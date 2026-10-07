# 033-install-shell-deps.sh - Install dependencies that were only there by chance
#
# The Bluetooth pairing agent needs python-dbus and python-gobject, the
# autostart runs kbuildsycoca6 (kservice) and Settings › About uses lspci
# (pciutils). They used to come along with other packages; now the installer
# lists them.

if command -v pacman &>/dev/null; then
    missing=()
    for pkg in python-dbus python-gobject kservice pciutils; do
        pacman -Q "$pkg" &>/dev/null || missing+=("$pkg")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "   Installing ${missing[*]}..."
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    else
        echo "   python-dbus, python-gobject, kservice and pciutils already installed, skipping"
    fi
else
    for mod in dbus gi; do
        python3 -c "import $mod" &>/dev/null || echo "   Python module $mod not found. Please install it manually."
    done
    command -v kbuildsycoca6 &>/dev/null || echo "   kbuildsycoca6 (kservice) not found. Please install it manually."
    command -v lspci &>/dev/null || echo "   lspci (pciutils) not found. Please install it manually."
fi
