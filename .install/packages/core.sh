#!/bin/bash
# =============================================================================
# Core Packages - Window Manager & Session
# =============================================================================
# Pacotes essenciais para o ambiente Hyprland funcionar
# =============================================================================

CORE_PACKAGES=(
    # Window Manager
    "hyprland" # Tiling Wayland compositor

    # Session Management
    "uwsm" # Universal Wayland Session Manager

    # Hyprland Utilities
    "hyprshot"        # Screenshot tool for Hyprland
    "hyprsunset"      # Blue light filter for Hyprland
    "hyprpolkitagent" # Polkit agent for Hyprland

    # Display & Wallpaper
    "swww"         # Wallpaper daemon for Wayland
    "nwg-displays" # Monitor configuration tool

    # XDG & Portal
    "xdg-desktop-portal-hyprland" # Portal for Hyprland
    "xdg-utils"                   # XDG utilities
)

# Pacotes AUR (requerem yay/paru)
CORE_AUR_PACKAGES=(
    # Nenhum pacote AUR obrigatório para core
)
