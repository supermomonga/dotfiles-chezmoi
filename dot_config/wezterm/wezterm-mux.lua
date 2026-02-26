-- wezterm-mux.lua
-- tmux replacement: pane/tab management using WezTerm's native multiplexer
-- Leader key: Ctrl+t (matches previous tmux prefix)

local wezterm = require 'wezterm'
local act = wezterm.action

local M = {}

-- Alt+Arrow: move between panes, wrapping to adjacent tab at edges
-- Replicates tmux behavior:
--   bind -n M-Left  if-shell -F '#{pane_at_left}'  'select-window -p' 'select-pane -L'
--   bind -n M-Right if-shell -F '#{pane_at_right}' 'select-window -n' 'select-pane -R'
local function pane_or_tab(direction, tab_action)
    return wezterm.action_callback(function(win, pane)
        local tab = win:active_tab()
        if tab:get_pane_direction(direction) then
            win:perform_action(act.ActivatePaneDirection(direction), pane)
        else
            win:perform_action(tab_action, pane)
        end
    end)
end

function M.apply_to_config(config)
    -- Leader key: Ctrl+t (equivalent to tmux prefix C-t)
    config.leader = { key = 't', mods = 'CTRL', timeout_milliseconds = 1000 }

    local mux_keys = {
        -- Send Ctrl+t through (leader + Ctrl+t, like tmux prefix prefix)
        {
            key = 't',
            mods = 'LEADER|CTRL',
            action = act.SendKey { key = 't', mods = 'CTRL' },
        },

        ---------------------------------------------------------------
        -- Pane splits  (tmux: prefix + | / -)
        ---------------------------------------------------------------
        {
            key = '|',
            mods = 'LEADER|SHIFT',
            action = act.SplitHorizontal { domain = 'CurrentPaneDomain' },
        },
        {
            key = '-',
            mods = 'LEADER',
            action = act.SplitVertical { domain = 'CurrentPaneDomain' },
        },

        ---------------------------------------------------------------
        -- Pane navigation  (tmux: prefix + h/j/k/l)
        ---------------------------------------------------------------
        { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
        { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
        { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
        { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },

        ---------------------------------------------------------------
        -- Tab navigation  (tmux: prefix + C-h / C-l)
        ---------------------------------------------------------------
        { key = 'h', mods = 'LEADER|CTRL', action = act.ActivateTabRelative(-1) },
        { key = 'l', mods = 'LEADER|CTRL', action = act.ActivateTabRelative(1) },

        ---------------------------------------------------------------
        -- Pane resize  (tmux: prefix + H/J/K/L, prefix + Arrow)
        ---------------------------------------------------------------
        { key = 'H', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Left', 5 } },
        { key = 'J', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Down', 5 } },
        { key = 'K', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Up', 5 } },
        { key = 'L', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Right', 5 } },

        { key = 'LeftArrow', mods = 'LEADER', action = act.AdjustPaneSize { 'Left', 5 } },
        { key = 'DownArrow', mods = 'LEADER', action = act.AdjustPaneSize { 'Down', 5 } },
        { key = 'UpArrow', mods = 'LEADER', action = act.AdjustPaneSize { 'Up', 5 } },
        { key = 'RightArrow', mods = 'LEADER', action = act.AdjustPaneSize { 'Right', 5 } },

        ---------------------------------------------------------------
        -- Utilities
        ---------------------------------------------------------------
        -- Reload config  (tmux: prefix + r)
        { key = 'r', mods = 'LEADER', action = act.ReloadConfiguration },

        -- Command palette  (tmux: prefix + ;  → command-prompt)
        { key = ';', mods = 'LEADER', action = act.ActivateCommandPalette },

        -- Close pane  (tmux: prefix + x)
        { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },

        -- New tab  (tmux: prefix + c)
        { key = 'c', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },

        -- Zoom pane toggle  (tmux: prefix + z)
        { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },

        -- Yazi file manager  (tmux: prefix + y → display-popup)
        -- Opens yazi in a bottom split pane at 80% height
        {
            key = 'y',
            mods = 'LEADER',
            action = act.SplitPane {
                direction = 'Down',
                command = { args = { 'yazi' } },
                size = { Percent = 80 },
            },
        },

        ---------------------------------------------------------------
        -- Alt+Arrow: pane navigation with tab wrapping at edges
        -- (tmux: bind -n M-Left/M-Right with pane_at_left/right check)
        ---------------------------------------------------------------
        { key = 'LeftArrow', mods = 'ALT', action = pane_or_tab('Left', act.ActivateTabRelative(-1)) },
        { key = 'RightArrow', mods = 'ALT', action = pane_or_tab('Right', act.ActivateTabRelative(1)) },
        { key = 'UpArrow', mods = 'ALT', action = act.ActivatePaneDirection 'Up' },
        { key = 'DownArrow', mods = 'ALT', action = act.ActivatePaneDirection 'Down' },
    }

    -- Append mux keys to existing config.keys
    config.keys = config.keys or {}
    for _, key in ipairs(mux_keys) do
        table.insert(config.keys, key)
    end
end

return M
