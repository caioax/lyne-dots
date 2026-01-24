#!/bin/bash
# =============================================================================
# Theming Packages - Qt/GTK Theming
# =============================================================================
# Pacotes para configuração de temas Qt e GTK
# =============================================================================

THEMING_PACKAGES=(
    # GTK Theming
    "nwg-look" # GTK theme configuration for Wayland

    # Themes
    "breeze"     # KDE Breeze theme
    "breeze5"    # Breeze QT5 theme
    "breeze-gtk" # Breeze GTK theme
)

# Pacotes AUR
THEMING_AUR_PACKAGES=(
    # Qt Theming
    "qt5ct-kde" # Qt5 theme configuration
    "qt6ct-kde" # Qt6 theme configuration
)

# =============================================================================
# Setup - Aplicar configurações de tema
# =============================================================================
setup_theming() {
    echo "[>>] Aplicando configurações de tema GTK..."
    gsettings set org.gnome.desktop.interface gtk-theme "Breeze-Dark"
    gsettings set org.gnome.desktop.interface icon-theme "Tela-blue-dark"
    gsettings set org.gnome.desktop.interface font-name "CaskaydiaCove Nerd Font 10"
    gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Classic"
    gsettings set org.gnome.desktop.interface cursor-size 24
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    echo "[OK] Tema GTK aplicado!"
}
