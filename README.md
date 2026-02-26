# dotfiles

[chezmoi](https://www.chezmoi.io/) で管理する dotfiles リポジトリ。Linux (WSL)・macOS・Windows に対応。

## セットアップ

### 初回インストール（ワンライナー）

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin init --apply supermomonga/dotfiles-chezmoi
```

### 前提条件

- curl または wget
- 初回実行時に chezmoi が自動インストールされる
- 1Password CLI（テンプレート内のシークレット解決に必要。スクリプトで自動インストールされる）

### インストール後に自動で行われること

- **Linux**: 1Password CLI (beta)・GitHub CLI・htop のインストール、mise のセットアップ
- **macOS**: GitHub CLI のインストール、mise のセットアップ
- mise 経由でランタイム（bun, deno, go, node, python, rust, zig）と各種 CLI ツールがインストールされる

## 主な管理対象

| 対象 | 説明 |
|------|------|
| シェル | bash, zsh |
| Git | gitconfig（WSL での SSH Agent ブリッジ含む） |
| SSH | 1Password 連携の SSH 設定 |
| エディタ | Neovim, VS Code (Neovim 拡張) |
| ターミナル | tmux, WezTerm, Starship プロンプト |
| ランタイム管理 | mise（グローバルツール定義） |
| AI ツール | Claude Code, OpenAI Codex |

## よく使うコマンド

```bash
# 変更のプレビュー（差分表示）
chezmoi diff ~/.bashrc

# ドライラン（実際には適用しない）
chezmoi apply ~/.bashrc --dry-run --debug

# ファイルを chezmoi 管理に追加
chezmoi add ~/.some_config

# テンプレートの編集
chezmoi edit ~/.gitconfig

# ソースディレクトリを開く
chezmoi cd
```

> **注意**: `chezmoi apply` や `chezmoi diff` を実行する際は、必ず対象ファイルを指定してください。一部のテンプレートが Windows Hello 等の認証を要求するため、対象未指定だとブロックされる場合があります。

## プラットフォーム分岐

`.tmpl` ファイル内で Go テンプレートによるプラットフォーム分岐を行っている。

- **WSL 判定**: `.chezmoi.kernel.osrelease` に `microsoft` が含まれるかで判定
- **OS 分岐**: `.chezmoi.os` が `windows` / `darwin` / `linux` で分岐
- **Windows 専用**: `AppData/`, `Documents/` 配下のファイル
- **Linux/macOS 専用**: `dot_config/1Password/` 配下のファイル

## ライセンス

MIT
