#!/bin/bash
# tmux pane-focus-in hook から呼ばれ、
# アクティブ pane のフォアグラウンドプロセス名を WEZTERM_PROG として通知する

cmd="$(tmux display-message -p '#{pane_current_command}')"
tty="$(tmux display-message -p '#{client_tty}')"

[ -z "$tty" ] && exit 0

# シェル自体ならアイドル状態とみなし空文字にする (CWDフォールバックが効く)
case "$cmd" in
  bash|zsh|fish|sh|dash|ksh) cmd="" ;;
esac

encoded=$(printf '%s' "$cmd" | base64 | tr -d '\n')
printf '\033]1337;SetUserVar=%s=%s\007' "WEZTERM_PROG" "$encoded" > "$tty"
