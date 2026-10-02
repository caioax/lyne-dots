-----------------------------
---- NAVIGATION PRESETS ----
-----------------------------

-- Starting keys for moving around, chosen in Settings › Hyprland ›
-- Keybinds (Navigation keys) or the welcome screen. local/settings.lua
-- (generated) calls lyne_bind_preset(name) from conf/binds.lua, which makes
-- these the default keys of the binds below; the user's own changes are
-- applied after it, so they stay.
--   vim     the keys of conf/keybinds.lua: H/J/K/L
--   arrows  the arrow keys instead of H/J/K/L
--   both    H/J/K/L plus the arrow keys on the "(arrow)" binds

local directions = { left = "left", right = "right", up = "up", down = "down" }

-- Modifiers of each directional group, as in conf/keybinds.lua
local groups = {
    focus = "SUPER",
    move = "SUPER + SHIFT",
    resize = "SUPER + ALT",
}

-- Workspace steps: next is right, previous is left
local steps = {
    ["workspace-next"] = "SUPER + CTRL + right",
    ["workspace-prev"] = "SUPER + CTRL + left",
    ["move-to-next"] = "SUPER + CTRL + SHIFT + right",
    ["move-to-prev"] = "SUPER + CTRL + SHIFT + left",
}

local function arrow_keys(suffix)
    local keys = {}
    for group, mods in pairs(groups) do
        for dir, key in pairs(directions) do
            keys[group .. "-" .. dir .. suffix] = mods .. " + " .. key
        end
    end
    for id, combo in pairs(steps) do
        keys[id .. suffix] = combo
    end
    return keys
end

return {
    vim = {},
    arrows = arrow_keys(""),
    both = arrow_keys("-alt"),
}
