#!/bin/bash
# =============================================================================
# Theming Packages - Qt/GTK Theming
# =============================================================================
# Packages for Qt and GTK theme configuration
# =============================================================================

THEMING_PACKAGES=(
    # GTK Theming
    "nwg-look" # GTK theme configuration for Wayland

    # Themes
    "breeze"        # KDE Breeze theme
    "breeze5"       # Breeze QT5 theme
    "breeze-gtk"    # Breeze GTK theme
    "adw-gtk-theme" # adw-gtk3 theme (GTK3 port of libadwaita, supports @define-color)

    # Material You color generation
    "matugen" # Generate Material You colors from wallpapers

    # Theme creation in Settings: accent colors from a wallpaper and the
    # lyne-dots wallpapers of a new theme (.data/wallpapers/generator)
    "python-numpy"  # Wallpaper generator
    "python-pillow" # Wallpaper generator, wallpaper color extraction
    "librsvg"       # rsvg-convert, rasterizes the generator's shapes
)

# AUR packages
THEMING_AUR_PACKAGES=(
    # Qt Theming
    "qt5ct-kde" # Qt5 theme configuration
    "qt6ct-kde" # Qt6 theme configuration
)

# =============================================================================
# Setup - Apply theme settings
# =============================================================================
setup_theming() {
    echo "[>>] Applying GTK theme settings..."
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"
    gsettings set org.gnome.desktop.interface icon-theme "Tela-blue-dark"
    gsettings set org.gnome.desktop.interface font-name "CaskaydiaCove Nerd Font 10"
    gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Classic"
    gsettings set org.gnome.desktop.interface cursor-size 24
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    echo "[OK] GTK theme applied!"

    echo "[>>] Setting up matugen..."
    mkdir -p "$HOME/.cache/matugen"
    mkdir -p "$HOME/.local/share/color-schemes"
    mkdir -p "$HOME/.config/matugen"
    ln -sf "$HOME/.lyne-dots/.data/matugen/config.toml" "$HOME/.config/matugen/config.toml"
    echo "[OK] Matugen configured!"
}
