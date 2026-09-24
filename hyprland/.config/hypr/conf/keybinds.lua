-----------------
---- KEYBINDINGS ----
-----------------

local vars = require("conf/variables")

-- Sets "Windows" key as main modifier
local mainMod = "SUPER"

-- ==============================================================================
-- APPS
-- ==============================================================================

hl.bind(mainMod .. " + return", hl.dsp.exec_cmd(vars.terminal))
hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd(vars.fileManager))
hl.bind(mainMod .. " + Z",      hl.dsp.exec_cmd(vars.browser))

-- ==============================================================================
-- ACTIONS
-- ==============================================================================

hl.bind(mainMod .. " + Q",         hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.float())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + TAB",       hl.dsp.layout("togglesplit"))

-- Screen zoom
local zoom = vars.scriptPath .. "/Zoom/run.sh" -- Script
hl.bind(mainMod .. " + equal", hl.dsp.exec_cmd(zoom .. " in"))
hl.bind(mainMod .. " + minus", hl.dsp.exec_cmd(zoom .. " out"))

-- Clipboard History
hl.bind(mainMod .. " + V", hl.dsp.global("quickshell:clipboard_history"))

-- ==============================================================================
-- WINDOWS
-- ==============================================================================

-- Move focus
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "d" }))

-- Move position
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))

-- Resize window
hl.bind(mainMod .. " + ALT + H", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true, locked = true })
hl.bind(mainMod .. " + ALT + L", hl.dsp.window.resize({ x = 20,  y = 0, relative = true }), { repeating = true, locked = true })
hl.bind(mainMod .. " + ALT + K", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true, locked = true })
hl.bind(mainMod .. " + ALT + J", hl.dsp.window.resize({ x = 0, y = 20,  relative = true }), { repeating = true, locked = true })

-- Drag windows with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ==============================================================================
-- WORKSPACES MULTI-MONITOR
-- ==============================================================================

-- Workspace management script
local workspaceManager = vars.scriptPath .. "/Workspace-Manager/workspace-manager.sh"

-- --- Special Workspaces (Global) ---
hl.bind(mainMod .. " + W", hl.dsp.workspace.toggle_special("whatsapp"))
hl.bind(mainMod .. " + M", hl.dsp.workspace.toggle_special("spotify"))
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))

hl.bind(mainMod .. " + SHIFT + W", hl.dsp.window.move({ workspace = "special:whatsapp" }))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.window.move({ workspace = "special:spotify" }))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- --- Direct Access (1-10) + Move Window (1-10) ---
-- Switch/move to workspace N on the current monitor (offset calculated by the script)
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.exec_cmd(workspaceManager .. " switch " .. i))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd(workspaceManager .. " move " .. i))
end

-- --- Navigation (Next/Previous) ---

-- Next workspace
hl.bind(mainMod .. " + CTRL + L",     hl.dsp.exec_cmd(workspaceManager .. " next"), { repeating = true, locked = true })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.exec_cmd(workspaceManager .. " next"), { repeating = true, locked = true })

-- Previous workspace
hl.bind(mainMod .. " + CTRL + H",    hl.dsp.exec_cmd(workspaceManager .. " prev"), { repeating = true, locked = true })
hl.bind(mainMod .. " + CTRL + left", hl.dsp.exec_cmd(workspaceManager .. " prev"), { repeating = true, locked = true })

-- --- Move Window + Navigation ---

-- Move window to next workspace
hl.bind(mainMod .. " + CTRL + SHIFT + L",     hl.dsp.exec_cmd(workspaceManager .. " move_next"), { repeating = true, locked = true })
hl.bind(mainMod .. " + CTRL + SHIFT + right", hl.dsp.exec_cmd(workspaceManager .. " move_next"), { repeating = true, locked = true })

-- Move window to previous workspace
hl.bind(mainMod .. " + CTRL + SHIFT + H",    hl.dsp.exec_cmd(workspaceManager .. " move_prev"), { repeating = true, locked = true })
hl.bind(mainMod .. " + CTRL + SHIFT + left", hl.dsp.exec_cmd(workspaceManager .. " move_prev"), { repeating = true, locked = true })

-- ==============================================================================
-- AUDIO, BRIGHTNESS & MEDIA
-- ==============================================================================

-- Controls with Quickshell OSD
hl.bind("XF86AudioRaiseVolume", hl.dsp.global("quickshell:volume_up"),   { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.global("quickshell:volume_down"), { repeating = true, locked = true })
hl.bind("XF86AudioMute",        hl.dsp.global("quickshell:volume_mute"))

hl.bind("XF86MonBrightnessUp",   hl.dsp.global("quickshell:brightness_up"),   { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.global("quickshell:brightness_down"), { repeating = true, locked = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- ==============================================================================
-- QUICKSHELL
-- ==============================================================================

hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("lyne reload")) -- Reload
hl.bind("Print",             hl.dsp.global("quickshell:take_screenshot")) -- Screenshot
hl.bind(mainMod .. " + End",   hl.dsp.global("quickshell:power_menu")) -- Power menu
hl.bind(mainMod .. " + Space", hl.dsp.global("quickshell:app_launcher")) -- Launcher
hl.bind(mainMod .. " + B",     hl.dsp.global("quickshell:wallpaper_picker")) -- Wallpapers (Settings)
hl.bind(mainMod .. " + slash", hl.dsp.global("quickshell:keybinds_help")) -- Keybinds Help
hl.bind(mainMod .. " + I",     hl.dsp.global("quickshell:settings")) -- Settings
