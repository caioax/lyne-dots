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

-- The apps are chosen in Settings > System > Apps: local/settings.lua
-- (generated) calls lyne_apps() with their commands. The binds read them
-- when pressed, so changing an app doesn't need a rebind
LYNE_APPS = {
    terminal     = vars.terminal,
    file_manager = vars.fileManager,
    browser      = vars.browser,
}

function lyne_apps(apps)
    for key, command in pairs(apps) do
        LYNE_APPS[key] = command
    end
end

local function open(app)
    return function()
        local command = LYNE_APPS[app] or ""
        if command ~= "" then
            hl.exec_cmd(command)
        end
    end
end

bind("terminal",     "Apps", "Terminal",     mainMod .. " + return", open("terminal"))
bind("file-manager", "Apps", "File manager", mainMod .. " + D",      open("file_manager"))
bind("browser",      "Apps", "Browser",      mainMod .. " + Z",      open("browser"))

-- ==============================================================================
-- WINDOWS
-- ==============================================================================

bind("close-window",      "Windows", "Close window",       mainMod .. " + Q",             hl.dsp.window.close())
bind("toggle-float",      "Windows", "Toggle floating",    mainMod .. " + SHIFT + Space", hl.dsp.window.float())
bind("maximize",          "Windows", "Maximize",           "",                            hl.dsp.window.fullscreen({ mode = "maximized" }))
bind("fullscreen",        "Windows", "Fullscreen",         mainMod .. " + F",             hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Super + Tab does what fits the workspace's layout (Settings > Windows >
-- Tiling): dwindle flips the split, master swaps with the main window,
-- scrolling cycles the column through scrolling:explicit_column_widths
local function layout_action(messages)
    return function()
        local workspace = hl.get_active_workspace()
        local layout = workspace and workspace.tiled_layout or hl.get_config("general.layout")
        local message = messages[layout]
        if message then
            hl.dispatch(hl.dsp.layout(message))
        end
    end
end

bind("toggle-split",       "Windows", "Split / swap with main / column width", mainMod .. " + TAB",         layout_action({ dwindle = "togglesplit", master = "swapwithmaster", scrolling = "colresize +conf" }))
bind("layout-action-back", "Windows", "Previous column width (scrolling)",      mainMod .. " + SHIFT + TAB", layout_action({ scrolling = "colresize -conf" }))
-- Dwindle → master → scrolling, saved like the Settings choice and shown in the OSD
bind("cycle-layout",       "Windows", "Next window layout",                     mainMod .. " + CTRL + TAB",  hl.dsp.global("quickshell:cycle_tiling"))

-- Scrolling layout only: columns on a strip (see conf/appearance.lua)
bind("swap-column-left",  "Windows", "Swap column left (scrolling)",             mainMod .. " + comma",        hl.dsp.layout("swapcol l"))
bind("swap-column-right", "Windows", "Swap column right (scrolling)",            mainMod .. " + period",       hl.dsp.layout("swapcol r"))
bind("join-column-prev",  "Windows", "Join / leave previous column (scrolling)", mainMod .. " + bracketleft",  hl.dsp.layout("consume_or_expel prev"))
bind("join-column-next",  "Windows", "Join / leave next column (scrolling)",     mainMod .. " + bracketright", hl.dsp.layout("consume_or_expel next"))
bind("center-column",     "Windows", "Center column (scrolling)",                mainMod .. " + C",            hl.dsp.layout("center"))
bind("fit-columns",       "Windows", "Fit visible columns (scrolling)",          mainMod .. " + R",            hl.dsp.layout("fit visible"))

-- Move focus. The "(arrow)" binds have no keys by default: the navigation
-- keys preset (Settings › Hyprland › Keybinds, conf/bind_presets.lua) gives
-- them the arrow keys when "Both" is chosen
bind("focus-left",  "Windows", "Focus left",  mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
bind("focus-right", "Windows", "Focus right", mainMod .. " + L", hl.dsp.focus({ direction = "r" }))
bind("focus-up",    "Windows", "Focus up",    mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
bind("focus-down",  "Windows", "Focus down",  mainMod .. " + J", hl.dsp.focus({ direction = "d" }))
bind("focus-left-alt",  "Windows", "Focus left (arrow)",  "", hl.dsp.focus({ direction = "l" }))
bind("focus-right-alt", "Windows", "Focus right (arrow)", "", hl.dsp.focus({ direction = "r" }))
bind("focus-up-alt",    "Windows", "Focus up (arrow)",    "", hl.dsp.focus({ direction = "u" }))
bind("focus-down-alt",  "Windows", "Focus down (arrow)",  "", hl.dsp.focus({ direction = "d" }))

-- Move position
bind("move-left",  "Windows", "Move window left",  mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
bind("move-right", "Windows", "Move window right", mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
bind("move-up",    "Windows", "Move window up",    mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
bind("move-down",  "Windows", "Move window down",  mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
bind("move-left-alt",  "Windows", "Move window left (arrow)",  "", hl.dsp.window.move({ direction = "l" }))
bind("move-right-alt", "Windows", "Move window right (arrow)", "", hl.dsp.window.move({ direction = "r" }))
bind("move-up-alt",    "Windows", "Move window up (arrow)",    "", hl.dsp.window.move({ direction = "u" }))
bind("move-down-alt",  "Windows", "Move window down (arrow)",  "", hl.dsp.window.move({ direction = "d" }))

-- Resize window
local resizeOpts = { repeating = true, locked = true }
bind("resize-left",  "Windows", "Shrink width",   mainMod .. " + ALT + H", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), resizeOpts)
bind("resize-right", "Windows", "Grow width",     mainMod .. " + ALT + L", hl.dsp.window.resize({ x = 20,  y = 0, relative = true }), { repeating = true, locked = true })
bind("resize-up",    "Windows", "Shrink height",  mainMod .. " + ALT + K", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true, locked = true })
bind("resize-down",  "Windows", "Grow height",    mainMod .. " + ALT + J", hl.dsp.window.resize({ x = 0, y = 20,  relative = true }), { repeating = true, locked = true })
bind("resize-left-alt",  "Windows", "Shrink width (arrow)",  "", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), resizeOpts)
bind("resize-right-alt", "Windows", "Grow width (arrow)",    "", hl.dsp.window.resize({ x = 20,  y = 0, relative = true }), resizeOpts)
bind("resize-up-alt",    "Windows", "Shrink height (arrow)", "", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), resizeOpts)
bind("resize-down-alt",  "Windows", "Grow height (arrow)",   "", hl.dsp.window.resize({ x = 0, y = 20,  relative = true }), resizeOpts)

-- Drag windows with mouse (mouse buttons can't be recorded in Settings)
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ==============================================================================
-- WORKSPACES MULTI-MONITOR
-- ==============================================================================

-- Each monitor has its own workspaces (conf/workspaces.lua): the binds act
-- on the focused monitor's block. Without it, they fall back to plain ids
local ok_ws, workspaces = pcall(require, "conf/workspaces")
if not ok_ws then
    print("[keybinds] conf/workspaces.lua failed, workspaces aren't per monitor: " .. tostring(workspaces))
    local function active_id()
        local active = hl.get_active_workspace()
        return active and active.id or 1
    end
    workspaces = {
        go = function(n) hl.dispatch(hl.dsp.focus({ workspace = n })) end,
        move = function(n) hl.dispatch(hl.dsp.window.move({ workspace = n })) end,
        step = function(d) hl.dispatch(hl.dsp.focus({ workspace = math.max(1, active_id() + d) })) end,
        move_step = function(d) hl.dispatch(hl.dsp.window.move({ workspace = math.max(1, active_id() + d) })) end,
    }
end

-- Special workspaces (WhatsApp, music, scratchpad) are bound in conf/specials.lua

-- --- Direct Access (1-10) + Move Window (1-10) ---
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    bind("workspace-" .. i,         "Workspaces", "Go to workspace " .. i,          mainMod .. " + " .. key,         function() workspaces.go(i) end)
    bind("move-to-workspace-" .. i, "Workspaces", "Move window to workspace " .. i, mainMod .. " + SHIFT + " .. key, function() workspaces.move(i) end)
end

-- --- Navigation (Next/Previous) ---
local navOpts = { repeating = true, locked = true }
local function go_step(direction) return function() workspaces.step(direction) end end
local function move_step(direction) return function() workspaces.move_step(direction) end end

bind("workspace-next",     "Workspaces", "Next workspace",             mainMod .. " + CTRL + L",     go_step(1),  navOpts)
bind("workspace-next-alt", "Workspaces", "Next workspace (arrow)",     "",                           go_step(1),  navOpts)
bind("workspace-prev",     "Workspaces", "Previous workspace",         mainMod .. " + CTRL + H",     go_step(-1), navOpts)
bind("workspace-prev-alt", "Workspaces", "Previous workspace (arrow)", "",                           go_step(-1), navOpts)

-- --- Move Window + Navigation ---
bind("move-to-next",     "Workspaces", "Move window to next workspace",             mainMod .. " + CTRL + SHIFT + L",     move_step(1),  navOpts)
bind("move-to-next-alt", "Workspaces", "Move window to next workspace (arrow)",     "",                                   move_step(1),  navOpts)
bind("move-to-prev",     "Workspaces", "Move window to previous workspace",         mainMod .. " + CTRL + SHIFT + H",     move_step(-1), navOpts)
bind("move-to-prev-alt", "Workspaces", "Move window to previous workspace (arrow)", "",                                   move_step(-1), navOpts)

-- ==============================================================================
-- AUDIO, BRIGHTNESS & MEDIA
-- ==============================================================================

-- Controls with Quickshell OSD
bind("volume-up",   "Media", "Volume up",   "XF86AudioRaiseVolume", hl.dsp.global("quickshell:volume_up"),   { repeating = true, locked = true })
bind("volume-down", "Media", "Volume down", "XF86AudioLowerVolume", hl.dsp.global("quickshell:volume_down"), { repeating = true, locked = true })
bind("volume-mute", "Media", "Mute",        "XF86AudioMute",        hl.dsp.global("quickshell:volume_mute"))
bind("mic-mute",    "Media", "Mute microphone", "XF86AudioMicMute", hl.dsp.global("quickshell:mic_mute"))

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

-- Tapping Super alone (bound on release, conf/binds.lua)
bind("launcher",          "Shell", "App launcher",      mainMod .. " + SUPER_L",   hl.dsp.global("quickshell:app_launcher"))
bind("clipboard-history", "Shell", "Clipboard history", mainMod .. " + V",         hl.dsp.global("quickshell:clipboard_history"))
bind("screenshot",        "Shell", "Screenshot",        "Print",                   hl.dsp.global("quickshell:take_screenshot"))
bind("power-menu",        "Shell", "Power menu",        mainMod .. " + End",       hl.dsp.global("quickshell:power_menu"))
bind("lock-screen",       "Shell", "Lock screen",       mainMod .. " + Escape",    hl.dsp.global("quickshell:lock_screen"))
bind("wallpapers",        "Shell", "Wallpaper picker",  mainMod .. " + B",         hl.dsp.global("quickshell:wallpaper_picker"))
bind("settings",          "Shell", "Settings",          mainMod .. " + I",         hl.dsp.global("quickshell:settings"))
bind("keybinds",          "Shell", "Keybinds",          "",                        hl.dsp.global("quickshell:keybinds_help"))
bind("reload",            "Shell", "Reload Quickshell", mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("lyne reload"))

-- ==============================================================================
-- KEYBOARD
-- ==============================================================================

-- Layouts of Settings › Hyprland › Keyboard: the keyboard typed on last and
-- the others with the same layouts (not those with layouts of their own)
local switchLayout = vars.scriptPath .. "/Keyboard/switch-layout.sh"
bind("switch-layout",   "Keyboard", "Next keyboard layout",     mainMod .. " + Space", hl.dsp.exec_cmd(switchLayout .. " next"))
bind("previous-layout", "Keyboard", "Previous keyboard layout", "",                    hl.dsp.exec_cmd(switchLayout .. " prev"))

binds.export()
