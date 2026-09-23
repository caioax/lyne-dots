# 010-install-mission-center.sh - Install Mission Center
#
# The QuickShell system monitor popup has a "Mission Center" button that
# opens it for a more detailed view. This installs the missing package for
# existing users.

if ! command -v missioncenter &>/dev/null; then
    if command -v pacman &>/dev/null; then
        echo "   Installing mission-center..."
        sudo pacman -S --needed --noconfirm mission-center
    else
        echo "   mission-center not found. Please install it manually."
    fi
else
    echo "   mission-center already installed, skipping"
fi
