# 003-install-satty.sh - Install satty screenshot annotation tool
#
# Satty is now used by the screenshot module for editing screenshots
# before saving. This migration installs it for existing users.

if ! command -v satty &>/dev/null; then
    if command -v pacman &>/dev/null; then
        echo "   Installing satty..."
        sudo pacman -S --noconfirm satty
    else
        echo "   satty not found. Please install it manually."
    fi
else
    echo "   satty already installed, skipping"
fi
