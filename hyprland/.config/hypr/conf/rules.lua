-------------
---- RULES ----
-------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/ for more
-- See https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/ for workspace rules

-- Ignore maximize requests from all apps
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Picture-in-Picture (YouTube, etc)
hl.window_rule({
    name  = "pip-window",
    match = { title = "^(Picture-in-Picture)$" },

    float    = true,
    pin      = true,
    no_shadow = true,
    size     = {600, 340},
    move     = {"100%-w-20", "100%-h-20"},
    no_initial_focus = true,
})

-- Satty (screenshot annotation)
hl.window_rule({
    name  = "satty-float",
    match = { class = "^(com\\.gabm\\.satty)$" },

    float  = true,
    center = true,
})

-- KCalc (calculator)
hl.window_rule({
    name  = "kcalc-float",
    match = { class = "^(org\\.kde\\.kcalc)$" },

    float  = true,
    size   = {360, 540},
    center = true,
    pin    = true,
})

-- Quickshell settings window (size = SettingsWindow.defaultSize; its size
-- buttons extend or fill from there)
hl.window_rule({
    name  = "quickshell-settings-float",
    match = { class = "^(org\\.quickshell)$", title = "^(Settings)$" },

    float  = true,
    size   = {960, 680},
    center = true,
})
