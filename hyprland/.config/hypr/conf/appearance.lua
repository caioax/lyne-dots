------------------
---- APPEARANCE ----
------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/

-- Some values here are overridden by local/settings.lua, generated from the
-- Quickshell settings window (Hyprland pages). Change those there, or in the
-- "hyprland" block of state.json.

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 5,

        border_size = 2,

        col = {
            active_border   = "rgba(6F92E0ff)",
            inactive_border = "rgba(595959aa)",
        },

        -- Set to true enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        -- Original file set rounding = 6 then rounding = 7 further down in the same
        -- block; hyprlang applies the last value, so 7 is the effective one here.
        rounding       = 7,
        rounding_power = 6,

        active_opacity     = 1.0,
        inactive_opacity   = 1.0,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },

        -- https://wiki.hypr.land/Configuring/Basics/Variables/#blur
        blur = {
            enabled  = true,
            size     = 8,
            passes   = 2,
            brightness = 1.0,
            noise    = 0.00,
            contrast = 1.0,
            xray     = false,
            popups   = true,
            popups_ignorealpha = 0.5,

            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Animation curves
hl.curve("specialWorkSwitch", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
hl.curve("emphasizedAccel",   { type = "bezier", points = { {0.3, 0},    {0.8, 0.15} } })
hl.curve("emphasizedDecel",   { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
hl.curve("standard",          { type = "bezier", points = { {0.2, 0},    {0, 1} } })

-- Animation configs
hl.animation({ leaf = "layersIn",  enabled = true, speed = 4, bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 4, bezier = "emphasizedAccel", style = "slide" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 4, bezier = "standard" })

hl.animation({ leaf = "windowsIn",   enabled = true, speed = 3, bezier = "emphasizedDecel" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3, bezier = "emphasizedAccel" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, bezier = "standard" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 4, bezier = "standard" })

hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "specialWorkSwitch", style = "slidefadevert 15%" })

hl.animation({ leaf = "fade",    enabled = true, speed = 4, bezier = "standard" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 4, bezier = "standard" })
hl.animation({ leaf = "border",  enabled = true, speed = 4, bezier = "standard" })

-- QuickShell layer surfaces
hl.layer_rule({
    name  = "modules",
    match = { namespace = "qs_modules" },

    blur         = true,
    ignore_alpha = 0.3,
    no_anim      = true,
})

-- The bar and the panels attached to it (bar.attachPopups) blur only the
-- wallpaper (xray), so they share one tint whatever window is behind them
hl.layer_rule({
    name  = "attached",
    match = { namespace = "qs_attached" },

    blur         = true,
    ignore_alpha = 0.3,
    no_anim      = true,
    xray         = true,
})

-- Notification popups float over windows like the bar popups, so they blur
-- what is behind them (no xray)
hl.layer_rule({
    name  = "notifications",
    match = { namespace = "qs_notifications" },

    blur         = true,
    ignore_alpha = 0.3,
    no_anim      = true,
})

hl.layer_rule({
    name  = "power",
    match = { namespace = "qs_powerOverlay" },

    blur         = true,
    no_anim      = true,
    ignore_alpha = 0,
})

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true,
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

hl.config({
    misc = {
        force_default_wallpaper = 0, -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true, -- If true disables the random hyprland logo / anime girl background. :(
    },
})
