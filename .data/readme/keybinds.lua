-- Keybindings table of the README, generated from the Hyprland config.
--
-- Runs conf/keybinds.lua and conf/specials.lua outside Hyprland with a
-- stand-in `hl`, collects every bind(id, group, description, keys, ...) and
-- prints Markdown tables grouped like Settings > Hyprland > Keybinds.
--
--   lua .data/readme/keybinds.lua             print the tables
--   lua .data/readme/keybinds.lua README.md   replace the block between
--                                             <!-- keybinds:start --> and
--                                             <!-- keybinds:end -->

local script_dir = (arg[0]:match("^(.*)/[^/]*$") or ".")
local dots = script_dir .. "/../.."
local hypr = dots .. "/hyprland/.config/hypr"

package.path = hypr .. "/?.lua;" .. package.path

-- Stand-in for Hyprland's `hl`: any field is a callable table, so
-- hl.dsp.window.move({...}) and friends just return a value
local function any()
    return setmetatable({}, {
        __index = function(t, k)
            local v = any()
            rawset(t, k, v)
            return v
        end,
        __call = function()
            return any()
        end,
    })
end
hl = any()

local binds = {}
package.preload["conf/binds"] = function()
    return {
        bind = function(id, group, description, keys)
            table.insert(binds, { id = id, group = group, description = description, keys = keys })
        end,
        export = function() end,
        lone_modifier = function() return false end,
    }
end
package.preload["conf/workspaces"] = function()
    return { go = function() end, move = function() end, step = function() end, move_step = function() end }
end

-- conf/variables.lua reads $HOME
require("conf/keybinds")
require("conf/specials")
lyne_specials_fallback()

-- Key names as printed in the README
local key_names = {
    ["return"] = "Enter", ["SUPER_L"] = "(tap)", ["slash"] = "/", ["equal"] = "=",
    ["minus"] = "-", ["TAB"] = "Tab", ["Space"] = "Space", ["left"] = "Left",
    ["right"] = "Right", ["Escape"] = "Esc", ["Print"] = "Print",
    ["XF86AudioRaiseVolume"] = "Volume Up", ["XF86AudioLowerVolume"] = "Volume Down",
    ["XF86AudioMute"] = "Mute", ["XF86AudioMicMute"] = "Mic Mute",
    ["XF86MonBrightnessUp"] = "Brightness Up", ["XF86MonBrightnessDown"] = "Brightness Down",
    ["XF86AudioNext"] = "Next", ["XF86AudioPrev"] = "Previous",
    ["XF86AudioPause"] = "Pause", ["XF86AudioPlay"] = "Play",
}
local mod_names = { SUPER = "Super", SHIFT = "Shift", CTRL = "Ctrl", CONTROL = "Ctrl", ALT = "Alt" }

local function pretty(keys)
    local parts = {}
    for part in keys:gmatch("[^+]+") do
        part = part:match("^%s*(.-)%s*$")
        table.insert(parts, mod_names[part:upper()] or key_names[part] or part)
    end
    -- "Super + (tap)" reads better as "Super (tap)"
    return (table.concat(parts, " + "):gsub(" %+ %(tap%)", " (tap)"))
end

-- Collapse numbered runs ("Go to workspace 1".."10") into one row and
-- alternative keys ("Next workspace (arrow)") into their main row
local rows, by_desc = {}, {}
for _, b in ipairs(binds) do
    if b.keys ~= "" then
        local keys = pretty(b.keys)
        local base = b.description:match("^(.-) %d+$")
        local alt = b.description:match("^(.-) %(.-%)$")
        local dir_base, dir = b.description:match("^(.-) (%a+)$")
        -- Only for modifier + key binds ("Volume up" is a key of its own)
        if not ({ left = true, right = true, up = true, down = true })[dir] or not keys:find(" + ", 1, true) then
            dir_base = nil
        end
        local key = (base and base .. " #") or (dir_base and dir_base .. " <dir>") or alt or b.description
        local row = by_desc[b.group .. "\0" .. key]
        if not row then
            local description = (base and base .. " 1–10") or (dir_base and dir_base) or key
            row = { group = b.group, description = description, keys = {}, numbered = base ~= nil, directional = dir_base ~= nil }
            by_desc[b.group .. "\0" .. key] = row
            table.insert(rows, row)
        end
        if row.directional then
            -- "Super + H" .. "Super + J" → "Super + H / L / K / J"
            local last = keys:match(" %+ (%S+)$")
            row.dirs = row.dirs or {}
            table.insert(row.dirs, dir)
            if #row.keys == 0 then
                row.keys[1] = keys
            else
                row.keys[1] = row.keys[1] .. " / " .. last
            end
        elseif row.numbered then
            -- Same modifiers, numbers 1..0: keep the first and show "1–0"
            if #row.keys == 0 then
                table.insert(row.keys, (keys:gsub("%d$", "1–0")))
            end
        else
            table.insert(row.keys, keys)
        end
    end
end

local groups, seen = {}, {}
for _, row in ipairs(rows) do
    if not seen[row.group] then
        seen[row.group] = true
        table.insert(groups, row.group)
    end
end

local out = {}
for i, group in ipairs(groups) do
    table.insert(out, "**" .. group .. "**")
    table.insert(out, "")
    table.insert(out, "| Keys | Action |")
    table.insert(out, "| --- | --- |")
    for _, row in ipairs(rows) do
        if row.group == group then
            local keys = {}
            for _, k in ipairs(row.keys) do
                table.insert(keys, "<kbd>" .. k:gsub(" %+ ", "</kbd> + <kbd>") .. "</kbd>")
            end
            local description = row.description
            if row.dirs then
                description = description .. " " .. table.concat(row.dirs, " / ")
            end
            table.insert(out, "| " .. table.concat(keys, " or ") .. " | " .. description .. " |")
        end
    end
    if i < #groups then
        table.insert(out, "")
    end
end
local block = table.concat(out, "\n")

local target = arg[1]
if not target then
    print(block)
    return
end

local f = assert(io.open(target, "r"))
local text = f:read("a")
f:close()
local start_tag, end_tag = "<!-- keybinds:start -->", "<!-- keybinds:end -->"
local s = text:find(start_tag, 1, true)
local e = text:find(end_tag, 1, true)
if not s or not e then
    io.stderr:write(target .. ": missing " .. start_tag .. " / " .. end_tag .. "\n")
    os.exit(1)
end
text = text:sub(1, s + #start_tag - 1) .. "\n\n" .. block .. "\n\n" .. text:sub(e)
f = assert(io.open(target, "w"))
f:write(text)
f:close()
