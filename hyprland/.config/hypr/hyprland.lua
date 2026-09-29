-- ###############
-- ### SOURCES ###
-- ###############
-- See https://wiki.hypr.land/Configuring/Start/

-- Core configurations (Managed by Git)
require("conf/variables")
require("conf/environment")
require("conf/autostart")
require("conf/appearance")
require("conf/input")
-- Workspaces per monitor. Guarded: an error inside a required file stops
-- this one silently, and the binds below still work without it
local ok, err = pcall(require, "conf/workspaces")
if not ok then
    print("[hyprland] conf/workspaces.lua failed: " .. tostring(err))
end
require("conf/keybinds")
require("conf/specials")
require("conf/rules")

-- Load all local overrides: every .lua file inside the local folder
-- (settings.lua from Settings, monitors.lua from Settings › Hyprland ›
-- Monitors...). Only .lua: backups like monitors.lua.bak must not run
require("./local/*.lua")

-- Special workspaces with the defaults when local/settings.lua has none
if lyne_specials_fallback then
    lyne_specials_fallback()
end

-- Monitors from before they moved to local/monitors.lua (migration 025
-- moves the file; until then, and without a file there, this keeps them)
if not lyne_monitors_file then
    pcall(require, "monitors")
end

-- Laptop screen off while its lid is closed and another monitor is
-- connected (conf/workspaces.lua): after the monitor rules, so it wins
if lyne_lid_rules then
    lyne_lid_rules()
end
