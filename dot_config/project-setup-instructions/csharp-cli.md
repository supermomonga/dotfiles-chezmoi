# C# CLI プロジェクト構成ガイド

C# による CLI プロジェクトの構成テンプレート。

---

## 技術スタック

- ランタイム: .NET (latest)
- 言語: C# (latest)
- 自動テストフレームワーク: `TUnit`

## ライブラリ

- CLIインターフェイス: `https://github.com/Cysharp/ConsoleAppFramework`
- TOMLパーサ: `CsToml` ... TOML のパースや書き込みを行う場合は使用する
- TUI: `Spectre.Console` ... プログレスバーなどのリッチなTUIが必要な場合は使用する

### 成果物の配布

- NativeAOT + self-contained による単一実行ファイルのデプロイ（publish）する
- GitHub Releases でコンパイル済みバイナリを配布する（GHA ワークフローでリリースする）
- 実行ファイル名は CamelCase ではなく kebab-case とする（`<AssemblyName>` で指定する）

---

## プロジェクト構成

```
ProjectName/
├── src/
│   ├── ProjectName.Cli/
│   │   ├── ProjectName.Cli.csproj        # CLI プロジェクト
│   │   └── Program.cs                    # エントリポイント
│   ├── ProjectName.Cli.Tests/
│   │   ├── ProjectName.Cli.Tests.csproj  # CLI テストプロジェクト
│   │   └── ...
│   ├── ProjectName.Core/
│   │   └── ProjectName.Core.csproj       # Core プロジェクト
│   ├── ProjectName.Core.Tests/
│   │   └── ProjectName.Core.Tests.csproj # Core テストプロジェクト
│   └── ...                               # 必要に応じてプロジェクト追加
├── docs/
│   └── ...                               # 仕様などのドキュメント群(md)
├── .github/
│   └── workflows/
│       ├── version-bump.yml
│       ├── release.yml
│       └── ...
├── ProjectName.slnx
├── Directory.Build.props
├── README.md
├── ...
└── .gitignore
```

プロジェクトが十分にコンパクトな場合、CliプロジェクトとCoreプロジェクトを分離する必要はない。
CLIとしての配布だけでなく、ライブラリとしての配布も必要なプロジェクトの場合はCoreプロジェクトに分離する。

Directory.Build.props にはバージョンの様な、プロジェクト共通の設定を追加する。

```Directory.Build.props
<Project>
  <PropertyGroup>
    <Version>0.0.1</Version>
    <FileVersion>0.0.1</FileVersion>
  </PropertyGroup>
</Project>
```

.gitignoreファイルは `dotnet new gitignore` コマンドを使用して生成する。

---


## XDG Base Directory Specification の採用

XDG Base Directory Specification を採用する。
たとえば、アプリケーション用のグローバルな設定ファイルは `XDG_CONFIG_HOME` をベースに、`$XDG_CONFIG_HOME/<project-name>/config.toml` の様に配置する設計とする。

`XDG_CACHE_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME` なども適切に使用する。


## 開発時コマンド

slnxファイルがプロジェクトルートディレクトリにあるので、そのままdotnet buildやdotnet testが実行できる。

```bash
# コンパイル
dotnet build

# テスト
dotnet test

# 実行
dotnet run --project src\<ProjectName>
```

プロジェクト実行時の `--project` 指定は .csproj のフルパスではなく、フォルダまでの指定で問題ない。

---

## GHA Workflow

以下のテンプレートを使用する。 `<ProjectName>` は作成するプロジェクトの名前やパスに置き換えること。

### `version-bump.yml` のテンプレート

```yaml
name: Version Bump

on:
  workflow_dispatch:
    inputs:
      release_type:
        description: "Release type"
        required: true
        type: choice
        options:
          - patch
          - minor
          - major
      version:
        description: "Explicit version (overrides release_type if set, e.g. 1.2.3)"
        required: false
        type: string

permissions:
  contents: write
  pull-requests: write

jobs:
  bump:
    name: Bump Version & Create PR
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Bump Version
        id: bump-version
        uses: supermomonga/action-bump-cli@v1
        with:
          file: Directory.Build.props
          pattern: '<Version>(\d+\.\d+\.\d+)</Version>'
          release_type: ${{ inputs.version == '' && inputs.release_type || '' }}
          version: ${{ inputs.version }}

      - name: Bump FileVersion
        uses: supermomonga/action-bump-cli@v1
        with:
          file: Directory.Build.props
          pattern: '<FileVersion>(\d+\.\d+\.\d+)</FileVersion>'
          version: ${{ steps.bump-version.outputs.version }}

      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v7
        with:
          branch: release/v${{ steps.bump-version.outputs.version }}
          commit-message: "bump version to ${{ steps.bump-version.outputs.version }}"
          title: "Release v${{ steps.bump-version.outputs.version }}"
          body: |
            Bump version to **${{ steps.bump-version.outputs.version }}**.

            This PR was automatically created by the Version Bump workflow.
          labels: release
```

### `release.yml` のテンプレート

```yaml
name: Release

on:
  pull_request:
    types: [closed]
    branches: [main]
  workflow_dispatch:

permissions:
  contents: write

jobs:
  create-tag:
    name: Create Tag
    runs-on: ubuntu-latest
    if: >-
      github.event_name == 'workflow_dispatch' ||
      (github.event.pull_request.merged == true && contains(github.event.pull_request.labels.*.name, 'release'))
    outputs:
      version: ${{ steps.version.outputs.version }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Extract version from Directory.Build.props
        id: version
        run: |
          version=$(grep -oP '<Version>\K\d+\.\d+\.\d+' Directory.Build.props)
          echo "version=$version" >> "$GITHUB_OUTPUT"

      - name: Delete existing release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release delete "v${{ steps.version.outputs.version }}" \
            --repo "${{ github.repository }}" --yes || true

      - name: Delete existing tag
        run: |
          git push origin --delete "v${{ steps.version.outputs.version }}" || true

      - name: Create tag
        run: |
          git tag "v${{ steps.version.outputs.version }}"
          git push origin "v${{ steps.version.outputs.version }}"

  build:
    name: Build Native AOT (${{ matrix.rid }})
    needs: create-tag
    strategy:
      fail-fast: false
      matrix:
        include:
          - rid: win-x64
            os: windows-latest
            ext: .exe
          - rid: win-arm64
            os: windows-latest
            ext: .exe
          - rid: linux-x64
            os: ubuntu-latest
            ext: ""
          - rid: osx-arm64
            os: macos-latest
            ext: ""
    runs-on: ${{ matrix.os }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.x'

      - name: Restore
        run: dotnet restore

      - name: Publish (Native AOT)
        run: >
          dotnet publish src/<ProjectName>.Cli/<ProjectName>.Cli.csproj
          --configuration Release
          --runtime ${{ matrix.rid }}
          --output publish/

      - name: Rename binary (Windows)
        if: runner.os == 'Windows'
        run: |
          mv publish/<ProjectName>.Cli.exe "publish/<project-name>-${{ matrix.rid }}.exe"

      - name: Rename binary (Unix)
        if: runner.os != 'Windows'
        run: |
          mv publish/<ProjectName>.Cli "publish/<project-name>-${{ matrix.rid }}"

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: <project-name>-${{ matrix.rid }}
          path: publish/<project-name>-${{ matrix.rid }}${{ matrix.ext }}

  nuget:
    name: Publish NuGet Package
    runs-on: ubuntu-latest
    needs: create-tag

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.x'

      - name: Restore
        run: dotnet restore

      - name: Pack
        run: >
          dotnet pack src/<ProjectName>.Core/<ProjectName>.Core.csproj
          --configuration Release
          --output nupkgs/
          -p:PackageVersion=${{ needs.create-tag.outputs.version }}

      - name: Publish to nuget.org
        run: >
          dotnet nuget push nupkgs/*.nupkg
          --source "https://api.nuget.org/v3/index.json"
          --api-key ${{ secrets.NUGET_API_KEY }}
          --skip-duplicate

  release:
    name: Create GitHub Release
    runs-on: ubuntu-latest
    needs: [create-tag, build, nuget]

    steps:
      - name: Download artifacts
        uses: actions/download-artifact@v4
        with:
          path: artifacts/
          merge-multiple: true

      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release create "v${{ needs.create-tag.outputs.version }}" \
            artifacts/<project-name>-win-x64.exe \
            artifacts/<project-name>-win-arm64.exe \
            artifacts/<project-name>-linux-x64 \
            artifacts/<project-name>-osx-arm64 \
            --repo "${{ github.repository }}" \
            --title "v${{ needs.create-tag.outputs.version }}" \
            --generate-notes
```
