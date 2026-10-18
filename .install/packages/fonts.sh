#!/bin/bash
# shellcheck disable=SC2034 # the package arrays are read by install.sh
# =============================================================================
# Font Packages
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
)

# AUR packages
FONTS_AUR_PACKAGES=()
