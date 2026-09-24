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
