-----------------
---- VARIABLES ----
-----------------

return {
    -- Default apps of the Apps binds (conf/keybinds.lua) until Quickshell
    -- writes the ones chosen in Settings > System > Apps to local/settings.lua
    terminal    = "kitty",
    fileManager = "dolphin",
    browser     = "zen-browser",
    scriptPath  = os.getenv("HOME") .. "/.local/scripts",
}
