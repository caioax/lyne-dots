#!/bin/bash
# =============================================================================
# Utility Packages - System Utilities & Tools
# =============================================================================
# System tools and utilities
# =============================================================================

UTILS_PACKAGES=(
    # Clipboard
    "wl-clipboard" # Wayland clipboard (wl-copy, wl-paste)
    "cliphist"     # Clipboard history manager

    # Media Control
    "playerctl" # Media player controller

    # JSON Processing
    "jq" # JSON processor

    # Calculator
    "bc" # Calculator (used by scripts)

    # Notifications
    "libnotify" # Notification library (notify-send)

    # Network
    "networkmanager"         # Network management
    "network-manager-applet" # NM applet (for quicksettings)

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
    "grim"  # Screenshot utility
    "slurp" # Region selection
    "satty" # Screenshot annotation tool

    # Image Processing
    "imagemagick" # Image manipulation

    # Misc
    "polkit-kde-agent" # KDE Polkit agent
    "qt5-wayland"      # Qt5 Wayland support
    "qt6-wayland"      # Qt6 Wayland support

    # Flatpak
    "flatpak" # Flatpak
)

# AUR packages
UTILS_AUR_PACKAGES=(
    # No mandatory AUR packages
)
