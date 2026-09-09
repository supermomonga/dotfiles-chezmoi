aiask() (
    if [[ $# -eq 0 || -z ${*//[[:space:]]/} ]]; then
        printf '使い方: aiask "実行したいことを自然言語で指定"\n' >&2
        return 2
    fi
    command -v codex >/dev/null 2>&1 || {
        printf 'aiask: codex が見つかりません。\n' >&2
        return 127
    }

    # 確認入力を標準入力から分離し、パイプの内容を承認として読まない。
    if ! { exec 3<>/dev/tty; } 2>/dev/null; then
        printf 'aiask: 確認できる端末が必要です。\n' >&2
        return 1
    fi

    local aiask_tmp aiask_prompt aiask_command aiask_answer aiask_status
    aiask_tmp=$(mktemp -d "${TMPDIR:-/tmp}/aiask.XXXXXXXX") || return 1
    trap 'rm -rf -- "$aiask_tmp"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    printf -v aiask_prompt '%s\nOS: %s\nBash: %s\n実行先ディレクトリ: %s\n依頼:\n%s\n' \
        '依頼を実現する Bash コマンドを生成してください。コマンドの実行、ツール利用、調査、ファイル変更は禁止です。最終回答は実行可能な Bash コードだけにし、Markdown、説明、コードフェンスを含めないでください。実行先は下記のディレクトリです。ここでの作業ディレクトリには移動しないでください。依頼に必要な処理だけを書き、不要なインストールや代替処理は追加しないでください。実現に必須の情報が不足している場合は、理由を日本語で標準エラーに出して終了コード2で終了するコマンドを返してください。' \
        "$(uname -s)" "$BASH_VERSION" "$PWD" "$*"

    printf 'コマンドを生成しています…\n' >&3
    # 認証は既存のものを使い、通常の設定と作業先から生成処理を分離する。
    if command codex exec \
        --ignore-user-config \
        --ephemeral \
        --skip-git-repo-check \
        --cd "$aiask_tmp" \
        --sandbox read-only \
        --model gpt-5.6-luna \
        -c 'model_reasoning_effort="low"' \
        -c 'approval_policy="never"' \
        -c 'project_doc_max_bytes=0' \
        -c 'web_search="disabled"' \
        --disable shell_tool \
        --disable shell_snapshot \
        --disable memories \
        --disable apps \
        --disable plugins \
        --disable hooks \
        --disable multi_agent \
        --disable browser_use \
        --disable computer_use \
        --disable code_mode_host \
        --color never \
        --output-last-message "$aiask_tmp/command" \
        - <<< "$aiask_prompt" >"$aiask_tmp/log" 2>&1 3>&-; then
        :
    else
        aiask_status=$?
        cat "$aiask_tmp/log" >&2
        return "$aiask_status"
    fi

    [[ -f $aiask_tmp/command ]] || {
        printf 'aiask: コマンドを取得できませんでした。\n' >&2
        return 1
    }
    aiask_command=$(<"$aiask_tmp/command")
    if [[ -z ${aiask_command//[[:space:]]/} || $aiask_command == *'```'* ]]; then
        printf 'aiask: 空の回答、またはコードフェンス付きの回答のため中止しました。\n' >&2
        return 1
    fi
    # 表示を隠したり書き換えたりする制御文字は許可しない（改行・タブは可）。
    local aiask_display_check
    aiask_display_check=${aiask_command//$'\n'/}
    aiask_display_check=${aiask_display_check//$'\t'/}
    if ( LC_ALL=C; [[ $aiask_display_check == *[[:cntrl:]]* ]] ); then
        printf 'aiask: 回答に制御文字が含まれるため中止しました。\n' >&2
        return 1
    fi
    BASH_ENV=/dev/null "$BASH" --noprofile --norc -n -c "$aiask_command" || return 1

    printf '\n' >&3
    command bat --language=bash --color=always --style=plain \
        --paging=never --wrap=character <<< "$aiask_command" >&3 || return 1
    printf '\n以下のコマンドを実行しますか？ (Y/n) ' >&3
    IFS= read -r aiask_answer <&3 || return 1
    case "$aiask_answer" in
        ''|[yY]|[yY][eE][sS])
            BASH_ENV=/dev/null "$BASH" --noprofile --norc -c "$aiask_command" 3>&-
            ;;
        *) printf 'キャンセルしました。\n' >&3 ;;
    esac
)
