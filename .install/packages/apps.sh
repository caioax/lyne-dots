#!/bin/bash
# shellcheck disable=SC2034 # the package arrays are read by install.sh
# =============================================================================
# Application Packages - Desktop Applications
# =============================================================================
# Daily-use applications
# =============================================================================

APPS_PACKAGES=(
    # File Manager
    "dolphin"                  # KDE file manager
    "dolphin-plugins"          # Dolphin plugins
    "ark"                      # Archive manager (Dolphin integration)
    "ffmpegthumbs"             # Video thumbnails for Dolphin
    "kdegraphics-thumbnailers" # Image/PDF thumbnails

    # Multimedia
    "mpv"

    # WhatsApp Web app (WhatsApp special workspace)
    "chromium"

    # Flatpak Store
    "discover"

    # KDE Integration
    "breeze"             # KDE theme (for Dolphin icons)
    "kio-admin"          # KIO for root access in Dolphin
    "archlinux-xdg-menu" # XDG for recognizing default apps
)

# AUR packages
APPS_AUR_PACKAGES=(
    "zen-browser-bin" # Zen Browser (Firefox fork)
    "spotify"         # Spotify music player (music special workspace)

    "qview" # Image viewer
)
