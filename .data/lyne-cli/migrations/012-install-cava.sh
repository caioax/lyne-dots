# 012-install-cava.sh - Install cava
#
# The QuickShell dashboard draws an audio visualizer around the cover in its
# Media tab, fed by cava. This installs the missing package for existing users.

if ! command -v cava &>/dev/null; then
    if command -v pacman &>/dev/null; then
        echo "   Installing cava..."
        sudo pacman -S --needed --noconfirm cava
    else
        echo "   cava not found. Please install cava manually."
    fi
else
    echo "   cava already installed, skipping"
fi
