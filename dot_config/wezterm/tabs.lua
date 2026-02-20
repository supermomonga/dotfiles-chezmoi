local wezterm = require 'wezterm'

local M = {}

-- WSLのwslhost.exeなど、Windows側ラッパープロセスを検出して
-- WEZTERM_PROG / WEZTERM_IN_TMUX や実際のタイトル、カレントディレクトリにフォールバックする
local wsl_wrappers = { wslhost = true, wsl = true, conhost = true }

-- ベースタイトルを決定する（tmuxプレフィックスなし）
local function resolve_base_title(pane, exec, title, user_vars)
    -- 1. WEZTERM_PROG (シェル統合が設定する実行中のコマンドライン)
    local prog = user_vars.WEZTERM_PROG or ""
    if prog ~= "" then
        -- コマンドライン先頭のプログラム名だけ抽出 (例: "nvim foo.txt" -> "nvim")
        local cmd = prog:match("^%S+")
        if cmd then
            cmd = cmd:match("([^/]+)$") or cmd
            return " " .. cmd
        end
    end

    -- 2. シェルが OSC エスケープシーケンスで設定したタイトル
    if title ~= "" and not title:lower():match("wslhost") and title ~= pane.foreground_process_name then
        return title
    end

    -- 3. フォールバック: カレントワーキングディレクトリを表示
    local cwd_url = pane.current_working_dir
    if cwd_url then
        local path
        if type(cwd_url) == "userdata" and cwd_url.file_path then
            path = cwd_url.file_path
        else
            path = tostring(cwd_url):gsub("^file://[^/]*", "")
        end
        if path then
            path = path:gsub("^/home/[^/]+", "~")
            local dir = path:match("([^/]+)/?$")
            if dir and dir ~= "" then
                return " " .. dir
            end
            return " ~"
        end
    end

    return "WSL"
end

local function get_tab_display_title(pane)
    local title = pane.title or ""
    local process = pane.foreground_process_name or ""
    local user_vars = pane.user_vars or {}

    -- プロセス名からファイル名部分だけ取得し、.exe を除去
    local exec = (process:match("([^/\\]+)$") or ""):gsub("%.exe$", "")

    -- WSL ラッパープロセスかどうか判定
    if not wsl_wrappers[exec:lower()] then
        return exec ~= "" and exec or title
    end

    -- WSL ラッパーの場合: ベースタイトルを解決
    local base = resolve_base_title(pane, exec, title, user_vars)

    -- tmux 内であればプレフィックスを付与
    -- WEZTERM_IN_TMUX="1" かつ TMUX_SESSION (カスタム user var) があればセッション名を表示
    -- なければ "tmux" のみ
    if user_vars.WEZTERM_IN_TMUX == "1" then
        local session = user_vars.TMUX_SESSION or ""
        if session ~= "" then
            return " " .. session
        else
            return base
        end
    end

    return base
end

-- =====================================================================
-- Bell 通知
--
-- 外部スクリプト (wezterm-bell) が OSC 1337 SetUserVar=BELL=<base64(emoji)>
-- を送信すると user-var-changed が発火し、ここで状態を管理する。
--
-- 表示条件:
--   タブが非アクティブ、または アクティブだが WezTerm が前面でない場合に 🔔 等を表示
-- クリア条件:
--   非アクティブタブ → タブをアクティブにしたとき
--   アクティブタブ   → WezTerm ウィンドウがフォーカスを取得したとき
-- =====================================================================

-- pane_id → { emoji_string → true }  (セットとして使用、重複排除)
local bell_state = {}

-- WezTerm ウィンドウごとの状態追跡 (update-status 用)
local prev_focused        = {}  -- [win_id] → bool
local prev_active_pane_id = {}  -- [win_id] → pane_id

local function get_bell_string(pane_id)
    local state = bell_state[pane_id]
    if not state then return "" end
    local result = ""
    for emoji in pairs(state) do
        result = result .. emoji
    end
    return result
end

local function clear_bell(pane)
    bell_state[pane:pane_id()] = nil
    -- BELL を空にリセット（次回の user-var-changed がクリア信号として扱う）
    pane:inject_output('\x1b]1337;SetUserVar=BELL=\x07')
end

function M.apply_to_config(config)
    config.tab_max_width = 30

    config.colors = config.colors or {}
    config.colors.tab_bar = {
        -- タブ間のボーダーを非表示
        inactive_tab_edge = "none",
    }

    -- BELL ユーザー変数が変化したときに発火
    wezterm.on('user-var-changed', function(window, pane, name, value)
        if name ~= 'BELL' then return end

        local pane_id = pane:pane_id()

        -- 空値はクリア信号（inject_output によるリセット時に発火）
        if value == '' then
            bell_state[pane_id] = nil
            return
        end

        -- 絵文字をセットに追加（同じ絵文字は重複しない）
        bell_state[pane_id] = bell_state[pane_id] or {}
        bell_state[pane_id][value] = true

        -- すでにユーザーがこのペインを見ている場合は即クリア
        -- (アクティブタブ かつ WezTerm がフォーカス中)
        if window:active_pane():pane_id() == pane_id and window:is_focused() then
            clear_bell(pane)
        end
    end)

    -- タブ切り替え・WezTerm フォーカス復帰時にベルをクリア
    wezterm.on('update-status', function(window, pane)
        local win_id  = window:window_id()
        local pane_id = pane:pane_id()
        local is_focused = window:is_focused()

        local was_focused = prev_focused[win_id]
        local prev_id     = prev_active_pane_id[win_id]

        -- 変化検知
        local just_gained_focus = was_focused ~= nil and not was_focused and is_focused
        local just_switched_to  = prev_id ~= nil and prev_id ~= pane_id

        prev_focused[win_id]        = is_focused
        prev_active_pane_id[win_id] = pane_id

        -- ベルが立っているペインにユーザーが注目し始めたらクリア
        if bell_state[pane_id] and (just_gained_focus or just_switched_to) then
            clear_bell(pane)
        end
    end)

    wezterm.on("format-tab-title", function(tab, tabs, panes, cfg, hover, max_width)
        local background = "#2D2D2D"
        local foreground = "#ccc"
        if tab.is_active then
            background = "#1F1F1F"
            foreground = "#FFFFFF"
        end

        local pane_id = tab.active_pane.pane_id
        local bells   = get_bell_string(pane_id)
        local base    = (bells ~= "" and (bells .. " ") or "") .. get_tab_display_title(tab.active_pane)
        local title   = " " .. wezterm.truncate_right(base, max_width - 2) .. " "

        return {
            { Background = { Color = background } },
            { Foreground = { Color = foreground } },
            { Text = title },
        }
    end)
end

return M
