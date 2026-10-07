#!/bin/bash
# shellcheck disable=SC2034 # the package arrays are read by install.sh
# =============================================================================
# Editor Packages - Text Editors & Development Tools
# =============================================================================
# Packages for text editing and development
# =============================================================================

EDITOR_PACKAGES=(
    # Editor
    "neovim" # Modern Vim-based text editor

    # Build tools (for Neovim plugins)
    "base-devel" # Build essentials
    "gcc"        # GNU Compiler Collection
    "make"       # Build automation tool
    "unzip"      # Unzip utility
    "unrar"      # Unrar utility
    "ripgrep"    # Fast grep (for Telescope)
    "fd"         # Fast find (for Telescope)
    "ffmpeg"     # Multimedia framework
    "tree-sitter-cli" # Tree-sitter CLI (required by nvim-treesitter to build parsers)

    # Node.js (for LSPs)
    "nodejs" # JavaScript runtime
    "npm"    # Node package manager
)

# AUR packages
EDITOR_AUR_PACKAGES=(
    # No mandatory AUR packages
)
