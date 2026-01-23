#!/bin/bash
# =============================================================================
# Font Packages - Fonts & Icons
# =============================================================================
# Fontes necessárias para o sistema
# =============================================================================

FONTS_PACKAGES=(
    # Nerd Fonts
    "ttf-cascadia-code-nerd"    # Caskaydia Cove Nerd Font (terminal/editor)
    "ttf-nerd-fonts-symbols"    # Símbolos Nerd Fonts

    # Base Fonts
    "noto-fonts"                # Noto Sans/Serif (fallback)
    "noto-fonts-cjk"            # CJK support (Chinês, Japonês, Coreano)
    "noto-fonts-emoji"          # Emoji support

    # Dependências para instalar Tela do git
    "gtk-update-icon-cache"     # Para atualizar cache de ícones
)

# Pacotes AUR
FONTS_AUR_PACKAGES=(
    "bibata-cursor-theme"       # Bibata cursor theme
)

# =============================================================================
# Instalação do Tela Icon Theme via Git
# =============================================================================
install_tela_icons() {
    local TEMP_DIR=$(mktemp -d)
    local ICON_NAME="blue"  # Variante a instalar

    echo "[>>] Instalando Tela Icon Theme do Git..."

    git clone --depth=1 https://github.com/vinceliuice/Tela-icon-theme.git "$TEMP_DIR/tela"

    if [[ -d "$TEMP_DIR/tela" ]]; then
        cd "$TEMP_DIR/tela"
        ./install.sh "$ICON_NAME"
        cd - > /dev/null
        echo "[INFO] Tela-$ICON_NAME instalado com sucesso!"
    else
        echo "[ERROR] Falha ao clonar Tela icon theme"
        return 1
    fi

    rm -rf "$TEMP_DIR"
}
