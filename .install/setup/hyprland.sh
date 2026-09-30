#!/bin/bash
# =============================================================================
# Hyprland Setup - Local Configuration
# =============================================================================
# Configures local Hyprland files that are not tracked by git
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATES_DIR="$DOTFILES_DIR/.data/hyprland/templates"
UWSM_TEMPLATES_DIR="$DOTFILES_DIR/.data/hyprland/uwsm"
QUICKSHELL_DATA_DIR="$DOTFILES_DIR/.data/quickshell"

# Destination directories
HYPR_CONFIG_DIR="$HOME/.config/hypr"
HYPR_LOCAL_DIR="$HYPR_CONFIG_DIR/local"
UWSM_ENV_DIR="$HOME/.config/uwsm/env.d"
QUICKSHELL_CONFIG_DIR="$HOME/.config/quickshell"

source "$DOTFILES_DIR/.install/lib/log.sh"

# =============================================================================
# Create directories
# =============================================================================
create_directories() {
    log_info "Creating local configuration directories..."
    mkdir -p "$HYPR_LOCAL_DIR"
    mkdir -p "$UWSM_ENV_DIR"
    mkdir -p "$QUICKSHELL_CONFIG_DIR"
    mkdir -p "$HOME/.local/themes"
    mkdir -p "$HOME/Pictures/Screenshots"
}

# =============================================================================
# Copy template if file doesn't exist
# =============================================================================
copy_template() {
    local TEMPLATE="$1"
    local DEST="$2"
    local DESC="$3"

    if [[ ! -f "$DEST" ]]; then
        if [[ -f "$TEMPLATE" ]]; then
            cp "$TEMPLATE" "$DEST"
            log_info "  Created: $DESC"
            return 0
        else
            log_warn "  Template not found: $TEMPLATE"
            return 1
        fi
    else
        log_warn "  Skipping (already exists): $DESC"
        return 0
    fi
}

# =============================================================================
# Configure monitors file
# =============================================================================
setup_monitors() {
    echo ""
    log_info "Configuring monitors.lua..."

    # In local/ with the other machine-specific files (hyprland.lua loads
    # every local/*.lua)
    local MONITORS_FILE="$HYPR_CONFIG_DIR/local/monitors.lua"
    mkdir -p "$HYPR_CONFIG_DIR/local"

    if [[ ! -f "$MONITORS_FILE" ]]; then
        # Automatic settings for every monitor; Settings › Hyprland ›
        # Monitors rewrites it
        cat >"$MONITORS_FILE" <<'EOF'
-- Monitors: managed by lyne (Settings › Hyprland › Monitors)
-- Automatic settings for every monitor until they're set up in Settings,
-- which rewrites this file (not tracked by git)

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

lyne_monitors_file = "automatic"
EOF
        log_info "  Created: local/monitors.lua (generic configuration)"
    else
        log_warn "  Skipping (already exists): local/monitors.lua"
    fi
}

# =============================================================================
# Configure QuickShell state.json
# =============================================================================
setup_quickshell() {
    echo ""
    log_info "Configuring QuickShell..."

    local STATE_FILE="$QUICKSHELL_CONFIG_DIR/state.json"
    local DEFAULTS_FILE="$QUICKSHELL_DATA_DIR/defaults.json"

    if [[ ! -f "$STATE_FILE" ]]; then
        if [[ -f "$DEFAULTS_FILE" ]]; then
            cp "$DEFAULTS_FILE" "$STATE_FILE"
            log_info "  Created: state.json (based on defaults.json)"
        else
            # Create minimal state.json if defaults.json doesn't exist
            cat >"$STATE_FILE" <<'EOF'
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
            log_info "  Created: state.json (minimal configuration)"
        fi
    else
        log_warn "  Skipping (already exists): state.json"
    fi
}

# =============================================================================
# Ask about NVIDIA (only when run on its own: install.sh asks beforehand and
# sets LYNE_NVIDIA_ENV to yes or no)
# =============================================================================
ask_nvidia() {
    echo ""
    echo -ne "\033[0;34m[?]\033[0m Do you have an NVIDIA GPU (hybrid or dedicated)? [y/N]: "
    read -r is_nvidia

    if [[ $is_nvidia =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Configure NVIDIA environment
# =============================================================================
setup_nvidia() {
    echo ""
    log_info "Configuring environment for NVIDIA..."

    # Hyprland extra_environment.lua
    copy_template \
        "$TEMPLATES_DIR/extra_environment_nvidia.lua" \
        "$HYPR_LOCAL_DIR/extra_environment.lua" \
        "local/extra_environment.lua (NVIDIA variables)"

    # UWSM global_hardware.sh
    copy_template \
        "$UWSM_TEMPLATES_DIR/global_hardware.sh" \
        "$UWSM_ENV_DIR/global_hardware.sh" \
        "uwsm/global_hardware.sh (global NVIDIA variables)"

    # UWSM hyprland_hardware.sh
    copy_template \
        "$UWSM_TEMPLATES_DIR/hyprland_hardware.sh" \
        "$UWSM_ENV_DIR/hyprland_hardware.sh" \
        "uwsm/hyprland_hardware.sh (Hyprland hardware)"

    echo ""
    log_info "NOTE: If you have a hybrid GPU (Intel + NVIDIA), you may need to"
    log_info "      edit the files in ~/.config/hypr/local/ and"
    log_info "      ~/.config/uwsm/env.d/ to uncomment AQ_DRM_DEVICES."
}

# =============================================================================
# Configure environment without NVIDIA
# =============================================================================
setup_no_nvidia() {
    echo ""
    log_info "Configuring default environment (no NVIDIA)..."

    # Hyprland extra_environment.lua (empty)
    if [[ ! -f "$HYPR_LOCAL_DIR/extra_environment.lua" ]]; then
        cat >"$HYPR_LOCAL_DIR/extra_environment.lua" <<'EOF'
-- =============================================================================
-- Extra Environment Variables - Local
-- =============================================================================
-- Machine-specific local environment variables.
-- This file is required by hyprland.lua
-- =============================================================================

-- Add machine-specific environment variables here
EOF
        log_info "  Created: local/extra_environment.lua (empty)"
    fi

    # UWSM - create empty files
    if [[ ! -f "$UWSM_ENV_DIR/global_hardware.sh" ]]; then
        echo "#!/bin/bash" >"$UWSM_ENV_DIR/global_hardware.sh"
        log_info "  Created: uwsm/global_hardware.sh (empty)"
    fi

    if [[ ! -f "$UWSM_ENV_DIR/hyprland_hardware.sh" ]]; then
        echo "#!/bin/bash" >"$UWSM_ENV_DIR/hyprland_hardware.sh"
        log_info "  Created: uwsm/hyprland_hardware.sh (empty)"
    fi
}

# =============================================================================
# Configure wallpapers
# =============================================================================
setup_wallpapers() {
    echo ""
    log_info "Configuring wallpapers..."

    local WALLPAPERS_DIR="$HOME/.local/wallpapers"
    local WALLPAPERS_DATA="$DOTFILES_DIR/.data/wallpapers"

    mkdir -p "$WALLPAPERS_DIR"

    # Copy initial wallpapers if directory is empty (ignores .gitkeep and .current)
    local file_count
    file_count=$(find "$WALLPAPERS_DIR" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' -o -name '*.gif' \) 2>/dev/null | wc -l)

    if [[ "$file_count" -eq 0 ]]; then
        if [[ -d "$WALLPAPERS_DATA/themes" ]]; then
            # Theme wallpaper folders (themes/{name}/lyne-{name}-{scene}.jpg,
            # made by .data/wallpapers/generator/generate.py)
            cp -rn "$WALLPAPERS_DATA/themes" "$WALLPAPERS_DIR/"
            # Each theme's default (contour) also goes to the root, the "all" view
            cp -n "$WALLPAPERS_DATA"/themes/*/lyne-*-contour.jpg "$WALLPAPERS_DIR/"
            log_info "  Theme wallpapers copied from .data/wallpapers/"
        else
            log_warn "  Initial wallpapers directory not found: $WALLPAPERS_DATA"
        fi
    else
        log_warn "  Skipping (wallpapers already exist): $WALLPAPERS_DIR"
    fi

}

# =============================================================================
# Configure themes
# =============================================================================
setup_themes() {
    echo ""
    log_info "Configuring themes..."

    local THEMES_DIR="$HOME/.local/themes"
    local THEMES_DATA="$DOTFILES_DIR/.data/themes"

    mkdir -p "$THEMES_DIR"

    # Copy theme JSON files if directory is empty
    local file_count
    file_count=$(find "$THEMES_DIR" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l)

    if [[ "$file_count" -eq 0 ]]; then
        if [[ -d "$THEMES_DATA" ]]; then
            cp -n "$THEMES_DATA"/*.json "$THEMES_DIR/" 2>/dev/null
            log_info "  Theme definitions copied from .data/themes/"
        else
            log_warn "  Theme data directory not found: $THEMES_DATA"
        fi
    else
        log_warn "  Skipping (themes already exist): $THEMES_DIR"
    fi
}

# =============================================================================
# Main (for direct execution)
# =============================================================================
run_hyprland_main() {
    echo ""
    echo "=================================================="
    echo "       Hyprland Setup - Local Configuration"
    echo "=================================================="
    echo ""

    create_directories
    setup_monitors
    setup_quickshell
    setup_wallpapers
    setup_themes

    if [[ -z "${LYNE_NVIDIA_ENV:-}" ]]; then
        ask_nvidia && LYNE_NVIDIA_ENV=yes || LYNE_NVIDIA_ENV=no
    fi

    if [[ "$LYNE_NVIDIA_ENV" == yes ]]; then
        setup_nvidia
    else
        setup_no_nvidia
    fi

    echo ""
    echo "=================================================="
    log_info "Hyprland configuration complete!"
    echo "=================================================="
    echo ""
    log_info "Files created/verified:"
    echo "  - ~/.config/hypr/local/monitors.lua"
    echo "  - ~/.config/hypr/local/extra_environment.lua"
    echo "  - ~/.config/uwsm/env.d/global_hardware.sh"
    echo "  - ~/.config/uwsm/env.d/hyprland_hardware.sh"
    echo "  - ~/.config/quickshell/state.json"
    echo "  - ~/.local/wallpapers/ (wallpapers)"
    echo "  - ~/.local/themes/ (theme definitions)"
    echo ""
    log_info "Set up your monitors in Settings › Hyprland › Monitors."
    log_info "Each monitor gets its own workspaces (conf/workspaces.lua), also after hotplug."
    echo ""
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_hyprland_main "$@"
fi
