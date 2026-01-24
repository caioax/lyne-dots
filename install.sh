#!/bin/bash
# =============================================================================
#
#   ▄▀█ █▀█ █▀▀ █ █ ▄▄ █▀▄ █▀█ ▀█▀ █▀
#   █▀█ █▀▄ █▄▄ █▀█    █▄▀ █▄█  █  ▄█
#
#   Installation Script
#   https://github.com/caioax/.arch-dots
#
# =============================================================================

set -e

# =============================================================================
# Configuração
# =============================================================================
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$DOTFILES_DIR/.install/packages"
SETUP_DIR="$DOTFILES_DIR/.install/setup"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# Funções de logging
# =============================================================================
log_header() {
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[>>]${NC} $1"; }

# =============================================================================
# Verificações iniciais
# =============================================================================
check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        log_error "Este script é apenas para Arch Linux!"
        exit 1
    fi
}

check_internet() {
    log_step "Verificando conexão com a internet..."
    if ! ping -c 1 google.com &>/dev/null; then
        log_error "Sem conexão com a internet!"
        exit 1
    fi
    log_info "Conexão OK"
}

check_aur_helper() {
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
        AUR_HELPER="paru"
    else
        log_warn "Nenhum AUR helper encontrado (yay/paru)"
        log_info "Instalando yay..."
        install_yay
        AUR_HELPER="yay"
    fi
    log_info "AUR helper: $AUR_HELPER"
}

install_yay() {
    sudo pacman -S --needed --noconfirm git base-devel
    local TEMP_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$TEMP_DIR/yay"
    cd "$TEMP_DIR/yay"
    makepkg -si --noconfirm
    cd "$DOTFILES_DIR"
    rm -rf "$TEMP_DIR"
}

# =============================================================================
# Instalação de pacotes
# =============================================================================
install_packages() {
    local CATEGORY=$1
    local PACKAGES_FILE="$PACKAGES_DIR/${CATEGORY}.sh"

    if [[ ! -f "$PACKAGES_FILE" ]]; then
        log_error "Arquivo de pacotes não encontrado: $PACKAGES_FILE"
        return 1
    fi

    # Carregar arrays de pacotes
    source "$PACKAGES_FILE"

    local ARRAY_NAME="${CATEGORY^^}_PACKAGES"
    local AUR_ARRAY_NAME="${CATEGORY^^}_AUR_PACKAGES"

    # Converter para array usando nameref
    local -n PACKAGES_REF="$ARRAY_NAME" 2>/dev/null || true
    local -n AUR_PACKAGES_REF="$AUR_ARRAY_NAME" 2>/dev/null || true

    # Instalar pacotes oficiais
    if [[ ${#PACKAGES_REF[@]} -gt 0 ]]; then
        log_step "Instalando pacotes oficiais ($CATEGORY)..."
        sudo pacman -S --needed --noconfirm "${PACKAGES_REF[@]}" || {
            log_warn "Alguns pacotes podem não estar disponíveis"
        }
    fi

    # Instalar pacotes AUR
    if [[ ${#AUR_PACKAGES_REF[@]} -gt 0 ]]; then
        log_step "Instalando pacotes AUR ($CATEGORY)..."
        $AUR_HELPER -S --needed --noconfirm "${AUR_PACKAGES_REF[@]}" || {
            log_warn "Alguns pacotes AUR podem não estar disponíveis"
        }
    fi
}

# =============================================================================
# Menu de seleção de categorias
# =============================================================================
show_menu() {
    echo ""
    echo -e "${CYAN}Selecione as categorias para instalar:${NC}"
    echo ""
    echo "  1) core       - Hyprland, UWSM, portal (ESSENCIAL)"
    echo "  2) terminal   - Kitty, Zsh, Tmux, Fastfetch"
    echo "  3) editor     - Neovim + ferramentas de desenvolvimento"
    echo "  4) apps       - Dolphin, Zen Browser, Spotify, Rofi"
    echo "  5) utils      - Clipboard, playerctl, audio, etc"
    echo "  6) fonts      - Nerd Fonts, cursores, ícones"
    echo "  7) quickshell - QuickShell bar/shell"
    echo "  8) theming    - Qt/GTK theming"
    echo "  9) nvidia     - Drivers NVIDIA (apenas se tiver GPU NVIDIA)"
    echo ""
    echo "  a) ALL        - Instalar tudo (exceto nvidia)"
    echo "  n) ALL+NVIDIA - Instalar tudo (incluindo nvidia)"
    echo "  q) QUIT       - Sair"
    echo ""
}

get_selection() {
    local SELECTED=()

    while true; do
        show_menu
        echo -ne "${BLUE}Digite os números separados por espaço (ex: 1 2 3 5): ${NC}"
        read -r input

        case "$input" in
        q | Q)
            log_info "Instalação cancelada."
            exit 0
            ;;
        a | A)
            SELECTED=("core" "terminal" "editor" "apps" "utils" "fonts" "quickshell" "theming")
            break
            ;;
        n | N)
            SELECTED=("core" "terminal" "editor" "apps" "utils" "fonts" "quickshell" "theming" "nvidia")
            break
            ;;
        *)
            for num in $input; do
                case "$num" in
                1) SELECTED+=("core") ;;
                2) SELECTED+=("terminal") ;;
                3) SELECTED+=("editor") ;;
                4) SELECTED+=("apps") ;;
                5) SELECTED+=("utils") ;;
                6) SELECTED+=("fonts") ;;
                7) SELECTED+=("quickshell") ;;
                8) SELECTED+=("theming") ;;
                9) SELECTED+=("nvidia") ;;
                *) log_warn "Opção inválida: $num" ;;
                esac
            done

            if [[ ${#SELECTED[@]} -gt 0 ]]; then
                break
            fi
            ;;
        esac
    done

    # Remover duplicatas
    CATEGORIES=($(printf "%s\n" "${SELECTED[@]}" | sort -u))
}

# =============================================================================
# Funções de setup
# =============================================================================
run_stow() {
    log_header "Criando Symlinks (Stow)"
    source "$SETUP_DIR/stow.sh"
    run_stow_main
}

run_hyprland_setup() {
    log_header "Configurando Hyprland"
    source "$SETUP_DIR/hyprland.sh"
    run_hyprland_main
}

setup_zsh() {
    log_header "Configurando Zsh"

    # Mudar shell padrão para zsh
    if [[ "$SHELL" != *"zsh"* ]]; then
        log_step "Mudando shell padrão para Zsh..."
        chsh -s $(which zsh)
        log_info "Shell mudado para Zsh. Faça logout/login para aplicar."
    else
        log_info "Zsh já é o shell padrão."
    fi

    log_info "Oh-My-Zsh e plugins serão instalados automaticamente"
    log_info "na primeira vez que você abrir um terminal."
}

setup_tmux() {
    log_header "Configurando Tmux"

    # Instalar TPM (Tmux Plugin Manager)
    local TPM_DIR="$HOME/.tmux/plugins/tpm"
    if [[ ! -d "$TPM_DIR" ]]; then
        log_step "Instalando TPM (Tmux Plugin Manager)..."
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
        log_info "TPM instalado. Use prefix + I dentro do tmux para instalar plugins."
    else
        log_info "TPM já está instalado."
    fi
}

setup_services() {
    log_header "Habilitando Serviços"

    # Bluetooth
    if systemctl list-unit-files | grep -q "bluetooth.service"; then
        log_step "Habilitando Bluetooth..."
        sudo systemctl enable --now bluetooth.service
    fi

    # NetworkManager
    if systemctl list-unit-files | grep -q "NetworkManager.service"; then
        log_step "Habilitando NetworkManager..."
        sudo systemctl enable --now NetworkManager.service
    fi
}

setup_wallpaper() {
    log_header "Configurando Wallpaper Inicial"

    local WALLPAPER="$HOME/.local/wallpapers/bash.png"

    # Verificar se swww está instalado
    if ! command -v swww &>/dev/null; then
        log_warn "swww não está instalado. Pulando configuração de wallpaper."
        return 0
    fi

    # Verificar se o wallpaper existe
    if [[ ! -f "$WALLPAPER" ]]; then
        log_warn "Wallpaper não encontrado: $WALLPAPER"
        return 0
    fi

    # Verificar se está em uma sessão Wayland
    if [[ -z "$WAYLAND_DISPLAY" ]]; then
        log_warn "Não está em uma sessão Wayland."
        log_info "O wallpaper será aplicado automaticamente ao iniciar o Hyprland."
        return 0
    fi

    log_step "Iniciando swww daemon..."
    # Iniciar daemon se não estiver rodando
    if ! pgrep -f "swww-daemon" &>/dev/null; then
        swww-daemon >/dev/null 2>&1 &
    fi
    sleep 3

    # Verificar se o daemon iniciou
    if ! pgrep -f "swww-daemon" &>/dev/null; then
        log_warn "Não foi possível iniciar o swww daemon."
        return 0
    fi

    log_step "Aplicando wallpaper: bash.png"
    if swww img "$WALLPAPER" --transition-type fade --transition-duration 1 2>/dev/null; then
        log_info "Wallpaper configurado com sucesso!"
    else
        log_warn "Erro ao aplicar wallpaper."
    fi
}

# =============================================================================
# Instalação completa
# =============================================================================
full_install() {
    log_header "Iniciando Instalação Completa"

    # Verificar internet e AUR helper agora (após seleção)
    check_internet
    check_aur_helper

    # Instalar stow primeiro
    log_step "Instalando GNU Stow..."
    sudo pacman -S --needed --noconfirm stow git

    # Instalar pacotes selecionados
    for category in "${CATEGORIES[@]}"; do
        log_header "Instalando: ${category^^}"
        install_packages "$category"
    done

    # Rodar setup scripts
    run_stow
    run_hyprland_setup

    # Instalar Tela icons do git (se fonts foi selecionado)
    if [[ " ${CATEGORIES[*]} " =~ " fonts " ]]; then
        log_header "Instalando Tela Icon Theme"
        install_tela_icons
    fi

    # Setup adicional baseado nas categorias instaladas
    if [[ " ${CATEGORIES[*]} " =~ " terminal " ]]; then
        setup_zsh
        setup_tmux
    fi

    # Habilitar serviços
    if [[ " ${CATEGORIES[*]} " =~ " utils " ]]; then
        setup_services
    fi

    # Configurar wallpaper inicial
    if [[ " ${CATEGORIES[*]} " =~ " core " ]]; then
        setup_wallpaper
    fi

    # Aplicar tema GTK
    if [[ " ${CATEGORIES[*]} " =~ " theming " ]]; then
        setup_theming
    fi
}

# =============================================================================
# Solicitar reboot
# =============================================================================
ask_reboot() {
    echo ""
    echo -ne "${YELLOW}Deseja reiniciar o sistema agora para aplicar todas as mudanças? [y/N]: ${NC}"
    read -r do_reboot

    if [[ $do_reboot =~ ^[Yy]$ ]]; then
        log_info "Reiniciando em 5 segundos..."
        sleep 5
        sudo reboot
    else
        log_info "Lembre-se de reiniciar o sistema para aplicar todas as mudanças."
    fi
}

# =============================================================================
# Resumo final
# =============================================================================
show_summary() {
    log_header "Instalação Concluída!"

    echo -e "${GREEN}Categorias instaladas:${NC}"
    for cat in "${CATEGORIES[@]}"; do
        echo "  - $cat"
    done

    echo ""
    echo -e "${YELLOW}Próximos passos:${NC}"
    echo "  1. Faça logout e selecione 'Hyprland (uwsm)' no seu display manager"
    echo "  2. Ou inicie manualmente com: uwsm start hyprland-uwsm.desktop"
    echo ""
    echo "  3. Configure seus monitores com: nwg-displays"
    echo "  4. Os workspaces serão configurados automaticamente pelo workspace-manager"
    echo ""

    if [[ " ${CATEGORIES[*]} " =~ " terminal " ]]; then
        echo "  5. Abra um terminal para instalar Oh-My-Zsh automaticamente"
        echo "  6. No tmux, use prefix + I para instalar plugins"
    fi

    if [[ " ${CATEGORIES[*]} " =~ " nvidia " ]]; then
        echo ""
        echo -e "${YELLOW}NVIDIA:${NC}"
        echo "  - Revise ~/.config/hypr/local/extra_environment.conf"
        echo "  - Para GPUs híbridas, descomente a linha AQ_DRM_DEVICES"
    fi

    echo ""
    log_info "Enjoy your new setup!"
    echo ""
}

# =============================================================================
# Mostrar banner
# =============================================================================
show_banner() {
    echo ""
    echo -e "${CYAN}"
    cat <<'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║   ▄▀█ █▀█ █▀▀ █ █ ▄▄ █▀▄ █▀█ ▀█▀ █▀                           ║
    ║   █▀█ █▀▄ █▄▄ █▀█    █▄▀ █▄█  █  ▄█                           ║
    ║                                                               ║
    ║   https://github.com/caioax/.arch-dots                        ║
    ║   Installation Script                                         ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# =============================================================================
# Main
# =============================================================================
main() {
    show_banner

    # Verificar se é Arch Linux
    check_arch

    # PRIMEIRO: Seleção de categorias (antes de qualquer instalação)
    get_selection

    echo ""
    log_info "Categorias selecionadas: ${CATEGORIES[*]}"
    echo ""
    echo -ne "${YELLOW}Continuar com a instalação? [Y/n]: ${NC}"
    read -r confirm

    if [[ $confirm =~ ^[Nn]$ ]]; then
        log_info "Instalação cancelada."
        exit 0
    fi

    # Executar instalação (verificações e AUR helper aqui)
    full_install

    # Mostrar resumo
    show_summary

    # Solicitar reboot
    ask_reboot
}

# =============================================================================
# Argumentos de linha de comando
# =============================================================================
case "${1:-}" in
--help | -h)
    echo "Uso: ./install.sh [opção]"
    echo ""
    echo "Opções:"
    echo "  --help, -h      Mostra esta ajuda"
    echo "  --stow-only     Apenas executa stow (symlinks)"
    echo "  --setup-only    Apenas executa setup do Hyprland"
    echo "  --packages PKG  Instala apenas a categoria especificada"
    echo ""
    echo "Categorias disponíveis:"
    echo "  core, terminal, editor, apps, utils, fonts, quickshell, theming, nvidia"
    exit 0
    ;;
--stow-only)
    check_arch
    sudo pacman -S --needed --noconfirm stow
    source "$SETUP_DIR/stow.sh"
    run_stow_main
    exit 0
    ;;
--setup-only)
    check_arch
    source "$SETUP_DIR/hyprland.sh"
    run_hyprland_main
    exit 0
    ;;
--packages)
    check_arch
    check_internet
    check_aur_helper
    if [[ -z "${2:-}" ]]; then
        log_error "Especifique uma categoria!"
        exit 1
    fi
    install_packages "$2"
    exit 0
    ;;
*)
    main
    ;;
esac
