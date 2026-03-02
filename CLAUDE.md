# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **chezmoi** dotfiles repository managed by user `supermomonga`. chezmoi manages dotfiles across multiple platforms (Linux/WSL, macOS, Windows).

## Key Commands

```bash
# Dry-run for debug
chezmoi apply ~/.some_config --dry-run --debug

# Preview what would change (diff)
chezmoi diff ~/.some_config

# Add a new file to chezmoi management
chezmoi add ~/.some_config
```

## Rules

Do not execute `chezmoi apply` without `--dry-run` option to avoid unexpected effect. You have to always use `--dry-run` option for debugging.

You MUST specify target file when using `chezmoi apply`, `chezmoi diff`, and other command, because some template files requires user's auth (via Windows Hello), so it'll be blocking.

## Document lookup


Always use Context7 MCP when you need documentation, code generation, setup or configuration steps without me having to explicitly ask.

Use library-id `/twpayne/chezmoi` for querying chezmoi docs.

Do not use MCP tools directly. Spawn `context7-plugin:docs-researcher` to look up documentation.

## Architecture

### Platform-Conditional Templating

Files ending in `.tmpl` are Go templates using `chezmoi.os`, `chezmoi.kernel.osrelease`, etc. to conditionally generate content per platform. Key conditionals:

- **WSL detection**: `(.chezmoi.kernel.osrelease | lower | contains "microsoft")` — used in gitconfig and bash_profile to set up SSH agent bridging (socat + npiperelay.exe) and credential helpers
- **OS branching**: `{{ if eq .chezmoi.os "windows" }}` / `"darwin"` / `"linux"` — used in chezmoi config, gitconfig, mise config, and chezmoiignore

### File Naming Convention (chezmoi)

- `dot_` prefix → maps to `.` (e.g., `dot_bashrc` → `~/.bashrc`)
- `private_` prefix → file permission 0600
- `.tmpl` suffix → processed as Go template
- `dot_config/` → `~/.config/`

### Platform-Specific Directories

- `AppData/`, `Documents/` — Windows-only files (PowerShell profile, 1Password config), ignored on Linux/macOS via `.chezmoiignore`
- `dot_config/1Password/` — Linux/macOS SSH agent config, ignored on Windows

### Shared Templates

`.chezmoitemplates/1password/agent.toml.tmpl` is shared between Linux (`dot_config/1Password/ssh/agent.toml`) and Windows (`AppData/Local/1Password/config/ssh/agent.toml.tmpl`) using chezmoi's `{{ template }}` directive.

### Tool Stack (managed via mise)

Global tools are defined in `dot_config/mise/conf.d/global.toml.tmpl`:
- Runtimes: bun, deno, go, node, python, rust, zig
- CLI tools: chezmoi, neovim, fzf, uv, tree-sitter
- Packages: ghq (repo management), git-wt (git worktree helper), pik, gomi, happy-coder, pockode (non-Windows only)
- npm package manager is set to bun

### Claude Code Settings

`dot_claude/settings.json` configures Claude Code globally:
- Language: Japanese
- Model: opus
- Hooks: ntfy.sh notifications for permission requests, idle prompts, and task completion
- StatusLine: ccstatusline with OpenRouter cost tracking (`dot_config/ccstatusline/`)
- Plugins: dig (kuu-marketplace), lua-lsp (claude-plugins-official)

### Available Tools in Templates

`.tmpl` ファイル内で chezmoi の `output` 関数経由で利用可能な外部コマンド:

- `vultr-cli` - Vultr インスタンス情報の取得（`private_dot_ssh/private_config.tmpl` で使用）
- `cntb` - Contabo インスタンス情報の取得（`private_dot_ssh/private_config.tmpl` で使用）
- `jq` - JSON の加工・フィルタリング
- `op` - 1Password に保存された情報の取得 (e.g. `op read [reference_path]`)

### Available secrets in Templates

`.tmpl` ファイル内で chezmoi の 1password-cli 経由で参照されることを想定しているシークレット:

- `op://Personal/GreenCloud VPS/api_key` - GreenCloud VPS の API キー

### Git Worktree Workflow

The gitconfig configures `git-wt` with worktree basedir at `../{gitroot}-worktrees`, auto-copying `.vscode/`, `.env`, `.envrc`, and local config files, and running `mise install` as a post-create hook.

## Expo / React Native 開発ガイドライン

### EAS Build の利用制限

EAS の無料プランはビルド可能回数が非常に少ないため、**EAS Build は原則使用しない**。ユーザーが明示的に `eas build` の実行を指示した場合のみ使用すること。

- `eas build` コマンドは**ユーザーの明示的な指示なしに実行してはならない**
- EAS Update（OTA Update）は月1000回の枠があるため、引き続き使用してよい

### ローカルビルドと実機テスト

preview/development build は**ローカルでビルド**し、adb で接続した実機 Android 端末で動作確認を行う。

```bash
# development build をローカルでビルド
npx expo run:android

# または prebuild してから Gradle で直接ビルド
npx expo prebuild --platform android
cd android && ./gradlew assembleDebug

# adb で接続確認
adb devices

# APK を実機にインストール
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
```

### adb による自律的な動作確認

Claude Code は adb を活用して、アプリの動作確認やデザイン確認を自律的に行うこと。

```bash
# スクリーンショットを取得して確認
adb exec-out screencap -p > /tmp/screenshot.png

# 画面タップ（座標指定）
adb shell input tap <x> <y>

# テキスト入力
adb shell input text '<text>'

# スワイプ操作
adb shell input swipe <x1> <y1> <x2> <y2> <duration_ms>

# 戻るボタン
adb shell input keyevent KEYCODE_BACK

# 現在のアクティビティ確認
adb shell dumpsys activity activities | grep mResumedActivity

# ログ確認（React Native）
adb logcat -s ReactNativeJS:V
```

動作確認のフロー:
1. ビルド・インストール後、adb でアプリを起動
2. スクリーンショットを取得して UI/デザインを目視確認
3. タップ・スワイプ等の操作で画面遷移を確認
4. 問題があればログを確認して原因を特定
