#!/bin/bash
# shellcheck disable=SC2034 # the package arrays are read by install.sh
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

    # Dependencies for installing Tela from git (the default icon theme;
    # more in Settings > Icons)
    "gtk-update-icon-cache" # For updating icon cache
    "git"                   # For cloning repository
)

# AUR packages
THEMING_AUR_PACKAGES=(
    # Qt Theming
    "qt5ct-kde" # Qt5 theme configuration
    "qt6ct-kde" # Qt6 theme configuration

    # The default mouse cursor (more in Settings > Cursor)
    "bibata-cursor-theme" # Bibata cursor theme
)

# =============================================================================
# Tela Icon Theme installation via Git
# =============================================================================
install_tela_icons() {
    local TEMP_DIR
    TEMP_DIR=$(mktemp -d) || return 1
    local ICON_COLOR="blue" # Color to install (generates Tela-blue, -dark and -light)

    log_step "Installing Tela Icon Theme (${ICON_COLOR}) from Git..."

    if ! git clone --depth=1 https://github.com/vinceliuice/Tela-icon-theme.git "$TEMP_DIR/tela"; then
        log_error "Failed to clone Tela icon theme"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Install only the blue color (generates Tela-blue, -dark and -light;
    # the shell picks -dark or -light by the theme's mode, IconService).
    # In a subshell: a failed cd must not run ./install.sh from here
    if (cd "$TEMP_DIR/tela" && ./install.sh "$ICON_COLOR"); then
        log_info "Tela-${ICON_COLOR} icon themes installed successfully!"
    else
        log_error "Failed to install Tela icon theme"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    rm -rf "$TEMP_DIR"
    return 0
}

# =============================================================================
# Setup - Apply theme settings
# =============================================================================
setup_theming() {
    log_step "Applying GTK theme settings..."
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"
    gsettings set org.gnome.desktop.interface font-name "CaskaydiaCove Nerd Font 10"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    log_info "GTK theme applied!"

    # GSettings, the default theme apps without a setting inherit and, inside
    # Hyprland, the running cursor (lyne cursor; Settings > Cursor)
    log_step "Applying the cursor theme..."
    source "$DOTFILES_DIR/.data/lyne-cli/lib/cursor.sh"
    if cursor_apply "$CURSOR_DEFAULT_THEME" "$CURSOR_DEFAULT_SIZE"; then
        log_info "Cursor: $CURSOR_DEFAULT_THEME, size $CURSOR_DEFAULT_SIZE"
    else
        log_warn "Cursor theme not applied: pick one in Settings > Cursor"
    fi

    # The default icon theme's dark version (the install starts dark) in
    # GSettings, qt6ct/qt5ct, kdeglobals and the GTK settings.ini (lyne
    # icons; Settings > Icons)
    log_step "Applying the icon theme..."
    source "$DOTFILES_DIR/.data/lyne-cli/lib/icons.sh"
    local icons
    if icons="$(icons_variant "$ICONS_DEFAULT_THEME" dark)" && icons_apply "$icons" >/dev/null; then
        log_info "Icons: $icons"
    else
        log_warn "Icon theme not applied: pick one in Settings > Icons"
    fi

    log_step "Setting up matugen..."
    mkdir -p "$HOME/.cache/matugen"
    mkdir -p "$HOME/.local/share/color-schemes"
    mkdir -p "$HOME/.config/matugen"
    ln -sf "$HOME/.lyne-dots/.data/matugen/config.toml" "$HOME/.config/matugen/config.toml"
    log_info "Matugen configured!"
}
