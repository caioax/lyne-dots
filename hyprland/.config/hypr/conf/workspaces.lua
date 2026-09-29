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
-- lyne_workspaces_* functions below), sets how next/previous behave and
-- whether closing the laptop lid turns its screen off while another monitor
-- is connected (local/settings.lua calls lyne_workspaces()). Quickshell reads the blocks
-- from $XDG_RUNTIME_DIR/lyne-workspaces.json.

local M = {}

-- Internal outputs the lid turned off in this config (see LAPTOP LID)
M.lid_off_outputs = {}

M.BLOCK = 100 -- ids per monitor
M.MAX = 99    -- workspaces per monitor

local HOME = os.getenv("HOME") or ""
local STATE_DIR = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")) .. "/lyne"
local STATE_FILE = STATE_DIR .. "/workspace-monitors.lua"
local EXPORT_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/lyne-workspaces.json"

-- Known monitors: { slot = 0.., desc = "...", name = "HDMI-A-1", twin }.
-- `desc` is empty for entries only known by port (migrated from the old
-- workspaces.lua, or monitors without an EDID); it's filled in once seen.
-- `twin`: two monitors share the description (same model, no serial), so
-- they're told apart by port for good.
local known = {}

-- Next/previous: only stop at workspaces with windows, and go around past
-- the ends; lid_off: see LAPTOP LID. Set by lyne_workspaces() from
-- local/settings.lua
M.options = { skip_empty = false, wrap = false, lid_off = true }

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
        if type(entry) == "table" and math.type(entry.slot) == "integer" and entry.slot >= 0
            and entry.name ~= "FALLBACK" then
            table.insert(known, {
                slot = entry.slot,
                desc = type(entry.desc) == "string" and entry.desc or "",
                name = type(entry.name) == "string" and entry.name or "",
                twin = entry.twin == true,
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
            table.insert(lines, string.format("    { slot = %d, desc = %s, name = %s%s },",
                entry.slot, lua_string(entry.desc), lua_string(entry.name), entry.twin and ", twin = true" or ""))
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

-- Rule selector of an entry: its description when it tells it apart,
-- else its port
local function selector(entry)
    if entry.desc ~= "" and not entry.twin then
        return "desc:" .. entry.desc
    end
    return entry.name
end

-- Outputs that never get a block: the FALLBACK one Hyprland makes when no
-- monitor is left, and mirrors (they show another monitor's workspaces)
local function ignored(monitor)
    return monitor.name == "FALLBACK" or monitor.is_mirror == true
end

-- Another connected monitor has the same description
local function shared_desc(monitor)
    local desc = monitor.description or ""
    if desc == "" then
        return false
    end
    for _, other in ipairs(hl.get_monitors()) do
        if other.name ~= monitor.name and (other.description or "") == desc then
            return true
        end
    end
    return false
end

local function entry_for(monitor)
    if not monitor or ignored(monitor) then
        return nil
    end
    local desc = monitor.description or ""
    if desc ~= "" and not shared_desc(monitor) then
        for _, entry in ipairs(known) do
            if entry.desc == desc and not entry.twin then
                return entry
            end
        end
    end
    -- By port: known only by port, a monitor without a description, or
    -- one of two alike
    for _, entry in ipairs(known) do
        if entry.name == monitor.name and (entry.desc == "" or entry.desc == desc) then
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
        table.insert(items, string.format('{"slot":%d,"base":%d,"desc":%s,"name":%s,"connected":%s,"lidOff":%s}',
            entry.slot, entry.slot * M.BLOCK, json_string(entry.desc), json_string(entry.name),
            json_string(connected[entry] or ""), tostring(M.lid_off_outputs[entry.name] == true)))
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
    local desc = monitor.description or ""
    -- Two alike: every entry with this description goes by port from now on
    if shared_desc(monitor) then
        local split = false
        for _, other in ipairs(known) do
            if other.desc == desc and not other.twin then
                other.twin = true
                split = true
                add_rules(other)
            end
        end
        if split then
            save_state()
        end
    end

    local entry = entry_for(monitor)
    if entry then
        local changed = false
        if entry.desc == "" and desc ~= "" and not entry.twin and not shared_desc(monitor) then
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

    entry = { slot = free_slot(), desc = desc, name = monitor.name, twin = shared_desc(monitor) }
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
-- (the first id free of rules, like 11), or a known one came back on an
-- empty leftover (the FALLBACK output's): show the first one of its block,
-- keeping the focus where it was
local function show_own_block(monitor, entry)
    local active = monitor.active_workspace
    if active and in_block(active.id, entry) then
        return
    end
    local target = entry.slot * M.BLOCK + 1
    local previous = hl.get_active_monitor()
    local existing = hl.get_workspace(target)
    if existing and existing.monitor and existing.monitor.name ~= monitor.name then
        -- Open on another monitor: rules only place new workspaces
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
        if not ignored(monitor) then
            local entry, is_new = remember(monitor)
            if is_new then
                table.insert(new, { name = monitor.name, entry = entry })
            end
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
-- (not a laptop screen the lid turned off)
function lyne_workspaces_forget(slot)
    for i, entry in ipairs(known) do
        if entry.slot == slot and not M.lid_off_outputs[entry.name] then
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
-- LAPTOP LID
-- ==============================================================================

-- With lid_off and another monitor connected, closing the lid turns the
-- laptop screen off: its workspaces move to the other monitor (shown there
-- as guests) and come back when the lid opens. logind ignores the lid while
-- another monitor is connected, so the laptop doesn't suspend.

local function is_internal(name)
    return name:match("^eDP") or name:match("^LVDS") or name:match("^DSI")
end

-- LYNE_LID_STATE_FILE points the tests at a fake lid. Without an ACPI lid
-- file, the state the lid switch last reported is used (saved below)
local LID_EVENT_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/lyne-lid-state"
local LID_FILES = { os.getenv("LYNE_LID_STATE_FILE") or "/proc/acpi/button/lid/LID0/state",
    "/proc/acpi/button/lid/LID/state", "/proc/acpi/button/lid/LID1/state",
    "/proc/acpi/button/lid/LID2/state", LID_EVENT_FILE }

function M.lid_closed()
    for _, path in ipairs(LID_FILES) do
        local file = io.open(path, "r")
        if file then
            local text = file:read("a") or ""
            file:close()
            return text:find("closed") ~= nil
        end
    end
    return false
end

local function lid_switched(state)
    local file = io.open(LID_EVENT_FILE, "w")
    if file then
        file:write(state, "\n")
        file:close()
    end
    M.apply_lid()
end

-- A real other screen: not the laptop's, nor the FALLBACK output Hyprland
-- makes when none is left, nor a virtual one
local function external_connected()
    for _, monitor in ipairs(hl.get_monitors()) do
        local name = monitor.name
        if not is_internal(name) and name ~= "FALLBACK" and not name:match("^HEADLESS") then
            return true
        end
    end
    return false
end

local function lid_turns_off()
    return M.options.lid_off and M.lid_closed() and external_connected()
end

-- Laptop screens known here (their ports), also while turned off
local function internal_outputs()
    local names = {}
    for _, entry in ipairs(known) do
        if is_internal(entry.name) then
            table.insert(names, entry.name)
        end
    end
    return names
end

-- Monitor rules only apply when the config is read, so the lid works
-- through reloads: hyprland.lua calls this after monitors.lua, turning the
-- laptop screen off while the lid keeps it closed (on every reload, so it
-- never flashes on). `turned_off` tells whether this config did
local turned_off = false

function lyne_lid_rules()
    if lid_turns_off() then
        for _, name in ipairs(internal_outputs()) do
            hl.monitor({ output = name, disabled = true })
            M.lid_off_outputs[name] = true
            turned_off = true
        end
        M.export() -- Settings shows it as off, not disconnected
    end
end

-- "<time of the last lid reload> <reloads within a minute>"
local RELOAD_MARK = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/lyne-lid-reload"
local retry_pending = false

-- Reloads when the lid (or a monitor coming or going) changed whether the
-- laptop screen should be off. At most one reload every few seconds (a
-- change meanwhile is retried after it) and eight a minute, so a rule that
-- doesn't take can't loop fast
function M.apply_lid()
    if turned_off == lid_turns_off() then
        return
    end

    local now = os.time()
    local last, count = 0, 0
    local mark = io.open(RELOAD_MARK, "r")
    if mark then
        local text = mark:read("a") or ""
        mark:close()
        last, count = text:match("(%d+) (%d+)")
        last, count = tonumber(last) or 0, tonumber(count) or 0
    end
    if now - last > 60 then
        count = 0
    end
    if count >= 8 then
        return
    end
    if now - last < 5 then
        if not retry_pending then
            retry_pending = true
            hl.timer(function()
                retry_pending = false
                M.apply_lid()
            end, { timeout = (5 - (now - last)) * 1000 + 200, type = "oneshot" })
        end
        return
    end

    mark = io.open(RELOAD_MARK, "w")
    if mark then
        mark:write(now, " ", count + 1)
        mark:close()
    end
    hl.exec_cmd("hyprctl reload")
end

hl.bind("switch:on:Lid Switch", function() lid_switched("closed") end, { locked = true })
hl.bind("switch:off:Lid Switch", function() lid_switched("open") end, { locked = true })

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
        M.apply_lid() -- docked with the lid closed at login
    end)
end

-- Monitors plugged in later
hl.on("monitor.added", function(monitor)
    if not started then
        return
    end
    if ignored(monitor) then
        M.export()
        return
    end
    local entry, is_new = remember(monitor)
    local active = monitor.active_workspace
    if is_new or (active and active.windows == 0) then
        -- Deferred: this can run while a reload (the lid's) reads the config
        local name = monitor.name
        hl.timer(function()
            local current = hl.get_monitor(name)
            if current then
                show_own_block(current, entry)
            end
        end, { timeout = 100, type = "oneshot" })
    end
    M.export()
    -- A monitor plugged in with the lid closed
    if not is_internal(monitor.name) then
        M.apply_lid()
    end
end)

-- The removed monitor is still listed while its event runs
hl.on("monitor.removed", function()
    hl.timer(function()
        -- A removed output's workspaces land on the others; an empty one
        -- left active there (the FALLBACK output's) gives way to the
        -- monitor's own block
        for _, monitor in ipairs(hl.get_monitors()) do
            local entry = entry_for(monitor)
            local active = monitor.active_workspace
            if entry and active and active.windows == 0 then
                show_own_block(monitor, entry)
            end
        end
        M.export()
        -- The last other monitor left: the laptop screen comes back
        M.apply_lid()
    end, { timeout = 200, type = "oneshot" })
end)

-- Settings may have switched lid_off; the lid may have changed during a reload
hl.on("config.reloaded", function()
    M.apply_lid()
end)

return M
