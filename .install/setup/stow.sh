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
    "qt5ct"         # Qt5 theme configuration
    "qt6ct"         # Qt6 theme configuration
    "gtk"           # GTK 3/4 theme configuration
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
# Fazer backup de configs existentes
# =============================================================================
backup_existing() {
    local BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
    local NEED_BACKUP=false
    local ITEMS_TO_BACKUP=()

    # Verificar cada diretório
    for dir in "${STOW_DIRS[@]}"; do
        case "$dir" in
            "zsh")
                if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
                    NEED_BACKUP=true
                    ITEMS_TO_BACKUP+=("$HOME/.zshrc")
                fi
                if [[ -f "$HOME/.p10k.zsh" && ! -L "$HOME/.p10k.zsh" ]]; then
                    NEED_BACKUP=true
                    ITEMS_TO_BACKUP+=("$HOME/.p10k.zsh")
                fi
                ;;
            "tmux")
                if [[ -f "$HOME/.tmux.conf" && ! -L "$HOME/.tmux.conf" ]]; then
                    NEED_BACKUP=true
                    ITEMS_TO_BACKUP+=("$HOME/.tmux.conf")
                fi
                ;;
            "local")
                if [[ -d "$HOME/.local/scripts" && ! -L "$HOME/.local/scripts" ]]; then
                    # Verificar se tem arquivos dentro
                    if [[ "$(ls -A "$HOME/.local/scripts" 2>/dev/null)" ]]; then
                        NEED_BACKUP=true
                        ITEMS_TO_BACKUP+=("$HOME/.local/scripts")
                    fi
                fi
                ;;
            "kde")
                if [[ -f "$HOME/.config/kdeglobals" && ! -L "$HOME/.config/kdeglobals" ]]; then
                    NEED_BACKUP=true
                    ITEMS_TO_BACKUP+=("$HOME/.config/kdeglobals")
                fi
                ;;
            *)
                if [[ -d "$HOME/.config/${dir}" && ! -L "$HOME/.config/${dir}" ]]; then
                    NEED_BACKUP=true
                    ITEMS_TO_BACKUP+=("$HOME/.config/${dir}")
                fi
                ;;
        esac
    done

    # Fazer backup se necessário
    if $NEED_BACKUP; then
        log_warn "Configurações existentes encontradas. Fazendo backup..."
        mkdir -p "$BACKUP_DIR"

        for item in "${ITEMS_TO_BACKUP[@]}"; do
            if [[ -e "$item" ]]; then
                log_step "  Backup: $item"
                mv "$item" "$BACKUP_DIR/" 2>/dev/null || true
            fi
        done

        log_info "Backup salvo em: $BACKUP_DIR"
    else
        log_info "Nenhum backup necessário."
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
            # Tentar stow normal primeiro
            if ! stow -R "$dir" 2>/dev/null; then
                # Se falhar, tentar com --adopt
                log_warn "    Restowing $dir com --adopt"
                stow --adopt -R "$dir" 2>/dev/null || {
                    log_warn "    Falha ao fazer stow de $dir"
                }
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
    backup_existing
    execute_stow

    echo ""
    log_info "Stow concluído com sucesso!"
    echo ""
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_stow_main "$@"
fi
