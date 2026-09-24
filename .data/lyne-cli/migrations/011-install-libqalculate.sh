# 011-install-libqalculate.sh - Install libqalculate
#
# The QuickShell launcher has a calculator mode ("=" prefix) that runs qalc.
# This installs the missing package for existing users.

if ! command -v qalc &>/dev/null; then
    if command -v pacman &>/dev/null; then
        echo "   Installing libqalculate..."
        sudo pacman -S --needed --noconfirm libqalculate
    else
        echo "   qalc not found. Please install libqalculate manually."
    fi
else
    echo "   qalc already installed, skipping"
fi
