# 014-install-xdg-user-dirs.sh - Install xdg-user-dirs
#
# QuickShell saves screenshots to <Pictures>/Screenshots and asks
# xdg-user-dir where the Pictures folder is (without it, ~/Pictures).

if ! command -v xdg-user-dir &>/dev/null; then
    if command -v pacman &>/dev/null; then
        echo "   Installing xdg-user-dirs..."
        sudo pacman -S --needed --noconfirm xdg-user-dirs
    else
        echo "   xdg-user-dirs not found. Please install it manually."
    fi
else
    echo "   xdg-user-dirs already installed, skipping"
fi
