#!/bin/bash
# =============================================================================
# Hyprland Setup - Local Configuration
# =============================================================================
# Configura arquivos locais do Hyprland que não são rastreados pelo git
# =============================================================================

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATES_DIR="$DOTFILES_DIR/.data/hyprland/templates"
UWSM_TEMPLATES_DIR="$DOTFILES_DIR/.data/hyprland/uwsm"

# Diretórios de destino
HYPR_CONFIG_DIR="$HOME/.config/hypr"
HYPR_LOCAL_DIR="$HYPR_CONFIG_DIR/local"
UWSM_ENV_DIR="$HOME/.config/uwsm/env.d"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_question() { echo -e "${BLUE}[?]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Criar diretórios
# =============================================================================
create_directories() {
    log_info "Criando diretórios de configuração local..."
    mkdir -p "$HYPR_LOCAL_DIR"
    mkdir -p "$UWSM_ENV_DIR"
}

# =============================================================================
# Copiar template se arquivo não existir
# =============================================================================
copy_template() {
    local TEMPLATE="$1"
    local DEST="$2"
    local DESC="$3"

    if [[ ! -f "$DEST" ]]; then
        if [[ -f "$TEMPLATE" ]]; then
            cp "$TEMPLATE" "$DEST"
            log_info "  Criado: $DESC"
        else
            log_warn "  Template não encontrado: $TEMPLATE"
        fi
    else
        log_warn "  Pulando (já existe): $DESC"
    fi
}

# =============================================================================
# Configurar arquivos de monitores e workspaces
# =============================================================================
setup_monitors_workspaces() {
    echo ""
    log_info "Configurando monitores e workspaces..."

    # monitors.conf
    copy_template \
        "$TEMPLATES_DIR/monitors.conf" \
        "$HYPR_CONFIG_DIR/monitors.conf" \
        "monitors.conf (configuração de monitores)"

    # workspaces.conf
    copy_template \
        "$TEMPLATES_DIR/workspaces.conf" \
        "$HYPR_CONFIG_DIR/workspaces.conf" \
        "workspaces.conf (mapeamento de workspaces)"
}

# =============================================================================
# Configurar arquivos locais do Hyprland
# =============================================================================
setup_local_configs() {
    echo ""
    log_info "Configurando arquivos locais do Hyprland..."

    # autostart.conf
    copy_template \
        "$TEMPLATES_DIR/autostart.conf" \
        "$HYPR_LOCAL_DIR/autostart.conf" \
        "local/autostart.conf (autostart local)"

    # extra_keybinds.conf
    copy_template \
        "$TEMPLATES_DIR/extra_keybinds.conf" \
        "$HYPR_LOCAL_DIR/extra_keybinds.conf" \
        "local/extra_keybinds.conf (keybinds locais)"
}

# =============================================================================
# Perguntar sobre NVIDIA
# =============================================================================
ask_nvidia() {
    echo ""
    log_question "Você tem uma GPU NVIDIA (híbrida ou dedicada)? [y/N]: "
    read -r is_nvidia

    if [[ $is_nvidia =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Configurar ambiente NVIDIA
# =============================================================================
setup_nvidia() {
    echo ""
    log_info "Configurando ambiente para NVIDIA..."

    # Hyprland extra_environment.conf
    copy_template \
        "$TEMPLATES_DIR/extra_environment_nvidia.conf" \
        "$HYPR_LOCAL_DIR/extra_environment.conf" \
        "local/extra_environment.conf (variáveis NVIDIA)"

    # UWSM global_hardware.sh
    copy_template \
        "$UWSM_TEMPLATES_DIR/global_hardware.sh" \
        "$UWSM_ENV_DIR/global_hardware.sh" \
        "uwsm/global_hardware.sh (variáveis globais NVIDIA)"

    # UWSM hyprland_hardware.sh
    copy_template \
        "$UWSM_TEMPLATES_DIR/hyprland_hardware.sh" \
        "$UWSM_ENV_DIR/hyprland_hardware.sh" \
        "uwsm/hyprland_hardware.sh (hardware Hyprland)"

    echo ""
    log_warn "NOTA: Se você tem GPU híbrida (Intel + NVIDIA), pode precisar"
    log_warn "      editar os arquivos em ~/.config/hypr/local/ e"
    log_warn "      ~/.config/uwsm/env.d/ para descomentar AQ_DRM_DEVICES."
}

# =============================================================================
# Configurar ambiente sem NVIDIA
# =============================================================================
setup_no_nvidia() {
    echo ""
    log_info "Configurando ambiente padrão (sem NVIDIA)..."

    # Hyprland extra_environment.conf (vazio)
    copy_template \
        "$TEMPLATES_DIR/extra_environment.conf" \
        "$HYPR_LOCAL_DIR/extra_environment.conf" \
        "local/extra_environment.conf (variáveis locais)"

    # UWSM - criar arquivos vazios
    if [[ ! -f "$UWSM_ENV_DIR/global_hardware.sh" ]]; then
        echo "#!/bin/bash" > "$UWSM_ENV_DIR/global_hardware.sh"
        log_info "  Criado: uwsm/global_hardware.sh (vazio)"
    fi

    if [[ ! -f "$UWSM_ENV_DIR/hyprland_hardware.sh" ]]; then
        echo "#!/bin/bash" > "$UWSM_ENV_DIR/hyprland_hardware.sh"
        log_info "  Criado: uwsm/hyprland_hardware.sh (vazio)"
    fi
}

# =============================================================================
# Criar diretório de screenshots
# =============================================================================
setup_screenshots_dir() {
    log_info "Criando diretório de screenshots..."
    mkdir -p "$HOME/Pictures/Screenshots"
}

# =============================================================================
# Main (para execução direta)
# =============================================================================
run_hyprland_main() {
    echo ""
    echo "=================================================="
    echo "       Hyprland Setup - Local Configuration"
    echo "=================================================="
    echo ""

    create_directories
    setup_monitors_workspaces
    setup_local_configs

    if ask_nvidia; then
        setup_nvidia
    else
        setup_no_nvidia
    fi

    setup_screenshots_dir

    echo ""
    echo "=================================================="
    log_info "Configuração do Hyprland concluída!"
    echo "=================================================="
    echo ""
    log_info "Arquivos criados:"
    echo "  - ~/.config/hypr/monitors.conf"
    echo "  - ~/.config/hypr/workspaces.conf"
    echo "  - ~/.config/hypr/local/extra_environment.conf"
    echo "  - ~/.config/hypr/local/autostart.conf"
    echo "  - ~/.config/hypr/local/extra_keybinds.conf"
    echo "  - ~/.config/uwsm/env.d/global_hardware.sh"
    echo "  - ~/.config/uwsm/env.d/hyprland_hardware.sh"
    echo ""
    log_info "Use 'nwg-displays' para configurar seus monitores."
    log_info "O workspace-manager.sh regenerará workspaces.conf automaticamente."
    echo ""
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_hyprland_main "$@"
fi
