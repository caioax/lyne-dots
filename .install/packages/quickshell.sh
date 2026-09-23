#!/bin/bash
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
)

# AUR packages
QUICKSHELL_AUR_PACKAGES=(
    # QuickShell
    "quickshell-git" # QuickShell shell framework
)
