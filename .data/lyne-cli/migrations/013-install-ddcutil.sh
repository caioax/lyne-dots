# 013-install-ddcutil.sh - Install ddcutil and load i2c-dev
#
# QuickShell controls the brightness of external monitors over DDC/CI with
# ddcutil, which talks to them through the /dev/i2c-* nodes of the i2c-dev
# module. ddcutil's udev rule gives the logged-in user access to them.

if ! command -v ddcutil &>/dev/null; then
    if command -v pacman &>/dev/null; then
        echo "   Installing ddcutil..."
        sudo pacman -S --needed --noconfirm ddcutil
    else
        echo "   ddcutil not found. Please install ddcutil manually."
    fi
else
    echo "   ddcutil already installed, skipping"
fi

if [[ ! -f /etc/modules-load.d/i2c-dev.conf ]]; then
    echo "   Loading i2c-dev at boot..."
    echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
    sudo modprobe i2c-dev
else
    echo "   i2c-dev already loaded at boot, skipping"
fi

# Apply ddcutil's udev rule to i2c nodes that already exist (no reboot)
if command -v ddcutil &>/dev/null && command -v udevadm &>/dev/null; then
    sudo udevadm trigger --subsystem-match=i2c-dev
fi
