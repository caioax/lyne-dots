# 044-qt5ct-bibata.sh - Plain qt5ct, and the Bibata cursor a new install missed
#
# qt5ct-kde needs KF5's qqc2-desktop-style5 and kirigami2, which left the
# repos and no longer build from the AUR: on a new install the theming
# packages' AUR batch stopped there and took bibata-cursor-theme down with
# it. The theming category installs plain qt5ct now, and the installer builds
# AUR packages one at a time. Where the theming packages are (qt6ct-kde):
# qt5ct when no qt5ct-kde stands for it, and Bibata when missing. An
# installed qt5ct-kde stays. A failed AUR build only warns: the cursor isn't
# worth stopping the chain for.

if command -v pacman &>/dev/null; then
    if pacman -Q qt6ct-kde &>/dev/null; then
        if pacman -Q qt5ct &>/dev/null || pacman -Q qt5ct-kde &>/dev/null; then
            echo "   qt5ct already installed, skipping"
        else
            echo "   Installing qt5ct..."
            sudo pacman -S --needed --noconfirm qt5ct
        fi

        if pacman -Q bibata-cursor-theme &>/dev/null; then
            echo "   bibata-cursor-theme already installed, skipping"
        elif command -v yay &>/dev/null; then
            echo "   Installing bibata-cursor-theme (AUR)..."
            yay -S --needed --noconfirm bibata-cursor-theme ||
                echo "   Bibata didn't build: try yay -S bibata-cursor-theme later, or pick a cursor in Settings > Cursor"
        elif command -v paru &>/dev/null; then
            echo "   Installing bibata-cursor-theme (AUR)..."
            paru -S --needed --noconfirm bibata-cursor-theme ||
                echo "   Bibata didn't build: try paru -S bibata-cursor-theme later, or pick a cursor in Settings > Cursor"
        else
            echo "   No AUR helper (yay/paru) found. Install bibata-cursor-theme manually (the default cursor)."
        fi
    fi
fi
