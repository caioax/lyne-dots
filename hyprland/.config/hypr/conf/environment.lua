-- -----------------------------------------------------
-- ENVIRONMENT VARIABLES
-- -----------------------------------------------------

-- --- Hardware ---
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("AQ_FORCE_LINEAR_BLIT", "0")

-- --- XDG / Session ---
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_MENU_PREFIX", "arch-")

-- --- Toolkits (Qt, GTK) ---
hl.env("GTK_THEME", "adw-gtk3-dark")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- --- Cursors ---
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")

-- --- PATH ---
-- Once: every config reload runs this again with the PATH it set
local localBin = os.getenv("HOME") .. "/.local/bin"
local path = os.getenv("PATH") or ""
if not (":" .. path .. ":"):find(":" .. localBin .. ":", 1, true) then
    hl.env("PATH", localBin .. ":" .. path)
end

-- --- Scripts & Apps ---
-- Defines where hyprshot will save (if your script reads this variable)
hl.env("HYPRSHOT_DIR", os.getenv("HOME") .. "/Pictures/Screenshots")
