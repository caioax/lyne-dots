#!/bin/bash
# shellcheck disable=SC2034 # the package arrays are read by install.sh
# =============================================================================
# Font Packages - Fonts & Icons
# =============================================================================
# Fonts required for the system
# =============================================================================

FONTS_PACKAGES=(
    # Nerd Fonts
    "ttf-cascadia-code-nerd" # CaskaydiaCove Nerd Font (terminal/editor)
    "ttf-nerd-fonts-symbols" # Nerd Fonts symbols

    # Base Fonts
    "noto-fonts"       # Noto Sans/Serif (fallback)
    "noto-fonts-cjk"   # CJK support (Chinese, Japanese, Korean)
    "noto-fonts-emoji" # Emoji support

    # Dependencies for installing Tela from git
    "gtk-update-icon-cache" # For updating icon cache
    "git"                   # For cloning repository
)

# AUR packages
FONTS_AUR_PACKAGES=(
    "bibata-cursor-theme" # Bibata cursor theme
)

# =============================================================================
# Tela Icon Theme installation via Git
# =============================================================================
install_tela_icons() {
    local TEMP_DIR
    TEMP_DIR=$(mktemp -d) || return 1
    local ICON_COLOR="blue" # Color to install (generates Tela-blue and Tela-blue-dark)

    log_step "Installing Tela Icon Theme (${ICON_COLOR}) from Git..."

    if ! git clone --depth=1 https://github.com/vinceliuice/Tela-icon-theme.git "$TEMP_DIR/tela"; then
        log_error "Failed to clone Tela icon theme"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Install only the blue color (generates Tela-blue and Tela-blue-dark).
    # In a subshell: a failed cd must not run ./install.sh from here
    if (cd "$TEMP_DIR/tela" && ./install.sh "$ICON_COLOR"); then
        log_info "Tela-${ICON_COLOR} and Tela-${ICON_COLOR}-dark installed successfully!"
    else
        log_error "Failed to install Tela icon theme"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    rm -rf "$TEMP_DIR"
    return 0
}
