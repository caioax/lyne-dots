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
    "git"                       # Para clonar repositório
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
    local ICON_COLOR="blue"  # Cor a instalar (gera Tela-blue e Tela-blue-dark)

    echo -e "\033[0;36m[>>]\033[0m Instalando Tela Icon Theme (${ICON_COLOR}) do Git..."

    if ! git clone --depth=1 https://github.com/vinceliuice/Tela-icon-theme.git "$TEMP_DIR/tela"; then
        echo -e "\033[0;31m[ERROR]\033[0m Falha ao clonar Tela icon theme"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    cd "$TEMP_DIR/tela"

    # Instalar apenas a cor blue (gera Tela-blue e Tela-blue-dark)
    if ./install.sh "$ICON_COLOR"; then
        echo -e "\033[0;32m[INFO]\033[0m Tela-${ICON_COLOR} e Tela-${ICON_COLOR}-dark instalados com sucesso!"
    else
        echo -e "\033[0;31m[ERROR]\033[0m Falha ao instalar Tela icon theme"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        return 1
    fi

    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    return 0
}
