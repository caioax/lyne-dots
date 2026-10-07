#!/bin/bash
# shellcheck disable=SC2034 # the package arrays are read by install.sh
# =============================================================================
# QuickShell Packages - QuickShell Bar/Shell
# =============================================================================
# Packages required for QuickShell to work
# =============================================================================

QUICKSHELL_PACKAGES=(
    # Qt6 Dependencies
    "qt6-base"        # Qt6 base
    "qt6-declarative" # QML support
    "qt6-wayland"     # Qt6 Wayland platform
    "qt6-svg"         # SVG support
    "qt6-5compat"     # Qt5 compatibility (GraphicalEffects)

    # Additional Qt6 modules
    "qt6-imageformats" # Additional image formats

    # Dialogs
    "zenity" # File picker for adding wallpapers

    # Bluetooth pairing agent (scripts/bluetooth-agent.py)
    "python-dbus"
    "python-gobject"

    # Settings › About: the GPU line
    "pciutils" # lspci

    # System monitor
    "mission-center" # Detailed view opened from the system monitor popup

    # Launcher
    "libqalculate" # qalc, for the launcher's calculator mode (=)

    # Dashboard
    "cava" # Audio visualizer around the cover in the Media tab

    # Brightness
    "ddcutil" # External monitor brightness over DDC/CI (needs i2c-dev)

    # Screenshot
    "xdg-user-dirs"      # Finds the Pictures folder screenshots are saved to
    "tesseract"          # OCR: copies the text in a screenshot selection
    "tesseract-data-eng" # English for tesseract
    "tesseract-data-por" # Portuguese for tesseract
)

# AUR packages
QUICKSHELL_AUR_PACKAGES=(
    # QuickShell
    "quickshell-git" # QuickShell shell framework
)
