#!/bin/bash
# =============================================================================
# Utility Packages - System Utilities & Tools
# =============================================================================
# Ferramentas e utilitários do sistema
# =============================================================================

UTILS_PACKAGES=(
    # Clipboard
    "wl-clipboard" # Wayland clipboard (wl-copy, wl-paste)
    "cliphist"     # Clipboard history manager

    # Media Control
    "playerctl" # Media player controller

    # JSON Processing
    "jq" # JSON processor (usado pelo workspace-manager)

    # Calculator
    "bc" # Calculator (usado por scripts)

    # Notifications
    "libnotify" # Notification library (notify-send)

    # Network
    "networkmanager"         # Network management
    "network-manager-applet" # NM applet (para quicksettings)

    # Bluetooth
    "bluez"       # Bluetooth stack
    "bluez-utils" # Bluetooth utilities

    # Audio
    "pipewire"       # Audio server
    "pipewire-pulse" # PulseAudio compatibility
    "pipewire-alsa"  # ALSA compatibility
    "wireplumber"    # Session manager
    "pavucontrol"    # PulseAudio volume control

    # Brightness
    "brightnessctl" # Brightness control

    # Screenshot
    "grim"  # Screenshot utility (usado pelo hyprshot)
    "slurp" # Region selection (usado pelo hyprshot)

    # Misc
    "polkit-kde-agent" # KDE Polkit agent
    "qt5-wayland"      # Qt5 Wayland support
    "qt6-wayland"      # Qt6 Wayland support

    # Flatpak
    "flatpak" # Flatpak
)

# Pacotes AUR
UTILS_AUR_PACKAGES=(
    # Nenhum pacote AUR obrigatório
)
