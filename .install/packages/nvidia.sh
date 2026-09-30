#!/bin/bash
# =============================================================================
# NVIDIA Packages - NVIDIA GPU Support (OPTIONAL)
# =============================================================================
# The driver depends on the GPU (nvidia-open for Turing and newer,
# nvidia-580xx from the AUR for Maxwell to Volta, nouveau for older cards),
# so it isn't a fixed list: .data/lyne-cli/lib/nvidia.sh picks and installs
# it. The installer's Graphics question, `./install.sh --packages nvidia` and
# `lyne nvidia install` all use it.
# =============================================================================

NVIDIA_PACKAGES=()
NVIDIA_AUR_PACKAGES=()
