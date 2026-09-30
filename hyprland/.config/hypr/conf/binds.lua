---------------------
---- BIND HELPERS ----
---------------------

-- Keybinds declared with bind() get an id, a group and a description, so
-- the Quickshell settings window can list them and change their keys:
--   * the catalog (defaults) is exported to $XDG_RUNTIME_DIR/lyne-keybinds.json
--   * local/settings.lua (generated) calls lyne_rebind() for changed keys
-- Plain hl.bind() still works for binds that shouldn't show up there.

local M = {}

-- Rebuilt on every config (re)load
LYNE_BINDS = { list = {}, by_id = {} }

-- A modifier alone ("SUPER + SUPER_L": tap Super) is bound on release:
-- Hyprland then runs it only when no other key was pressed meanwhile, so
-- Super + 1 still goes to workspace 1
local function lone_modifier(keys)
    local last = (keys:match("([^+]+)$") or ""):match("^%s*(.-)%s*$"):upper()
    return last:match("^SUPER_[LR]$") or last:match("^ALT_[LR]$")
        or last:match("^CONTROL_[LR]$") or last:match("^SHIFT_[LR]$")
end

local function opts_for(opts, keys)
    if not lone_modifier(keys) then
        return opts
    end
    local copy = {}
    for k, v in pairs(opts) do
        copy[k] = v
    end
    copy.release = true
    return copy
end

-- Inside a release bind Hyprland sends global shortcuts as "released" only,
-- and Quickshell acts on "pressed": the dispatcher runs a moment later,
-- outside the bind, where a global is a normal press
LYNE_LONE_TIMER = nil
local function dispatcher_for(dispatcher, keys)
    if not lone_modifier(keys) then
        return dispatcher
    end
    return function()
        -- Kept referenced until it fires
        LYNE_LONE_TIMER = hl.timer(function()
            if type(dispatcher) == "function" then
                dispatcher()
            else
                hl.dispatch(dispatcher)
            end
        end, { timeout = 1, type = "oneshot" })
    end
end
M.lone_modifier = lone_modifier

function M.bind(id, group, description, keys, dispatcher, opts)
    -- Copy: callers may share one options table between binds
    local copy = {}
    for k, v in pairs(opts or {}) do
        copy[k] = v
    end
    copy.description = description
    opts = copy

    local entry = {
        id = id,
        group = group,
        description = description,
        keys = keys,
        default = keys,
        dispatcher = dispatcher,
        opts = opts,
    }
    LYNE_BINDS.by_id[id] = entry
    table.insert(LYNE_BINDS.list, entry)

    -- No default keys: listed in Settings, bound once keys are set
    if keys ~= "" then
        hl.bind(keys, dispatcher_for(dispatcher, keys), opts_for(opts, keys))
    end
end

-- "super + shift + q" and "SUPER+SHIFT+Q" are the same combo
local mod_order = { SUPER = 1, CTRL = 2, CONTROL = 2, ALT = 3, SHIFT = 4 }
local function normalize(keys)
    local mods, key = {}, ""
    for raw in keys:gmatch("[^+]+") do
        -- Loop variables are constants in Hyprland's Lua: use a local
        local part = raw:match("^%s*(.-)%s*$"):upper()
        if mod_order[part] then
            table.insert(mods, part == "CONTROL" and "CTRL" or part)
        else
            key = part
        end
    end
    table.sort(mods, function(a, b) return mod_order[a] < mod_order[b] end)
    table.insert(mods, key)
    return table.concat(mods, "+")
end

-- Moves a bind to other keys ("" disables it). Called by local/settings.lua
function lyne_rebind(id, keys)
    local entry = LYNE_BINDS.by_id[id]
    if not entry then
        return
    end
    local old = entry.keys
    entry.keys = keys

    if old ~= "" then
        -- hl.unbind drops every bind on these keys: put back the others
        -- that share them (two actions on one combo)
        hl.unbind(old)
        local combo = normalize(old)
        for _, other in ipairs(LYNE_BINDS.list) do
            if other ~= entry and other.keys ~= "" and normalize(other.keys) == combo then
                hl.bind(other.keys, dispatcher_for(other.dispatcher, other.keys), opts_for(other.opts, other.keys))
            end
        end
    end
    if keys ~= "" then
        hl.bind(keys, dispatcher_for(entry.dispatcher, keys), opts_for(entry.opts, keys))
    end
end

local function json_string(s)
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
    return '"' .. s .. '"'
end

-- Writes the default keys of every bind() for Quickshell
function M.export()
    local items = {}
    for _, b in ipairs(LYNE_BINDS.list) do
        table.insert(items, string.format(
            '{"id":%s,"group":%s,"description":%s,"keys":%s}',
            json_string(b.id), json_string(b.group), json_string(b.description), json_string(b.default)))
    end

    local dir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
    local file = io.open(dir .. "/lyne-keybinds.json", "w")
    if file then
        file:write("[" .. table.concat(items, ",") .. "]\n")
        file:close()
    end
end

-- Empty submap Quickshell enters while recording a shortcut, so the keys
-- reach the settings window instead of triggering binds. A submap needs at
-- least one bind to exist; this one is just a way out
hl.define_submap("lyne_capture", function()
    hl.bind("CTRL + ALT + SHIFT + F24", hl.dsp.submap("reset"))
end)

return M
