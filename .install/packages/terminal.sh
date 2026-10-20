#!/bin/bash
# shellcheck disable=SC2034 # the package arrays are read by install.sh
# =============================================================================
# Terminal Packages - Terminal Emulators & Shells
# =============================================================================
# Packages for terminal, shells and multiplexers
# =============================================================================

# Kitty itself is in core (the default terminal); its config is linked with
# this category
TERMINAL_PACKAGES=(
    # Shell
    "zsh"                   # Z Shell

    # Multiplexer
    "tmux"                  # Terminal multiplexer

    # System Info
    "fastfetch"             # Fast system info display
)

# AUR packages
TERMINAL_AUR_PACKAGES=(
    # Oh-My-Zsh and plugins are installed by setup_zsh() in install.sh
)
