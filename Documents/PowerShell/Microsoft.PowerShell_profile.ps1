# XDG Base Directory
# change vimrc dir for neovim
$env:XDG_CONFIG_HOME = "$HOME\.config"
$env:XDG_DATA_HOME = "$HOME\.local\share"
$env:XDG_STATE_HOME = "$HOME\.local\state"

# mise
(&mise activate pwsh) | Out-String | Invoke-Expression
