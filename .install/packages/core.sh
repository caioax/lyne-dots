#!/bin/bash
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
    "hyprshot"        # Screenshot tool for Hyprland
    "hyprsunset"      # Blue light filter for Hyprland
    "hyprpolkitagent" # Polkit agent for Hyprland

    # Display & Wallpaper
    "awww"         # Wallpaper daemon for Wayland
    "nwg-displays" # Monitor configuration tool

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
