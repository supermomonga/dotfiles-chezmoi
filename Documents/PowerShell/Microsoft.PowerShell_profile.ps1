# XDG Base Directory
# change vimrc dir for neovim
$env:XDG_CONFIG_HOME = "$HOME\.config"
$env:XDG_DATA_HOME = "$HOME\.local\share"
$env:XDG_STATE_HOME = "$HOME\.local\state"

# mise
(&mise activate pwsh) | Out-String | Invoke-Expression

# Claude Code
$resolved = Resolve-Path "~/.local/bin" -ErrorAction SilentlyContinue
if ($resolved) {
    $Env:Path = "$($resolved.Path);$Env:Path"
}

# git-bash for Claude Code
$resolved = Resolve-Path "~/scoop/apps/git/current/bin/bash.exe" -ErrorAction SilentlyContinue
if ($resolved) {
    $Env:CLAUDE_CODE_GIT_BASH_PATH = "$($resolved.Path)"
}

# Incremental search
Set-PSReadLineKeyHandler -Key Ctrl+p -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key Ctrl+n -Function HistorySearchForward

# 行頭 / 行末
Set-PSReadLineKeyHandler -Key Ctrl+a -Function BeginningOfLine
Set-PSReadLineKeyHandler -Key Ctrl+e -Function EndOfLine

# 削除系
Set-PSReadLineKeyHandler -Key Ctrl+k -Function KillLine
Set-PSReadLineKeyHandler -Key Ctrl+u -Function BackwardKillLine

# 1文字移動
Set-PSReadLineKeyHandler -Key Ctrl+f -Function ForwardChar
Set-PSReadLineKeyHandler -Key Ctrl+b -Function BackwardChar

# git-wt
Invoke-Expression (git wt --init powershell | Out-String)

# Editor
$env:EDITOR = "nvim"

# History settings (equivalent to HISTCONTROL=ignoreboth, HISTSIZE=100000)
Set-PSReadLineOption -MaximumHistoryCount 100000
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -AddToHistoryHandler {
  param($line)
  $line -ne '' -and $line[0] -ne ' '
}

# Aliases
function rl { . $PROFILE }
function gs { git status @args }
function gd { git diff @args }
Set-Alias -Name che -Value chezmoi

function cc { cage claude --allow-dangerously-skip-permissions @args }
function ccd { cage claude --dangerously-skip-permissions @args }
function glm { cage glmcode --allow-dangerously-skip-permissions @args }
function glmd { cage glmcode --dangerously-skip-permissions @args }
function co { cage codex @args }
function cod { cage codex --yolo @args }

# ghq + fzf repo selector
function repo_list {
  $candidates = @(ghq list | Where-Object { $_ -notmatch '-worktrees/[^/]+$' })
  $candidates += '.local/share/chezmoi'
  $repo = $candidates | fzf
  if (-not $repo) { return }
  if ($repo -eq '.local/share/chezmoi') {
    Set-Location "$HOME\.local\share\chezmoi"
  } else {
    Set-Location "$(ghq root)\$repo"
  }
}
Set-Alias -Name g -Value repo_list

# git worktree + fzf selector
function git_worktree_list {
  $select = git-wt | Select-Object -Skip 1 | fzf
  if (-not $select) { return }
  $repo = ($select -split '\s+')[0]
  Set-Location $repo
}
Set-Alias -Name gw -Value git_worktree_list

# Starship
Invoke-Expression (&starship init powershell)
starship preset pure-preset -o $(Resolve-Path "~/.config/starship/presets/pure.toml")
