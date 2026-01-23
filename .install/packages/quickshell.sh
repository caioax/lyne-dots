#!/bin/bash
# =============================================================================
# QuickShell Packages - QuickShell Bar/Shell
# =============================================================================
# Pacotes necessários para o QuickShell funcionar
# =============================================================================

QUICKSHELL_PACKAGES=(
    # QuickShell (repositório oficial extra)
    "quickshell"            # QuickShell shell framework

    # Qt6 Dependencies (já são dependências do quickshell, mas garantir)
    "qt6-base"              # Qt6 base
    "qt6-declarative"       # QML support
    "qt6-wayland"           # Qt6 Wayland platform
    "qt6-svg"               # SVG support
    "qt6-5compat"           # Qt5 compatibility (GraphicalEffects)

    # Additional Qt6 modules
    "qt6-imageformats"      # Additional image formats
)

# Pacotes AUR
QUICKSHELL_AUR_PACKAGES=(
    # Nenhum - quickshell está no repositório oficial
)
