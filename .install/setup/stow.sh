#!/bin/bash
# =============================================================================
# Stow Setup - Symlink Dotfiles
# =============================================================================
# Usa GNU Stow para criar symlinks das dotfiles
# =============================================================================

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

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
)

# =============================================================================
# Verificar se stow está instalado
# =============================================================================
check_stow() {
    if ! command -v stow &>/dev/null; then
        log_error "GNU Stow não está instalado!"
        log_info "Instale com: sudo pacman -S stow"
        exit 1
    fi
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
# Fazer backup de configs existentes
# =============================================================================
backup_existing() {
    local BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
    local NEED_BACKUP=false

    for dir in "${STOW_DIRS[@]}"; do
        # Verificar se existe algo que não é symlink
        case "$dir" in
            "zsh")
                [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]] && NEED_BACKUP=true
                ;;
            "local")
                [[ -d "$HOME/.local/scripts" && ! -L "$HOME/.local/scripts" ]] && NEED_BACKUP=true
                ;;
            *)
                [[ -d "$HOME/.config/${dir}" && ! -L "$HOME/.config/${dir}" ]] && NEED_BACKUP=true
                ;;
        esac
    done

    if $NEED_BACKUP; then
        log_warn "Configurações existentes encontradas. Fazendo backup em $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"

        for dir in "${STOW_DIRS[@]}"; do
            case "$dir" in
                "zsh")
                    [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]] && mv "$HOME/.zshrc" "$BACKUP_DIR/"
                    ;;
                "local")
                    [[ -d "$HOME/.local/scripts" && ! -L "$HOME/.local/scripts" ]] && mv "$HOME/.local/scripts" "$BACKUP_DIR/"
                    ;;
                *)
                    [[ -d "$HOME/.config/${dir}" && ! -L "$HOME/.config/${dir}" ]] && mv "$HOME/.config/${dir}" "$BACKUP_DIR/"
                    ;;
            esac
        done
    fi
}

# =============================================================================
# Executar stow
# =============================================================================
run_stow() {
    log_info "Executando stow para criar symlinks..."

    cd "$DOTFILES_DIR"

    for dir in "${STOW_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "  Stowing: $dir"
            stow -R "$dir" 2>/dev/null || {
                log_warn "  Restowing $dir com --adopt"
                stow --adopt -R "$dir"
            }
        else
            log_warn "  Diretório não encontrado: $dir"
        fi
    done
}

# =============================================================================
# Main
# =============================================================================
main() {
    echo ""
    echo "=================================================="
    echo "       Stow Setup - Symlink Dotfiles"
    echo "=================================================="
    echo ""

    check_stow
    create_dirs
    backup_existing
    run_stow

    echo ""
    log_info "Stow concluído com sucesso!"
    echo ""
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
