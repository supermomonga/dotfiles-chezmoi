-- Import the wezterm module
local wezterm = require 'wezterm'
-- Creates a config object which we will be adding our config to
local config = wezterm.config_builder()

if wezterm.target_triple == 'x86_64-pc-windows-msvc' then
  config.default_domain = 'WSL:Ubuntu-24.04'
  config.wsl_domains = {
    {
      name = 'WSL:Ubuntu-24.04',
      distribution = 'Ubuntu-24.04',
      default_cwd = '~',
    }
  }
  -- We are running on Windows; maybe we emit different
  -- key assignments here?
end


enable_kitty_graphics = true

-- Pick a colour scheme. WezTerm ships with more than 1,000!
-- Find them here: https://wezfurlong.org/wezterm/colorschemes/index.html

-- Import our new module (put this near the top of your wezterm.lua)
local appearance = require 'appearance'

-- Use it!
if appearance.is_dark() then
    config.color_scheme = 'Tokyo Night'
else
    -- config.color_scheme = 'Tokyo Night Day'
    config.color_scheme = 'Tokyo Night'
end


-- Choose your favourite font, make sure it's installed on your machine
-- config.font = wezterm.font({ family = 'Berkeley Mono' })
-- And a font size that won't have you squinting

--  🭽
--  ▏
--  ▔
--  🭾
--  ▕
--  🭿
--  ▁
--  🭼
--  ▏
--

--  🭽▔▔▔▔🭾
--  ▏    ▕
--  🭼▁▁▁▁🭿


-- ┌└┐┘┼┬┴├┤─│╡╢╖╕╣║╗╝╜╛╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪━┃┄┅┆┇┈┉┊┋┍┎┏┑┒┓┕┖┗┙┚┛┝┞┟┠┡┢┣┥┦┧┨┩┪┫┭┮┯┰┱┲┳┵┶┷┸┹┺┻┽┾┿╀╁╂╃╄╅╆╇╈╉╊╋╌╍╎

--config.font = wezterm.font('JetBrains Mono', { weight = 'Regular' })
--config.font = wezterm.font('Fira Code')
config.font = wezterm.font({
    family = 'Firple',
    weight = 'Regular',
    harfbuzz_features = {
        'calt=0', 'clig=0', 'liga=0', -- リガチャオフ [ >= => != ++ ]
        'zero',                       -- [000]
        'cv33',                       -- 全角スペース可視化 [　　　]
        'ss11',                       -- 半濁点の強調 [ぱぴぷぺぽ パピプペポ]
    }
})
config.font_size = 11


config.use_resize_increments = true

-- Slightly transparent and blurred background
config.window_background_opacity = 1.0
config.macos_window_background_blur = 0
-- Removes the title bar, leaving only the tab bar. Keeps
-- the ability to resize by dragging the window's edges.
-- On macOS, 'RESIZE|INTEGRATED_BUTTONS' also looks nice if
-- you want to keep the window controls visible and integrate
-- them into the tab bar.
config.window_decorations = 'TITLE | RESIZE'
-- Sets the font for the window frame (tab bar)
config.window_frame = {
    -- Berkeley Mono for me again, though an idea could be to try a
    -- serif font here instead of monospace for a nicer look?
    -- font = wezterm.font({ family = 'Berkeley Mono', weight = 'Bold' }),
    font = wezterm.font({ family = 'Firple Slim', weight = 'Regular' }),
    font_size = 11,
}


local function segments_for_right_status(window)
    return {
        window:active_workspace(),
        wezterm.strftime('%a %b %-d %H:%M'),
        wezterm.hostname(),
    }
end

wezterm.on('update-status', function(window, _)
    local SOLID_LEFT_ARROW = utf8.char(0xe0b2)
    local segments = segments_for_right_status(window)

    local color_scheme = window:effective_config().resolved_palette
    -- Note the use of wezterm.color.parse here, this returns
    -- a Color object, which comes with functionality for lightening
    -- or darkening the colour (amongst other things).
    local bg = wezterm.color.parse(color_scheme.background)
    local fg = color_scheme.foreground

    -- Each powerline segment is going to be coloured progressively
    -- darker/lighter depending on whether we're on a dark/light colour
    -- scheme. Let's establish the "from" and "to" bounds of our gradient.
    local gradient_to, gradient_from = bg
    if appearance.is_dark() then
        gradient_from = gradient_to:lighten(0.2)
    else
        gradient_from = gradient_to:darken(0.2)
    end

    -- Yes, WezTerm supports creating gradients, because why not?! Although
    -- they'd usually be used for setting high fidelity gradients on your terminal's
    -- background, we'll use them here to give us a sample of the powerline segment
    -- colours we need.
    local gradient = wezterm.color.gradient(
        {
            orientation = 'Horizontal',
            colors = { gradient_from, gradient_to },
        },
        #segments -- only gives us as many colours as we have segments.
    )

    -- We'll build up the elements to send to wezterm.format in this table.
    local elements = {}

    for i, seg in ipairs(segments) do
        local is_first = i == 1

        if is_first then
            table.insert(elements, { Background = { Color = 'none' } })
        end
        table.insert(elements, { Foreground = { Color = gradient[i] } })
        table.insert(elements, { Text = SOLID_LEFT_ARROW })

        table.insert(elements, { Foreground = { Color = fg } })
        table.insert(elements, { Background = { Color = gradient[i] } })
        table.insert(elements, { Text = ' ' .. seg .. ' ' })
    end

    window:set_right_status(wezterm.format(elements))
end)

config.colors = {
    -- disable tab bar border between tabs
    tab_bar = {
        inactive_tab_edge = "none",
    },
}

-- tab design

-- https://wezfurlong.org/wezterm/config/lua/wezterm/nerdfonts.html
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
            return cmd
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
                return dir
            end
            return "~"
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
            return " " .. session .. "  " .. base
        else
            return " " .. base
        end
    end

    return base
end

config.tab_max_width = 30
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
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

-- Table mapping keypresses to actions
config.keys = {
    { key = '-', mods = 'CTRL', action = wezterm.action.SendKey({ mods = 'CTRL', key = '-' }) },
    { key = '=', mods = 'CTRL', action = wezterm.action.SendKey({ mods = 'CTRL', key = '=' }) },

    -- Cmd+Shift+Pでコマンドパレットを開く
    {
        key = 'P',
        mods = 'CMD|SHIFT',
        action = wezterm.action.ActivateCommandPalette,
    },

    -- Sends ESC + b and ESC + f sequence, which is used
    -- for telling your shell to jump back/forward.
    {
        -- When the left arrow is pressed
        key = 'LeftArrow',
        -- With the "Option" key modifier held down
        mods = 'OPT',
        -- Perform this action, in this case - sending ESC + B
        -- to the terminal
        action = wezterm.action.SendString '\x1bb',
    },
    {
        key = 'RightArrow',
        mods = 'OPT',
        action = wezterm.action.SendString '\x1bf',
    },
    -- Ctrl-Shift-pをカスタムイベントに割り当て
    {
        key = 'p',
        mods = 'CTRL|SHIFT',
        action = wezterm.action.EmitEvent 'custom-ctrl-shift-p',
    },
    -- Cmd+→ で1つ右のタブに切り替え
    {
        key = 'RightArrow',
        mods = 'CMD',
        action = wezterm.action.ActivateTabRelative(1),
    },
    -- Cmd+← で1つ左のタブに切り替え
    {
        key = 'LeftArrow',
        mods = 'CMD',
        action = wezterm.action.ActivateTabRelative(-1),
    },
}


config.set_environment_variables = {
    PATH = '/opt/homebrew/bin:' .. os.getenv('PATH')
}

-- remove window padding while NeoVim is active
local function is_nvim(pane)
    return (pane:get_foreground_process_name():match("nvim") ~= nil) or
        (pane:get_foreground_process_name():match("devcontainer.vim") ~= nil)
end

-- カスタムイベントを処理する関数
wezterm.on('custom-ctrl-shift-p', function(window, pane)
    if is_nvim(pane) then
        -- nvimがフォアグラウンドの場合、F1キーを送信
        --window:perform_action(wezterm.action.SendKey { key = 'F1' }, pane)
        window:perform_action(wezterm.action.SendKey {
            key = 'p',
            mods = 'CTRL|SHIFT'
        }, pane)
    else
        -- その他の場合、元のCtrl-Shift-pの動作
        window:perform_action(wezterm.action.SendKey {
            key = 'p',
            mods = 'CTRL|SHIFT',
        }, pane)
    end
end)

wezterm.on("update-right-status", function(window, pane)
    if is_nvim(pane) then
        window:set_config_overrides({
            window_padding = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0,
            },
        })
    else
        window:set_config_overrides({
            window_padding = nil,
        })
    end
end)


-- Returns our config to be evaluated. We must always do this at the bottom of this file
return config
