#!/bin/bash
# =============================================================================
# Application Packages - Desktop Applications
# =============================================================================
# Aplicativos de uso diário
# =============================================================================

APPS_PACKAGES=(
    # File Manager
    "dolphin"                  # KDE file manager
    "ark"                      # Archive manager (integração com Dolphin)
    "ffmpegthumbs"             # Video thumbnails para Dolphin
    "kdegraphics-thumbnailers" # Image/PDF thumbnails

    # Launcher
    "rofi-wayland" # Application launcher (Wayland fork)

    # Multi mídia
    "mpv"

    # KDE Integration
    "breeze"             # KDE theme (para ícones do Dolphin)
    "kio-admin"          # KIO para acesso root no Dolphin
    "archlinux-xdg-menu" # Xdg para reconhecer apps padrão
)

# Pacotes AUR
APPS_AUR_PACKAGES=(
    "zen-browser-bin" # Zen Browser (Firefox fork)
    "spotify"         # Spotify music player
)
