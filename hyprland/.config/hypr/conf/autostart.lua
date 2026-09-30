-------------------
---- AUTOSTART ----
-------------------

-- Programs started once Hyprland is up:
--   * the essential ones below, always (Settings › System › Autostart lists
--     them as "System", exported to $XDG_RUNTIME_DIR/lyne-autostart.json)
--   * your apps, added in that page: local/settings.lua (generated) calls
--     lyne_autostart() with them
-- Apps of special workspaces started at login are set in Settings ›
-- Hyprland › Specials (conf/specials.lua).

local vars = require("conf/variables")
local HOME = os.getenv("HOME")

local system = {
    { name = "Quickshell",        command = "quickshell",
      about = "Bar, notifications, launcher and this settings window" },
    { name = "Polkit agent",      command = "/usr/lib/polkit-kde-authentication-agent-1",
      about = "Asks for your password when an app needs admin rights" },
    { name = "KDE app cache",     command = "kbuildsycoca6",
      about = "Lets KDE apps (Dolphin's Open with...) find your apps" },
    { name = "Hyprsunset",        command = "hyprsunset",
      about = "Night light" },
    { name = "Wallpaper daemon",  command = "awww-daemon",
      about = "Draws the wallpaper" },
    { name = "Wallpaper",         command = "sleep 1 && " .. vars.scriptPath .. "/Wallpaper/wallpaper-boot.sh",
      about = "Restores the wallpaper of the last session" },
    -- Text and image watchers, with the options from Settings › Clipboard
    { name = "Clipboard history", command = HOME .. "/.config/quickshell/scripts/cliphist-watch.sh",
      about = "Keeps what you copy for the clipboard history" },
}

hl.on("hyprland.start", function()
    for _, app in ipairs(system) do
        hl.exec_cmd(app.command)
    end
end)

local function json_string(s)
    s = tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    return '"' .. s .. '"'
end

local RUNTIME = os.getenv("XDG_RUNTIME_DIR") or "/tmp"

-- The system list for Quickshell
do
    local items = {}
    for _, app in ipairs(system) do
        table.insert(items, string.format('{"name":%s,"command":%s,"about":%s}',
            json_string(app.name), json_string(app.command), json_string(app.about)))
    end
    local file = io.open(RUNTIME .. "/lyne-autostart.json", "w")
    if file then
        file:write('{"system":[' .. table.concat(items, ",") .. "]}\n")
        file:close()
    end
end

-- Delayed apps: kept here so the timers aren't collected before they fire
LYNE_AUTOSTART_TIMERS = {}

-- Your apps: { name, command, delay (seconds), workspace ("" or a
-- workspace like "3 silent"), enabled }
function lyne_autostart(list)
    hl.on("hyprland.start", function()
        for _, app in ipairs(list) do
            local command = app.command or ""
            if app.enabled ~= false and command ~= "" then
                local workspace = app.workspace or ""
                local function run()
                    if workspace ~= "" then
                        hl.exec_cmd(command, { workspace = workspace })
                    else
                        hl.exec_cmd(command)
                    end
                end
                local delay = tonumber(app.delay) or 0
                if delay > 0 then
                    table.insert(LYNE_AUTOSTART_TIMERS, hl.timer(run, { timeout = math.floor(delay * 1000), type = "oneshot" }))
                else
                    run()
                end
            end
        end
    end)
end

-- Reads a hand-written autostart file (the old local/autostart.lua) without
-- running anything, for Settings and the migration that import it: its
-- hyprland.start handlers run against a stand-in `hl` whose exec_cmd only
-- records the command. Writes JSON to `out`:
--   {"ok":true,"error":"","apps":[{"command","workspace","delay"}],"other":N}
-- `other` counts what can't be imported (binds, options, commands run on
-- every reload...); the file must stay when it isn't 0
function lyne_autostart_import(path, out)
    local apps, other = {}, 0
    local in_start, delay = false, 0

    -- Anything else: callable and indexable, counted when called
    local function stub()
        return setmetatable({}, {
            __index = function() return stub() end,
            __call = function() other = other + 1; return stub() end,
        })
    end

    local fake = setmetatable({
        on = function(event, fn)
            if event ~= "hyprland.start" then
                other = other + 1
                return
            end
            in_start = true
            local ok = pcall(fn)
            in_start = false
            if not ok then
                other = other + 1
            end
        end,
        exec_cmd = function(command, opts)
            if not in_start or type(command) ~= "string" then
                other = other + 1
                return
            end
            table.insert(apps, {
                command = command,
                workspace = type(opts) == "table" and type(opts.workspace) == "string" and opts.workspace or "",
                delay = delay,
            })
        end,
        -- A delayed command: recorded with its delay
        timer = function(fn, opts)
            if not in_start then
                other = other + 1
                return stub()
            end
            local before = delay
            delay = math.floor(((type(opts) == "table" and tonumber(opts.timeout)) or 0) / 1000)
            pcall(fn)
            delay = before
            return stub()
        end,
    }, { __index = function() return stub() end })

    local env = setmetatable({ hl = fake }, { __index = _G })
    local ok, err = false, nil
    local chunk
    chunk, err = loadfile(path, "t", env)
    if chunk then
        ok, err = pcall(chunk)
    end

    local items = {}
    for _, app in ipairs(apps) do
        table.insert(items, string.format('{"command":%s,"workspace":%s,"delay":%d}',
            json_string(app.command), json_string(app.workspace), app.delay))
    end
    local file = io.open(out, "w")
    if file then
        file:write(string.format('{"ok":%s,"error":%s,"apps":[%s],"other":%d}\n',
            tostring(ok), json_string(ok and "" or tostring(err)), table.concat(items, ","), other))
        file:close()
    end
end
