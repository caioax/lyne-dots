# 009-install-zenity.sh - Install zenity
#
# The QuickShell wallpaper picker uses zenity as the file picker for the
# "add" button. This installs the missing package for existing users.

if ! command -v zenity &>/dev/null; then
    if command -v pacman &>/dev/null; then
        echo "   Installing zenity..."
        sudo pacman -S --needed --noconfirm zenity
    else
        echo "   zenity not found. Please install it manually."
    fi
else
    echo "   zenity already installed, skipping"
fi
