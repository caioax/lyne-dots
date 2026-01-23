#!/bin/bash
# =============================================================================
# Hyprland Setup - Local Configuration
# =============================================================================
# Configura arquivos locais do Hyprland que não são rastreados pelo git
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATES_DIR="$DOTFILES_DIR/.data/hyprland/templates"
UWSM_TEMPLATES_DIR="$DOTFILES_DIR/.data/hyprland/uwsm"
QUICKSHELL_DATA_DIR="$DOTFILES_DIR/.data/quickshell"

# Diretórios de destino
HYPR_CONFIG_DIR="$HOME/.config/hypr"
HYPR_LOCAL_DIR="$HYPR_CONFIG_DIR/local"
UWSM_ENV_DIR="$HOME/.config/uwsm/env.d"
QUICKSHELL_CONFIG_DIR="$HOME/.config/quickshell"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_question() { echo -e "${BLUE}[?]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[>>]${NC} $1"; }

# =============================================================================
# Criar diretórios
# =============================================================================
create_directories() {
    log_info "Criando diretórios de configuração local..."
    mkdir -p "$HYPR_LOCAL_DIR"
    mkdir -p "$UWSM_ENV_DIR"
    mkdir -p "$QUICKSHELL_CONFIG_DIR"
    mkdir -p "$HOME/Pictures/Screenshots"
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
            return 0
        else
            log_warn "  Template não encontrado: $TEMPLATE"
            return 1
        fi
    else
        log_warn "  Pulando (já existe): $DESC"
        return 0
    fi
}

# =============================================================================
# Configurar arquivo de monitores
# =============================================================================
setup_monitors() {
    echo ""
    log_info "Configurando monitors.conf..."

    local MONITORS_FILE="$HYPR_CONFIG_DIR/monitors.conf"

    if [[ ! -f "$MONITORS_FILE" ]]; then
        # Criar arquivo com configuração genérica do Hyprland
        cat > "$MONITORS_FILE" << 'EOF'
# =============================================================================
# Monitor Configuration
# =============================================================================
# Este arquivo é criado na primeira instalação.
# Use 'nwg-displays' para configurar seus monitores graficamente.
# Este arquivo não é rastreado pelo git.
# See https://wiki.hypr.land/Configuring/Monitors/
# =============================================================================

# Configuração genérica - detecta automaticamente resolução e taxa
monitor=,preferred,auto,auto
EOF
        log_info "  Criado: monitors.conf (configuração genérica)"
    else
        log_warn "  Pulando (já existe): monitors.conf"
    fi
}

# =============================================================================
# Configurar arquivo de workspaces
# =============================================================================
setup_workspaces() {
    log_info "Configurando workspaces.conf..."

    local WORKSPACES_FILE="$HYPR_CONFIG_DIR/workspaces.conf"

    if [[ ! -f "$WORKSPACES_FILE" ]]; then
        # Criar arquivo vazio (será preenchido pelo workspace-manager.sh)
        cat > "$WORKSPACES_FILE" << 'EOF'
# =============================================================================
# Workspaces Configuration
# =============================================================================
# Este arquivo é gerado automaticamente pelo workspace-manager.sh no boot.
# Não edite manualmente - suas alterações serão sobrescritas.
# =============================================================================
EOF
        log_info "  Criado: workspaces.conf (será preenchido automaticamente)"
    else
        log_warn "  Pulando (já existe): workspaces.conf"
    fi
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
# Configurar QuickShell state.json
# =============================================================================
setup_quickshell() {
    echo ""
    log_info "Configurando QuickShell..."

    local STATE_FILE="$QUICKSHELL_CONFIG_DIR/state.json"
    local DEFAULTS_FILE="$QUICKSHELL_DATA_DIR/defaults.json"

    if [[ ! -f "$STATE_FILE" ]]; then
        if [[ -f "$DEFAULTS_FILE" ]]; then
            cp "$DEFAULTS_FILE" "$STATE_FILE"
            log_info "  Criado: state.json (baseado em defaults.json)"
        else
            # Criar state.json mínimo se defaults.json não existir
            cat > "$STATE_FILE" << 'EOF'
{
  "nightLight": {
    "enabled": false,
    "intensity": 0.5
  },
  "bar": {
    "autoHide": true,
    "height": 32
  }
}
EOF
            log_info "  Criado: state.json (configuração mínima)"
        fi
    else
        log_warn "  Pulando (já existe): state.json"
    fi
}

# =============================================================================
# Perguntar sobre NVIDIA
# =============================================================================
ask_nvidia() {
    echo ""
    echo -ne "${BLUE}[?]${NC} Você tem uma GPU NVIDIA (híbrida ou dedicada)? [y/N]: "
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
    if [[ ! -f "$HYPR_LOCAL_DIR/extra_environment.conf" ]]; then
        cat > "$HYPR_LOCAL_DIR/extra_environment.conf" << 'EOF'
# =============================================================================
# Extra Environment Variables - Local
# =============================================================================
# Variáveis de ambiente locais específicas da máquina.
# Este arquivo é sourced pelo hyprland.conf
# =============================================================================

# Adicione variáveis de ambiente específicas aqui
EOF
        log_info "  Criado: local/extra_environment.conf (vazio)"
    fi

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
# Main (para execução direta)
# =============================================================================
run_hyprland_main() {
    echo ""
    echo "=================================================="
    echo "       Hyprland Setup - Local Configuration"
    echo "=================================================="
    echo ""

    create_directories
    setup_monitors
    setup_workspaces
    setup_local_configs
    setup_quickshell

    if ask_nvidia; then
        setup_nvidia
    else
        setup_no_nvidia
    fi

    echo ""
    echo "=================================================="
    log_info "Configuração do Hyprland concluída!"
    echo "=================================================="
    echo ""
    log_info "Arquivos criados/verificados:"
    echo "  - ~/.config/hypr/monitors.conf"
    echo "  - ~/.config/hypr/workspaces.conf"
    echo "  - ~/.config/hypr/local/extra_environment.conf"
    echo "  - ~/.config/hypr/local/autostart.conf"
    echo "  - ~/.config/hypr/local/extra_keybinds.conf"
    echo "  - ~/.config/uwsm/env.d/global_hardware.sh"
    echo "  - ~/.config/uwsm/env.d/hyprland_hardware.sh"
    echo "  - ~/.config/quickshell/state.json"
    echo ""
    log_info "Use 'nwg-displays' para configurar seus monitores."
    log_info "O workspace-manager.sh regenerará workspaces.conf automaticamente."
    echo ""
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_hyprland_main "$@"
fi
