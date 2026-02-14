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
- `op` - 1Password に保存された情報の取得 (e.g. `op read [reference_path]`) / WSLの場合は `op.exe` を使用すること

### Available secrets in Templates

`.tmpl` ファイル内で chezmoi の 1password-cli 経由で参照されることを想定しているシークレット:

- `op://Personal/GreenCloud VPS/api_key` - GreenCloud VPS の API キー

### Git Worktree Workflow

The gitconfig configures `git-wt` with worktree basedir at `../{gitroot}-worktrees`, auto-copying `.vscode/`, `.env`, `.envrc`, and local config files, and running `mise install` as a post-create hook.
