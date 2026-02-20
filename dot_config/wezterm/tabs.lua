local wezterm = require 'wezterm'

local M = {}

local SOLID_LEFT_ARROW = wezterm.nerdfonts.ple_left_half_circle_thick
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.ple_right_half_circle_thick

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

function M.apply_to_config(config)
    config.tab_max_width = 30

    config.colors = config.colors or {}
    config.colors.tab_bar = {
        -- タブ間のボーダーを非表示
        inactive_tab_edge = "none",
    }

    wezterm.on("format-tab-title", function(tab, tabs, panes, cfg, hover, max_width)
        local background = "#2D2D2D"
        local foreground = "#ccc"
        if tab.is_active then
            background = "#1F1F1F"
            foreground = "#FFFFFF"
        end

        local title = " " .. wezterm.truncate_right(get_tab_display_title(tab.active_pane), max_width - 1) .. " "

        return {
            { Background = { Color = background } },
            { Foreground = { Color = foreground } },
            { Text = title },
        }
    end)
end

return M
