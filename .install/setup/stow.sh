#!/bin/bash
# =============================================================================
# Stow Setup - Symlink Dotfiles
# =============================================================================
# Usa GNU Stow para criar symlinks das dotfiles
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[>>]${NC} $1"; }

# =============================================================================
# Diretórios para fazer stow
# =============================================================================
STOW_DIRS=(
    "hyprland"      # Hyprland config
    "quickshell"    # QuickShell bar
    "kitty"         # Terminal
    "nvim"          # Editor
    "zsh"           # Shell
    "tmux"          # Multiplexer
    "local"         # Local scripts
    "fastfetch"     # System info
    "kde"           # KDE globals (terminal, fonts, icons)
    "theming"       # Qt5/Qt6/GTK theme configuration
)

# =============================================================================
# Verificar se stow está instalado
# =============================================================================
check_stow() {
    if ! command -v stow &>/dev/null; then
        log_error "GNU Stow não está instalado!"
        log_info "Instale com: sudo pacman -S stow"
        return 1
    fi
    return 0
}

# =============================================================================
# Criar diretórios necessários
# =============================================================================
create_dirs() {
    log_info "Criando diretórios necessários..."
    mkdir -p "$HOME/.config"
    mkdir -p "$HOME/.local/scripts"
    mkdir -p "$HOME/.local/bin"
}

# =============================================================================
# Obter destinos do stow para cada diretório
# =============================================================================
get_stow_targets() {
    local dir=$1
    local targets=()

    case "$dir" in
        "hyprland")
            targets+=("$HOME/.config/hypr" "$HOME/.config/uwsm")
            ;;
        "zsh")
            targets+=("$HOME/.zshrc" "$HOME/.p10k.zsh")
            ;;
        "tmux")
            targets+=("$HOME/.tmux.conf")
            ;;
        "local")
            targets+=("$HOME/.local/scripts" "$HOME/.local/wallpapers")
            ;;
        "kde")
            targets+=("$HOME/.config/kdeglobals")
            ;;
        "theming")
            targets+=("$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/qt5ct" "$HOME/.config/qt6ct")
            ;;
        *)
            targets+=("$HOME/.config/${dir}")
            ;;
    esac

    echo "${targets[@]}"
}

# =============================================================================
# Remover destinos existentes com confirmação
# =============================================================================
remove_existing_targets() {
    log_info "Verificando destinos existentes..."

    local ITEMS_TO_REMOVE=()

    # Coletar todos os itens existentes
    for dir in "${STOW_DIRS[@]}"; do
        local targets
        targets=($(get_stow_targets "$dir"))

        for target in "${targets[@]}"; do
            if [[ -e "$target" || -L "$target" ]]; then
                ITEMS_TO_REMOVE+=("$target")
            fi
        done
    done

    # Se não há itens para remover, retornar
    if [[ ${#ITEMS_TO_REMOVE[@]} -eq 0 ]]; then
        log_info "Nenhum destino existente encontrado. Pronto para stow!"
        return 0
    fi

    # Mostrar itens encontrados
    echo ""
    log_warn "Os seguintes arquivos/pastas de destino foram encontrados:"
    echo ""
    for item in "${ITEMS_TO_REMOVE[@]}"; do
        if [[ -L "$item" ]]; then
            echo -e "  ${CYAN}[symlink]${NC} $item"
        elif [[ -d "$item" ]]; then
            echo -e "  ${YELLOW}[pasta]${NC}   $item"
        else
            echo -e "  ${GREEN}[arquivo]${NC} $item"
        fi
    done
    echo ""

    # Pedir confirmação
    echo -ne "${RED}Deseja REMOVER esses itens para criar os novos symlinks? [Y/n]: ${NC}"
    read -r confirm

    if [[ ! $confirm =~ ^[Nn]$ ]]; then
        log_info "Removendo destinos existentes..."
        for item in "${ITEMS_TO_REMOVE[@]}"; do
            if [[ -e "$item" || -L "$item" ]]; then
                log_step "  Removendo: $item"
                rm -rf "$item"
            fi
        done
        log_info "Destinos removidos com sucesso!"
    else
        log_error "Remoção cancelada. O stow não pode criar symlinks sobre arquivos existentes."
        log_info "Remova os arquivos manualmente ou execute o script novamente."
        return 1
    fi
}

# =============================================================================
# Executar stow
# =============================================================================
execute_stow() {
    log_info "Executando stow para criar symlinks..."

    cd "$DOTFILES_DIR"

    for dir in "${STOW_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            log_step "  Stowing: $dir"
            if ! stow -R "$dir" 2>&1; then
                log_error "    Falha ao fazer stow de $dir"
                log_info "    Verifique se há conflitos e tente novamente."
            fi
        else
            log_warn "  Diretório não encontrado: $dir"
        fi
    done

    log_info "Symlinks criados com sucesso!"
}

# =============================================================================
# Main (para execução direta)
# =============================================================================
run_stow_main() {
    echo ""
    echo "=================================================="
    echo "       Stow Setup - Symlink Dotfiles"
    echo "=================================================="
    echo ""

    if ! check_stow; then
        return 1
    fi

    create_dirs

    if ! remove_existing_targets; then
        return 1
    fi

    execute_stow

    echo ""
    log_info "Stow concluído com sucesso!"
    echo ""
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_stow_main "$@"
fi
