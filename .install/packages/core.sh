#!/bin/bash
# shellcheck disable=SC2034 # the package arrays are read by install.sh
# =============================================================================
# Core Packages - Window Manager & Session
# =============================================================================
# Essential packages for the Hyprland environment to work
# =============================================================================

CORE_PACKAGES=(
    # Window Manager
    "hyprland" # Tiling Wayland compositor

    # Session Management
    "uwsm" # Universal Wayland Session Manager

    # Hyprland Utilities
    "hyprsunset" # Blue light filter for Hyprland

    # Polkit agent (password prompts; started by hypr/conf/autostart.lua)
    "polkit-kde-agent"

    # Default terminal (Super+Enter, Settings › System › Apps); its config
    # comes with the terminal category
    "kitty"

    # Display & Wallpaper
    "awww" # Wallpaper daemon for Wayland

    # XDG & Portal
    "xdg-desktop-portal-hyprland" # Portal for Hyprland
    "xdg-desktop-portal-gtk"      # Portal for Gtk
    "xdg-user-dirs-gtk"           # For default files
    "xdg-utils"                   # XDG utilities
)

# AUR packages (require yay/paru)
CORE_AUR_PACKAGES=(
    # No mandatory AUR packages for core
)
