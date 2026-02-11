#!/bin/bash
# =============================================================================
# Font Packages - Fonts & Icons
# =============================================================================
# Fonts required for the system
# =============================================================================

FONTS_PACKAGES=(
    # Nerd Fonts
    "ttf-cascadia-code-nerd" # Caskaydia Cove Nerd Font (terminal/editor)
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
    local TEMP_DIR=$(mktemp -d)
    local ICON_COLOR="blue" # Color to install (generates Tela-blue and Tela-blue-dark)

    echo -e "\033[0;36m[>>]\033[0m Installing Tela Icon Theme (${ICON_COLOR}) from Git..."

    if ! git clone --depth=1 https://github.com/vinceliuice/Tela-icon-theme.git "$TEMP_DIR/tela"; then
        echo -e "\033[0;31m[ERROR]\033[0m Failed to clone Tela icon theme"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    cd "$TEMP_DIR/tela"

    # Install only the blue color (generates Tela-blue and Tela-blue-dark)
    if ./install.sh "$ICON_COLOR"; then
        echo -e "\033[0;32m[INFO]\033[0m Tela-${ICON_COLOR} and Tela-${ICON_COLOR}-dark installed successfully!"
    else
        echo -e "\033[0;31m[ERROR]\033[0m Failed to install Tela icon theme"
        cd - >/dev/null
        rm -rf "$TEMP_DIR"
        return 1
    fi

    cd - >/dev/null
    rm -rf "$TEMP_DIR"
    return 0
}
