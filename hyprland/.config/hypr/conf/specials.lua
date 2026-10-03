-------------------------
---- SPECIAL WORKSPACES ----
-------------------------

-- Toggleable app workspaces (WhatsApp, music, scratchpad...). The list is
-- edited in Settings > Hyprland > Special workspaces: local/settings.lua
-- (generated) calls lyne_specials() with it. Without that file the defaults
-- below are used (hyprland.lua calls lyne_specials_fallback()).
--
-- Each special:
--   id         workspace name (special:<id>) and bind ids special-<id> / move-to-<id>
--   name       shown in the bar badge and in the bind descriptions
--   command    app opened when the workspace is shown empty ("" = none)
--   class      window class regex pinned to the workspace ("" = none), so
--              single-instance apps reopened from the tray land there too
--   keys       default toggle keys ("" = none), changed in Settings > Keybinds
--   move_keys  default "move window here" keys
--   autostart  open the app hidden in the workspace at login

local ok, binds = pcall(require, "conf/binds")
local bind = ok and binds.bind or function(_, _, _, keys, dispatcher, opts)
    if keys ~= "" then
        hl.bind(keys, dispatcher, opts)
    end
end

local defaults = {
    -- WhatsApp Web in its own Chromium profile
    { id = "whatsapp", name = "WhatsApp",   command = "chromium --app=https://web.whatsapp.com --user-data-dir=$HOME/.local/share/lyne/whatsapp --no-first-run --no-default-browser-check",
      class = "^(chrome-web\\.whatsapp\\.com__-Default)$", keys = "SUPER + W", move_keys = "SUPER + SHIFT + W", autostart = false },
    { id = "music",    name = "Music",      command = "spotify", class = "^([Ss]potify)$",            keys = "SUPER + M", move_keys = "SUPER + SHIFT + M", autostart = false },
}

-- Seconds the autostarted apps wait for the notification server
local NOTIFICATIONS_TIMEOUT = 30

-- Set once lyne_specials() ran in this config load
LYNE_SPECIALS_APPLIED = false

function lyne_specials(list)
    LYNE_SPECIALS_APPLIED = true
    local autostart = {}

    for _, spec in ipairs(list) do
        local workspace = "special:" .. spec.id
        local command = spec.command or ""

        if command ~= "" then
            hl.workspace_rule({ workspace = workspace, on_created_empty = command })
        end
        if (spec.class or "") ~= "" then
            hl.window_rule({
                name  = "lyne-special-" .. spec.id,
                match = { class = spec.class },

                workspace = workspace .. " silent",
            })
        end

        bind("special-" .. spec.id, "Special workspaces", "Toggle " .. spec.name, spec.keys or "", hl.dsp.workspace.toggle_special(spec.id))
        bind("move-to-" .. spec.id, "Special workspaces", "Move window to " .. spec.name, spec.move_keys or "", hl.dsp.window.move({ workspace = workspace }))

        if spec.autostart and command ~= "" then
            table.insert(autostart, { command = command, workspace = workspace })
        end
    end

    -- Opened straight into the hidden workspace, nothing shows up. Quickshell
    -- starts at the same time, and apps that look for the notification
    -- server only once (ZapZap, Chromium) would stay silent all session:
    -- wait until it's on the bus (the app still opens after the timeout)
    if #autostart > 0 then
        hl.on("hyprland.start", function()
            for _, app in ipairs(autostart) do
                local command = "gdbus wait --session --timeout " .. NOTIFICATIONS_TIMEOUT
                    .. " org.freedesktop.Notifications; " .. app.command
                hl.exec_cmd(command, { workspace = app.workspace .. " silent" })
            end
        end)
    end

    -- conf/keybinds.lua exported the catalog before these binds existed
    if ok then
        binds.export()
    end
end

function lyne_specials_fallback()
    if not LYNE_SPECIALS_APPLIED then
        lyne_specials(defaults)
    end
end
