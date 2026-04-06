# XDG Base Directory
# change vimrc dir for neovim
$env:XDG_CONFIG_HOME = "$HOME\.config"
$env:XDG_DATA_HOME = "$HOME\.local\share"
$env:XDG_STATE_HOME = "$HOME\.local\state"
$env:XDG_CACHE_HOME = "$HOME\.cache"

# mise (cached activation for faster startup)
$_miseCache = "$HOME\.cache\mise\activate.ps1"
$_miseConf = "$HOME\.config\mise\conf.d\global.toml"
if (-not (Test-Path $_miseCache) -or
    (Test-Path $_miseConf) -and (Get-Item $_miseConf).LastWriteTime -gt (Get-Item $_miseCache).LastWriteTime) {
    $null = New-Item -ItemType Directory -Path (Split-Path $_miseCache) -Force
    & mise activate pwsh | Set-Content $_miseCache -Encoding UTF8
}
. $_miseCache

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


# ------------------------------------------------------------
# If not running interactively, don't do anything anymore.
if (-not $Host.UI -or -not $Host.UI.RawUI) {
    return
}
# ------------------------------------------------------------

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

# Aliases
function rl { . $PROFILE }
function gs { git status @args }
function gd { git diff @args }
Set-Alias -Name che -Value chezmoi

function ccd { cage claude --allow-dangerously-skip-permissions @args }
function glmd { cage glmcode --allow-dangerously-skip-permissions @args }
function co { cage codex @args }
function cod { cage codex --yolo @args }

# Starship
$env:STARSHIP_CONFIG = "$HOME\.config\starship\presets\pure.toml"
Invoke-Expression (&starship init powershell)

$localProfile = Join-Path $HOME ".local_profile.ps1"
if (Test-Path $localProfile) {
    . $localProfile
}



