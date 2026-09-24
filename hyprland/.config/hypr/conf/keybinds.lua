-----------------
---- KEYBINDINGS ----
-----------------

-- Binds declared with bind(id, group, description, keys, dispatcher, opts)
-- show up in Settings > Hyprland > Keybinds, where their keys can be changed
-- (saved to local/settings.lua). See conf/binds.lua.

local vars = require("conf/variables")
-- If conf/binds.lua fails to load, every bind below still works (just not
-- editable from Settings). Hyprland doesn't report errors from require()
local ok, binds = pcall(require, "conf/binds")
if not ok then
    print("[keybinds] conf/binds.lua failed, binds aren't editable: " .. tostring(binds))
    binds = {
        bind = function(_, _, _, keys, dispatcher, opts) hl.bind(keys, dispatcher, opts) end,
        export = function() end,
    }
end
local bind = binds.bind

-- Sets "Windows" key as main modifier
local mainMod = "SUPER"

-- ==============================================================================
-- APPS
-- ==============================================================================

bind("terminal",     "Apps", "Terminal",     mainMod .. " + return", hl.dsp.exec_cmd(vars.terminal))
bind("file-manager", "Apps", "File manager", mainMod .. " + D",      hl.dsp.exec_cmd(vars.fileManager))
bind("browser",      "Apps", "Browser",      mainMod .. " + Z",      hl.dsp.exec_cmd(vars.browser))

-- ==============================================================================
-- WINDOWS
-- ==============================================================================

bind("close-window",      "Windows", "Close window",       mainMod .. " + Q",             hl.dsp.window.close())
bind("toggle-float",      "Windows", "Toggle floating",    mainMod .. " + SHIFT + Space", hl.dsp.window.float())
bind("maximize",          "Windows", "Maximize",           mainMod .. " + SHIFT + F",     hl.dsp.window.fullscreen({ mode = "maximized" }))
bind("fullscreen",        "Windows", "Fullscreen",         mainMod .. " + F",             hl.dsp.window.fullscreen({ mode = "fullscreen" }))
bind("toggle-split",      "Windows", "Toggle split",       mainMod .. " + TAB",           hl.dsp.layout("togglesplit"))

-- Move focus
bind("focus-left",  "Windows", "Focus left",  mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
bind("focus-right", "Windows", "Focus right", mainMod .. " + L", hl.dsp.focus({ direction = "r" }))
bind("focus-up",    "Windows", "Focus up",    mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
bind("focus-down",  "Windows", "Focus down",  mainMod .. " + J", hl.dsp.focus({ direction = "d" }))

-- Move position
bind("move-left",  "Windows", "Move window left",  mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
bind("move-right", "Windows", "Move window right", mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
bind("move-up",    "Windows", "Move window up",    mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
bind("move-down",  "Windows", "Move window down",  mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))

-- Resize window
local resizeOpts = { repeating = true, locked = true }
bind("resize-left",  "Windows", "Shrink width",   mainMod .. " + ALT + H", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), resizeOpts)
bind("resize-right", "Windows", "Grow width",     mainMod .. " + ALT + L", hl.dsp.window.resize({ x = 20,  y = 0, relative = true }), { repeating = true, locked = true })
bind("resize-up",    "Windows", "Shrink height",  mainMod .. " + ALT + K", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true, locked = true })
bind("resize-down",  "Windows", "Grow height",    mainMod .. " + ALT + J", hl.dsp.window.resize({ x = 0, y = 20,  relative = true }), { repeating = true, locked = true })

-- Drag windows with mouse (mouse buttons can't be recorded in Settings)
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ==============================================================================
-- WORKSPACES MULTI-MONITOR
-- ==============================================================================

-- Workspace management script
local workspaceManager = vars.scriptPath .. "/Workspace-Manager/workspace-manager.sh"

-- --- Special Workspaces (Global) ---
bind("special-whatsapp", "Workspaces", "Toggle WhatsApp", mainMod .. " + W", hl.dsp.workspace.toggle_special("whatsapp"))
bind("special-spotify",  "Workspaces", "Toggle Spotify",  mainMod .. " + M", hl.dsp.workspace.toggle_special("spotify"))
bind("special-magic",    "Workspaces", "Toggle scratchpad", mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))

bind("move-to-whatsapp", "Workspaces", "Move window to WhatsApp",   mainMod .. " + SHIFT + W", hl.dsp.window.move({ workspace = "special:whatsapp" }))
bind("move-to-spotify",  "Workspaces", "Move window to Spotify",    mainMod .. " + SHIFT + M", hl.dsp.window.move({ workspace = "special:spotify" }))
bind("move-to-magic",    "Workspaces", "Move window to scratchpad", mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- --- Direct Access (1-10) + Move Window (1-10) ---
-- Switch/move to workspace N on the current monitor (offset calculated by the script)
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    bind("workspace-" .. i,         "Workspaces", "Go to workspace " .. i,          mainMod .. " + " .. key,         hl.dsp.exec_cmd(workspaceManager .. " switch " .. i))
    bind("move-to-workspace-" .. i, "Workspaces", "Move window to workspace " .. i, mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd(workspaceManager .. " move " .. i))
end

-- --- Navigation (Next/Previous) ---
local navOpts = { repeating = true, locked = true }

bind("workspace-next",     "Workspaces", "Next workspace",           mainMod .. " + CTRL + L",     hl.dsp.exec_cmd(workspaceManager .. " next"), { repeating = true, locked = true })
bind("workspace-next-alt", "Workspaces", "Next workspace (arrow)",   mainMod .. " + CTRL + right", hl.dsp.exec_cmd(workspaceManager .. " next"), { repeating = true, locked = true })
bind("workspace-prev",     "Workspaces", "Previous workspace",       mainMod .. " + CTRL + H",     hl.dsp.exec_cmd(workspaceManager .. " prev"), { repeating = true, locked = true })
bind("workspace-prev-alt", "Workspaces", "Previous workspace (arrow)", mainMod .. " + CTRL + left", hl.dsp.exec_cmd(workspaceManager .. " prev"), navOpts)

-- --- Move Window + Navigation ---
bind("move-to-next",     "Workspaces", "Move window to next workspace",             mainMod .. " + CTRL + SHIFT + L",     hl.dsp.exec_cmd(workspaceManager .. " move_next"), { repeating = true, locked = true })
bind("move-to-next-alt", "Workspaces", "Move window to next workspace (arrow)",     mainMod .. " + CTRL + SHIFT + right", hl.dsp.exec_cmd(workspaceManager .. " move_next"), { repeating = true, locked = true })
bind("move-to-prev",     "Workspaces", "Move window to previous workspace",         mainMod .. " + CTRL + SHIFT + H",     hl.dsp.exec_cmd(workspaceManager .. " move_prev"), { repeating = true, locked = true })
bind("move-to-prev-alt", "Workspaces", "Move window to previous workspace (arrow)", mainMod .. " + CTRL + SHIFT + left",  hl.dsp.exec_cmd(workspaceManager .. " move_prev"), { repeating = true, locked = true })

-- ==============================================================================
-- AUDIO, BRIGHTNESS & MEDIA
-- ==============================================================================

-- Controls with Quickshell OSD
bind("volume-up",   "Media", "Volume up",   "XF86AudioRaiseVolume", hl.dsp.global("quickshell:volume_up"),   { repeating = true, locked = true })
bind("volume-down", "Media", "Volume down", "XF86AudioLowerVolume", hl.dsp.global("quickshell:volume_down"), { repeating = true, locked = true })
bind("volume-mute", "Media", "Mute",        "XF86AudioMute",        hl.dsp.global("quickshell:volume_mute"))

bind("brightness-up",   "Media", "Brightness up",   "XF86MonBrightnessUp",   hl.dsp.global("quickshell:brightness_up"),   { repeating = true, locked = true })
bind("brightness-down", "Media", "Brightness down", "XF86MonBrightnessDown", hl.dsp.global("quickshell:brightness_down"), { repeating = true, locked = true })

-- Requires playerctl
bind("media-next",  "Media", "Next track",       "XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
bind("media-pause", "Media", "Play / pause",     "XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("media-play",  "Media", "Play / pause (play key)", "XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("media-prev",  "Media", "Previous track",   "XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- ==============================================================================
-- SHELL
-- ==============================================================================

-- Screen zoom
local zoom = vars.scriptPath .. "/Zoom/run.sh" -- Script
bind("zoom-in",  "Shell", "Zoom in",  mainMod .. " + equal", hl.dsp.exec_cmd(zoom .. " in"))
bind("zoom-out", "Shell", "Zoom out", mainMod .. " + minus", hl.dsp.exec_cmd(zoom .. " out"))

bind("launcher",          "Shell", "App launcher",      mainMod .. " + Space",     hl.dsp.global("quickshell:app_launcher"))
bind("clipboard-history", "Shell", "Clipboard history", mainMod .. " + V",         hl.dsp.global("quickshell:clipboard_history"))
bind("screenshot",        "Shell", "Screenshot",        "Print",                   hl.dsp.global("quickshell:take_screenshot"))
bind("power-menu",        "Shell", "Power menu",        mainMod .. " + End",       hl.dsp.global("quickshell:power_menu"))
bind("wallpapers",        "Shell", "Wallpapers",        mainMod .. " + B",         hl.dsp.global("quickshell:wallpaper_picker"))
bind("settings",          "Shell", "Settings",          mainMod .. " + I",         hl.dsp.global("quickshell:settings"))
bind("keybinds",          "Shell", "Keybinds",          mainMod .. " + slash",     hl.dsp.global("quickshell:keybinds_help"))
bind("reload",            "Shell", "Reload Quickshell", mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("lyne reload"))

binds.export()
