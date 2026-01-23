#!/bin/bash
# =============================================================================
# Editor Packages - Text Editors & Development Tools
# =============================================================================
# Pacotes para edição de texto e desenvolvimento
# =============================================================================

EDITOR_PACKAGES=(
    # Editor
    "neovim"                # Modern Vim-based text editor

    # Build tools (para plugins do Neovim)
    "base-devel"            # Build essentials
    "gcc"                   # GNU Compiler Collection
    "make"                  # Build automation tool
    "unzip"                 # Unzip utility
    "ripgrep"               # Fast grep (para Telescope)
    "fd"                    # Fast find (para Telescope)

    # Node.js (para LSPs)
    "nodejs"                # JavaScript runtime
    "npm"                   # Node package manager
)

# Pacotes AUR
EDITOR_AUR_PACKAGES=(
    # Nenhum pacote AUR obrigatório
)
