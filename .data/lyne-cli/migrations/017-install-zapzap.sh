# 017-install-zapzap.sh - Install ZapZap, the WhatsApp app of the special workspace
#
# The WhatsApp special workspace (SUPER+W) now opens ZapZap instead of a Zen
# Browser profile made by hand. Pick another app, or start it hidden at
# login, in Settings › Hyprland › Specials.

if command -v pacman &>/dev/null; then
    if pacman -Q zapzap &>/dev/null; then
        echo "   zapzap already installed, skipping"
    elif command -v yay &>/dev/null; then
        echo "   Installing zapzap (AUR)..."
        yay -S --needed --noconfirm zapzap
    elif command -v paru &>/dev/null; then
        echo "   Installing zapzap (AUR)..."
        paru -S --needed --noconfirm zapzap
    else
        echo "   No AUR helper (yay/paru) found. Install zapzap manually."
    fi
elif ! command -v zapzap &>/dev/null; then
    echo "   zapzap not found. Please install it manually."
fi
