#!/bin/bash
# =============================================================================
# NVIDIA Packages - NVIDIA GPU Support (OPCIONAL)
# =============================================================================
# Pacotes para suporte a GPUs NVIDIA em sistemas híbridos
# Instale apenas se você tem uma GPU NVIDIA
# =============================================================================

NVIDIA_PACKAGES=(
    # Drivers
    "nvidia-open-dkms" # NVIDIA proprietary driver
    "nvidia-utils"     # NVIDIA utilities
    "nvidia-settings"  # NVIDIA settings GUI

    # Video Acceleration
    "libva-nvidia-driver" # VA-API driver for NVIDIA

    # For hybrid graphics (Intel + NVIDIA)
    "intel-media-driver" # Intel VA-API driver
    "libva-utils"        # VA-API utilities (vainfo)
)

# Pacotes AUR
NVIDIA_AUR_PACKAGES=(
    # Nenhum pacote AUR obrigatório
)

# Nota: Após instalar os drivers NVIDIA, o script de setup irá
# configurar as variáveis de ambiente necessárias automaticamente.
