-----------------
---- AUTOSTART ----
-----------------

local vars = require("conf/variables")

-- Start essential programs, wallpaper daemon, cliphist, WhatsApp workspace
-- and the workspace manager once Hyprland is up.
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("kbuildsycoca6")
    hl.exec_cmd("hyprsunset")

    -- Wallpaper
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sleep 1 && " .. vars.scriptPath .. "/Wallpaper/wallpaper-boot.sh")

    -- Cliphist (clipboard history): text and image watchers, with the
    -- options from Quickshell's Settings › Clipboard
    hl.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/scripts/cliphist-watch.sh")

    -- Open WhatsApp on special workspace
    hl.exec_cmd(vars.scriptPath .. "/WhatsApp-Init/run.sh")

    -- Workspaces manager
    hl.exec_cmd(vars.scriptPath .. "/Workspace-Manager/workspace-manager.sh --auto-update")
end)
