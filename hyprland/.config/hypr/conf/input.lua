-------------
---- INPUT ----
-------------

-- Some values here are overridden by local/settings.lua, generated from the
-- Quickshell settings window (Hyprland pages). Change those there, or in the
-- "hyprland" block of state.json.

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "alt-intl",
        repeat_delay = 250,
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        force_no_accel = true,

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- hl.config({ cursor = { no_hardware_cursors = false } })

-- Keyboards with their own layout are set in Settings › Hyprland › Keyboard
-- (hl.device lines in local/settings.lua).

local function json_string(s)
    s = tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    return '"' .. s .. '"'
end

local function split(text)
    local out = {}
    for part in (tostring(text or "") .. ","):gmatch("([^,]*),") do
        table.insert(out, (part:gsub("^%s+", ""):gsub("%s+$", "")))
    end
    return out
end

-- Reads a hand-written file of per-keyboard rules (the old
-- local/extra_input.lua) without running it, for Settings and the migration
-- that import it: hl.device() calls are recorded by a stand-in `hl`. Layouts
-- and variants are checked against xkeyboard-config's list (`lst`) and its
-- symbols files (some variants, like br's abnt2, aren't listed): an unknown
-- variant is dropped, a device with an unknown layout is left out. Writes
-- JSON to `out`:
--   {"ok":true,"error":"","devices":[{"name","kb_layout","kb_variant",
--    "kb_options"?,"kb_model"?}],"notes":[...],"other":N}
-- `other` counts what can't be imported (options other than kb_*, other
-- calls); the file must stay when it isn't 0
function lyne_keyboard_import(path, out, lst)
    local devices, notes, other = {}, {}, 0

    -- Known layouts, "layout:variant" pairs and models
    local layouts, variants, models = {}, {}, {}
    local known = false
    local list = io.open(lst or "/usr/share/X11/xkb/rules/evdev.lst", "r")
    if list then
        local section = ""
        for line in list:lines() do
            local head = line:match("^!%s*(%S+)")
            if head then
                section = head
            else
                local name, rest = line:match("^%s+(%S+)%s+(.*)$")
                if name then
                    if section == "layout" then
                        layouts[name] = true
                        known = true
                    elseif section == "model" then
                        models[name] = true
                    elseif section == "variant" then
                        local layout = rest:match("^([^:%s]+):")
                        if layout then
                            variants[layout .. ":" .. name] = true
                        end
                    end
                end
            end
        end
        list:close()
    end

    -- Sections of a symbols file the list doesn't name (br's "abnt2")
    local symbols_dir = (lst or "/usr/share/X11/xkb/rules/evdev.lst"):gsub("rules/[^/]*$", "symbols/")
    local sections = {}
    local function defined(layout, variant)
        if sections[layout] == nil then
            sections[layout] = {}
            local file = io.open(symbols_dir .. layout:gsub("[^%w_%-]", ""), "r")
            if file then
                for name in file:read("a"):gmatch('xkb_symbols%s+"([^"]+)"') do
                    sections[layout][name] = true
                end
                file:close()
            end
        end
        return sections[layout][variant] == true
    end

    local kb_keys = { kb_layout = true, kb_variant = true, kb_options = true, kb_model = true }

    local function stub()
        return setmetatable({}, {
            __index = function() return stub() end,
            __call = function() other = other + 1; return stub() end,
        })
    end

    local fake = setmetatable({
        device = function(spec)
            if type(spec) ~= "table" or type(spec.name) ~= "string" then
                other = other + 1
                return
            end
            local entry = { name = spec.name }
            for key, value in pairs(spec) do
                if kb_keys[key] then
                    entry[key] = tostring(value)
                elseif key ~= "name" then
                    other = other + 1
                end
            end
            table.insert(devices, entry)
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
    for _, d in ipairs(devices) do
        local names = split(d.kb_layout)
        local vars = split(d.kb_variant)
        local fixed, valid = {}, d.kb_layout ~= nil
        for i, layout in ipairs(names) do
            local variant = vars[i] or ""
            if known and not layouts[layout] then
                valid = false
                table.insert(notes, d.name .. ": unknown layout " .. layout .. ", left out")
            end
            if variant ~= "" and known and not variants[layout .. ":" .. variant] and not defined(layout, variant) then
                table.insert(notes, d.name .. ": " .. layout .. " has no variant " .. variant
                    .. (models[variant] and " (it's a keyboard model)" or "") .. ", dropped")
                variant = ""
            end
            table.insert(fixed, variant)
        end
        if valid then
            local variant = table.concat(fixed, ",")
            if not variant:find("[^,]") then
                variant = ""
            end
            local fields = {
                '"name":' .. json_string(d.name),
                '"kb_layout":' .. json_string(d.kb_layout),
                '"kb_variant":' .. json_string(variant),
            }
            if d.kb_options then
                table.insert(fields, '"kb_options":' .. json_string(d.kb_options))
            end
            if d.kb_model then
                table.insert(fields, '"kb_model":' .. json_string(d.kb_model))
            end
            table.insert(items, "{" .. table.concat(fields, ",") .. "}")
        elseif d.kb_layout == nil then
            -- Only options or a model: imported as they are
            local fields = { '"name":' .. json_string(d.name) }
            for _, key in ipairs({ "kb_variant", "kb_options", "kb_model" }) do
                if d[key] then
                    table.insert(fields, '"' .. key .. '":' .. json_string(d[key]))
                end
            end
            table.insert(items, "{" .. table.concat(fields, ",") .. "}")
        end
    end

    local quoted = {}
    for _, n in ipairs(notes) do
        table.insert(quoted, json_string(n))
    end
    local file = io.open(out, "w")
    if file then
        file:write(string.format('{"ok":%s,"error":%s,"devices":[%s],"notes":[%s],"other":%d}\n',
            tostring(ok), json_string(ok and "" or tostring(err)), table.concat(items, ","),
            table.concat(quoted, ","), other))
        file:close()
    end
end
