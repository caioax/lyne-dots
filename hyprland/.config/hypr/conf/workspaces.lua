------------------------------
---- WORKSPACES PER MONITOR ----
------------------------------

-- Each monitor owns a block of workspace ids: the first one 1-99, the
-- second 101-199, and so on. SUPER + 1..9 and next/previous act on the
-- block of the focused monitor.
--
-- A block belongs to the monitor itself (its description, so changing
-- ports or positions keeps it) and is remembered in
-- ~/.local/state/lyne/workspace-monitors.lua, also while the monitor is
-- disconnected: its workspaces move to another monitor meanwhile and the
-- workspace rules below bring them back when it's connected again.
-- New monitors get the first free block (left to right at login).
--
-- Settings > Hyprland > Workspaces reorders and forgets monitors (the
-- lyne_workspaces_* functions below) and sets how next/previous behave
-- (local/settings.lua calls lyne_workspaces()). Quickshell reads the blocks
-- from $XDG_RUNTIME_DIR/lyne-workspaces.json.

local M = {}

M.BLOCK = 100 -- ids per monitor
M.MAX = 99    -- workspaces per monitor

local HOME = os.getenv("HOME") or ""
local STATE_DIR = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")) .. "/lyne"
local STATE_FILE = STATE_DIR .. "/workspace-monitors.lua"
local EXPORT_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/lyne-workspaces.json"

-- Known monitors: { slot = 0.., desc = "...", name = "HDMI-A-1" }. `desc`
-- is empty for entries only known by port (migrated from the old
-- workspaces.lua, or monitors without an EDID); it's filled in once seen.
local known = {}

-- Next/previous: only stop at workspaces with windows, and go around past
-- the ends. Set by lyne_workspaces() from local/settings.lua
M.options = { skip_empty = false, wrap = false }

function lyne_workspaces(options)
    for key, value in pairs(options or {}) do
        M.options[key] = value
    end
end

-- ==============================================================================
-- STATE FILE
-- ==============================================================================

-- A broken file is kept aside (.bad) instead of being overwritten with
-- blocks handed out again
local function set_aside()
    os.rename(STATE_FILE, STATE_FILE .. ".bad")
end

local function load_state()
    local file = io.open(STATE_FILE, "r")
    if not file then
        return
    end
    file:close()
    local chunk = loadfile(STATE_FILE)
    if not chunk then
        set_aside()
        return
    end
    local ok, list = pcall(chunk)
    if not ok or type(list) ~= "table" then
        set_aside()
        return
    end
    for _, entry in ipairs(list) do
        if type(entry) == "table" and math.type(entry.slot) == "integer" and entry.slot >= 0 then
            table.insert(known, {
                slot = entry.slot,
                desc = type(entry.desc) == "string" and entry.desc or "",
                name = type(entry.name) == "string" and entry.name or "",
            })
        end
    end
end

local function lua_string(s)
    return string.format("%q", s)
end

-- Virtual outputs (hyprctl output create headless, screen sharing) get a
-- block for the session but aren't remembered
local function persistent(entry)
    return entry.desc ~= "" or not entry.name:match("^HEADLESS")
end

local save_retried = false

local function save_state()
    local lines = { "-- Workspace blocks per monitor (conf/workspaces.lua). Slot N owns ids N*100+1..N*100+99", "return {" }
    for _, entry in ipairs(known) do
        if persistent(entry) then
            table.insert(lines, string.format("    { slot = %d, desc = %s, name = %s },",
                entry.slot, lua_string(entry.desc), lua_string(entry.name)))
        end
    end
    table.insert(lines, "}")

    -- Written next to the target and renamed, so a crash never leaves half a file
    local tmp = STATE_FILE .. ".tmp"
    local file = io.open(tmp, "w")
    if not file then
        -- First run: create the directory and try again shortly
        if not save_retried then
            save_retried = true
            hl.exec_cmd("mkdir -p '" .. STATE_DIR .. "'")
            hl.timer(save_state, { timeout = 1000, type = "oneshot" })
        end
        return
    end
    file:write(table.concat(lines, "\n"), "\n")
    file:close()
    os.rename(tmp, STATE_FILE)
end

-- ==============================================================================
-- MONITORS
-- ==============================================================================

-- Rule selector of an entry: its description when known, else its port
local function selector(entry)
    if entry.desc ~= "" then
        return "desc:" .. entry.desc
    end
    return entry.name
end

local function entry_for(monitor)
    if not monitor then
        return nil
    end
    local desc = monitor.description or ""
    if desc ~= "" then
        for _, entry in ipairs(known) do
            if entry.desc == desc then
                return entry
            end
        end
    end
    -- Known by port only, or a monitor without a description
    for _, entry in ipairs(known) do
        if entry.desc == "" and entry.name == monitor.name then
            return entry
        end
    end
    return nil
end

local function free_slot()
    local used = {}
    for _, entry in ipairs(known) do
        used[entry.slot] = true
    end
    local slot = 0
    while used[slot] do
        slot = slot + 1
    end
    return slot
end

local function drop_rules(entry)
    for _, rule in ipairs(entry.rules or {}) do
        rule:set_enabled(false)
    end
    entry.rules = nil
end

-- Every id of the block goes to the monitor, the first one is its default
local function add_rules(entry)
    drop_rules(entry)
    local monitor = selector(entry)
    local base = entry.slot * M.BLOCK
    entry.rules = {}
    for i = 1, M.MAX do
        table.insert(entry.rules, hl.workspace_rule({ workspace = tostring(base + i), monitor = monitor, default = i == 1 }))
    end
end

local function json_string(s)
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
    return '"' .. s .. '"'
end

-- Blocks of the known monitors for Quickshell, with the port each one is
-- connected to now ("" = disconnected)
function M.export()
    local connected = {}
    for _, monitor in ipairs(hl.get_monitors()) do
        local entry = entry_for(monitor)
        if entry then
            connected[entry] = monitor.name
        end
    end
    local items = {}
    for _, entry in ipairs(known) do
        table.insert(items, string.format('{"slot":%d,"base":%d,"desc":%s,"name":%s,"connected":%s}',
            entry.slot, entry.slot * M.BLOCK, json_string(entry.desc), json_string(entry.name),
            json_string(connected[entry] or "")))
    end
    local file = io.open(EXPORT_FILE, "w")
    if file then
        file:write('{"block":', M.BLOCK, ',"max":', M.MAX, ',"monitors":[', table.concat(items, ","), "]}\n")
        file:close()
    end
end

-- Remembers a monitor, filling in what changed (description of a port-only
-- entry, current port); returns its entry and whether it's new
local function remember(monitor)
    local entry = entry_for(monitor)
    local desc = monitor.description or ""
    if entry then
        local changed = false
        if entry.desc == "" and desc ~= "" then
            entry.desc = desc
            changed = true
            add_rules(entry) -- by description from now on
        end
        if entry.name ~= monitor.name then
            entry.name = monitor.name
            changed = true
        end
        if changed then
            save_state()
        end
        return entry, false
    end

    entry = { slot = free_slot(), desc = desc, name = monitor.name }
    table.insert(known, entry)
    add_rules(entry)
    save_state()
    return entry, true
end

local function in_block(id, entry)
    local base = entry.slot * M.BLOCK
    return id > base and id <= base + M.MAX
end

-- A monitor that had no rules yet got some other workspace from Hyprland
-- (the first id free of rules, like 11): show the first one of its block,
-- keeping the focus where it was
local function show_own_block(monitor, entry)
    local active = monitor.active_workspace
    if active and in_block(active.id, entry) then
        return
    end
    local target = entry.slot * M.BLOCK + 1
    local previous = hl.get_active_monitor()
    if hl.get_workspace(target) then
        -- Already open elsewhere: rules only place new workspaces
        hl.dispatch(hl.dsp.workspace.move({ workspace = target, monitor = monitor.name }))
    else
        hl.dispatch(hl.dsp.focus({ monitor = monitor.name }))
        hl.dispatch(hl.dsp.focus({ workspace = target }))
    end
    if previous and previous.name ~= monitor.name then
        hl.dispatch(hl.dsp.focus({ monitor = previous.name }))
    end
end

-- Monitors connected before Hyprland started are placed left to right
local function adopt_all()
    local monitors = hl.get_monitors()
    table.sort(monitors, function(a, b)
        if a.x ~= b.x then
            return a.x < b.x
        end
        return a.y < b.y
    end)
    local new = {}
    for _, monitor in ipairs(monitors) do
        local entry, is_new = remember(monitor)
        if is_new then
            table.insert(new, { name = monitor.name, entry = entry })
        end
    end
    -- Dispatches are dropped while the config is being read (reloads)
    if #new > 0 then
        hl.timer(function()
            for _, item in ipairs(new) do
                local monitor = hl.get_monitor(item.name)
                if monitor then
                    show_own_block(monitor, item.entry)
                end
            end
        end, { timeout = 100, type = "oneshot" })
    end
    M.export()
end

-- ==============================================================================
-- ACTIONS (used by the binds in conf/keybinds.lua)
-- ==============================================================================

-- First id of a monitor's block, minus one
local function base_of(monitor)
    local entry = entry_for(monitor)
    return entry and entry.slot * M.BLOCK or 0
end

-- Workspace n of the focused monitor
function M.go(n)
    hl.dispatch(hl.dsp.focus({ workspace = base_of(hl.get_active_monitor()) + n }))
end

-- Moves the active window to workspace n of the focused monitor (and follows it)
function M.move(n)
    hl.dispatch(hl.dsp.window.move({ workspace = base_of(hl.get_active_monitor()) + n }))
end

-- Next (1) or previous (-1) workspace id of a monitor's block, following
-- M.options, or nil when there's none. From another block's workspace it
-- goes to the first one (next) or the last busy one (previous)
function M.step_target(direction, monitor)
    if not monitor then
        return nil
    end
    local base = base_of(monitor)
    local active = monitor.active_workspace
    local id = active and active.id or 0
    local current = (id > base and id <= base + M.MAX) and id - base or nil

    local occupied, highest = {}, 0
    for _, workspace in ipairs(hl.get_workspaces()) do
        local position = workspace.id - base
        if position >= 1 and position <= M.MAX and workspace.windows > 0 then
            occupied[position] = true
            highest = math.max(highest, position)
        end
    end

    -- Positions next/previous can land on, in order. Going around, the end
    -- is the last busy workspace (plus one empty one unless skipping them)
    local stops = {}
    if M.options.skip_empty then
        for position = 1, M.MAX do
            if occupied[position] or position == current then
                table.insert(stops, position)
            end
        end
    else
        local last = M.MAX
        if M.options.wrap then
            last = math.min(M.MAX, math.max(highest + 1, current or 1))
        end
        for position = 1, last do
            table.insert(stops, position)
        end
    end
    if #stops == 0 then
        return nil
    end
    if not current then
        return base + (direction > 0 and stops[1] or (highest > 0 and highest or stops[1]))
    end

    local target
    if direction > 0 then
        for _, position in ipairs(stops) do
            if position > current then
                target = position
                break
            end
        end
        if not target and M.options.wrap then
            target = stops[1]
        end
    else
        for i = #stops, 1, -1 do
            if stops[i] < current then
                target = stops[i]
                break
            end
        end
        if not target and M.options.wrap then
            target = stops[#stops]
        end
    end
    if not target or target == current then
        return nil
    end
    return base + target
end

function M.step(direction)
    local target = M.step_target(direction, hl.get_active_monitor())
    if target then
        hl.dispatch(hl.dsp.focus({ workspace = target }))
    end
end

function M.move_step(direction)
    local target = M.step_target(direction, hl.get_active_monitor())
    if target then
        hl.dispatch(hl.dsp.window.move({ workspace = target }))
    end
end

-- Dispatcher for Quickshell's bar (mouse wheel over a monitor's strip):
-- `hyprctl dispatch 'lyne_workspace_step(1, "eDP-1")'`
function lyne_workspace_step(direction, monitor_name)
    local target = M.step_target(direction, hl.get_monitor(monitor_name))
    if target then
        return hl.dsp.focus({ workspace = target })
    end
    return hl.dsp.no_op()
end

-- ==============================================================================
-- MANAGING MONITORS (Settings > Hyprland > Workspaces, via hyprctl eval)
-- ==============================================================================

local function entry_at(slot)
    for _, entry in ipairs(known) do
        if entry.slot == slot then
            return entry
        end
    end
    return nil
end

-- Gives the workspaces open in block `from` the same positions in block
-- `to` (windows stay where they are)
local function renumber(from, to)
    for _, workspace in ipairs(hl.get_workspaces()) do
        local position = workspace.id - from * M.BLOCK
        if position >= 1 and position <= M.MAX then
            hl.dispatch(hl.dsp.workspace.change_id({ workspace = workspace.id, id = to * M.BLOCK + position }))
        end
    end
end

-- Swaps the blocks of two slots (either may be free), renumbering the
-- open workspaces through a spare block so no id is taken midway
function lyne_workspaces_swap(slot_a, slot_b)
    if slot_a == slot_b or slot_a < 0 or slot_b < 0 then
        return
    end
    local a, b = entry_at(slot_a), entry_at(slot_b)
    if not a and not b then
        return
    end
    local spare = math.max(slot_a, slot_b, free_slot()) + 1
    for _, entry in ipairs(known) do
        spare = math.max(spare, entry.slot + 1)
    end
    renumber(slot_a, spare)
    renumber(slot_b, slot_a)
    renumber(spare, slot_b)

    if a then
        a.slot = slot_b
    end
    if b then
        b.slot = slot_a
    end
    -- Both old rule sets go before the new ones are made (a slot left free
    -- keeps none)
    if a then
        drop_rules(a)
    end
    if b then
        drop_rules(b)
    end
    if a then
        add_rules(a)
    end
    if b then
        add_rules(b)
    end
    save_state()
    M.export()
end

-- Forgets a disconnected monitor: its slot is free for the next new one
function lyne_workspaces_forget(slot)
    for i, entry in ipairs(known) do
        if entry.slot == slot then
            for _, monitor in ipairs(hl.get_monitors()) do
                if entry_for(monitor) == entry then
                    return -- connected
                end
            end
            drop_rules(entry)
            table.remove(known, i)
            save_state()
            M.export()
            return
        end
    end
end

-- ==============================================================================
-- SETUP
-- ==============================================================================

load_state()
for _, entry in ipairs(known) do
    add_rules(entry)
end

-- On a config reload the monitors are already there; at login they show up
-- one by one before hyprland.start, which places the new ones in order
local started = #hl.get_monitors() > 0
if started then
    adopt_all()
else
    hl.on("hyprland.start", function()
        started = true
        adopt_all()
    end)
end

-- Monitors plugged in later
hl.on("monitor.added", function(monitor)
    if not started then
        return
    end
    local entry, is_new = remember(monitor)
    if is_new then
        show_own_block(monitor, entry)
    end
    M.export()
end)

-- The removed monitor is still listed while its event runs
hl.on("monitor.removed", function()
    hl.timer(M.export, { timeout = 200, type = "oneshot" })
end)

return M
