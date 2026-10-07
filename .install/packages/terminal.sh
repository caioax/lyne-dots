#!/bin/bash
# shellcheck disable=SC2034 # the package arrays are read by install.sh
# =============================================================================
# Terminal Packages - Terminal Emulators & Shells
# =============================================================================
# Packages for terminal, shells and multiplexers
# =============================================================================

TERMINAL_PACKAGES=(
    # Terminal Emulator
    "kitty"                 # GPU-accelerated terminal emulator

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
