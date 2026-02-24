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

