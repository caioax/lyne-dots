#!/bin/bash
# =============================================================================
#
#   █   █▄█ █▄ █ █▀▀ ▄▄ █▀▄ █▀█ ▀█▀ █▀
#   █▄▄  █  █ ▀█ ██▄    █▄▀ █▄█  █  ▄█
#
#   Installation Script
#   https://github.com/caioax/lyne-dots
#
# =============================================================================
# Every question comes first (.install/lib/ask.sh); after the review screen
# and the sudo password the install runs on its own, showing its progress
# (.install/lib/run.sh) and writing everything to ~/.cache/lyne/install-*.log
# =============================================================================

# =============================================================================
# Configuration
# =============================================================================
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$DOTFILES_DIR/.install/packages"
SETUP_DIR="$DOTFILES_DIR/.install/setup"
LIB_DIR="$DOTFILES_DIR/.install/lib"

source "$LIB_DIR/log.sh"
source "$LIB_DIR/ui.sh"
source "$LIB_DIR/ask.sh"
source "$LIB_DIR/run.sh"
# lyne_state_set, also used by gpu-order.sh
source "$DOTFILES_DIR/.data/lyne-cli/lib/state.sh"

# Categories offered in the questionnaire (value|label|description|default).
# nvidia.sh has no packages yet: its environment files are a question of
# their own, and `--packages nvidia` still installs the list
CATEGORY_OPTIONS=(
    "core|core|Hyprland, UWSM, portals (essential)|1"
    "terminal|terminal|Kitty, Zsh, Tmux, Fastfetch|1"
    "editor|editor|Neovim + development tools|1"
    "apps|apps|Dolphin, Zen Browser, Spotify, Chromium, mpv|1"
    "utils|utils|Clipboard, audio, bluetooth, brightness|1"
    "fonts|fonts|Nerd Fonts, cursors, Tela icons|1"
    "quickshell|quickshell|QuickShell bar/shell|1"
    "theming|theming|Qt/GTK theming, matugen|1"
)

REBOOT_SECONDS=10

# =============================================================================
# Initial checks
# =============================================================================
check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        log_error "This script is for Arch Linux only!"
        exit 1
    fi
}

# makepkg refuses to run as root, and the files belong in the user's HOME
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Run the installer as your user, not as root (it asks for sudo)."
        exit 1
    fi
}

has_category() {
    [[ " ${CATEGORIES[*]} " == *" $1 "* ]]
}

# =============================================================================
# Package installation
# =============================================================================
install_packages() {
    local CATEGORY=$1
    local PACKAGES_FILE="$PACKAGES_DIR/${CATEGORY}.sh"

    if [[ ! -f "$PACKAGES_FILE" ]]; then
        log_error "Package file not found: $PACKAGES_FILE"
        return 1
    fi

    # Load package arrays
    source "$PACKAGES_FILE"

    local ARRAY_NAME="${CATEGORY^^}_PACKAGES"
    local AUR_ARRAY_NAME="${CATEGORY^^}_AUR_PACKAGES"

    # Convert to array using nameref
    local -n PACKAGES_REF="$ARRAY_NAME" 2>/dev/null || true
    local -n AUR_PACKAGES_REF="$AUR_ARRAY_NAME" 2>/dev/null || true

    # Install official packages
    if [[ ${#PACKAGES_REF[@]} -gt 0 ]]; then
        log_step "Installing official packages ($CATEGORY)..."
        sudo pacman -S --needed --noconfirm "${PACKAGES_REF[@]}" || {
            log_warn "Some packages may not be available"
        }
    fi

    # Install AUR packages
    if [[ ${#AUR_PACKAGES_REF[@]} -gt 0 ]]; then
        log_step "Installing AUR packages ($CATEGORY)..."
        $AUR_HELPER -S --needed --noconfirm "${AUR_PACKAGES_REF[@]}" || {
            log_warn "Some AUR packages may not be available"
        }
    fi
}

# Prints "<missing official> <missing AUR>" for a category: the packages its
# step still has to install (pacman -T also knows provides and groups)
missing_packages() {
    (
        source "$PACKAGES_DIR/$1.sh"
        local -n official="${1^^}_PACKAGES" aur="${1^^}_AUR_PACKAGES"
        local a=0 b=0
        ((${#official[@]})) && a=$(pacman -T "${official[@]}" 2>/dev/null | wc -l)
        ((${#aur[@]})) && b=$(pacman -T "${aur[@]}" 2>/dev/null | wc -l)
        echo "$a $b"
    )
}

# =============================================================================
# Install steps (each runs unattended, its output in the log file)
# =============================================================================
step_connection() {
    log_step "Checking internet connection..."
    if ! ping -c 1 -W 5 google.com &>/dev/null; then
        log_error "No internet connection!"
        return 1
    fi
    log_info "Connection OK"
}

step_aur_helper() {
    local helper
    if command -v yay &>/dev/null; then
        helper=yay
    elif command -v paru &>/dev/null; then
        helper=paru
    else
        log_warn "No AUR helper found (yay/paru), installing yay"
        install_yay || return 1
        helper=yay
    fi
    step_export AUR_HELPER "$helper"
    log_info "AUR helper: $helper"
}

install_yay() {
    sudo pacman -S --needed --noconfirm git base-devel || return 1
    local TEMP_DIR
    TEMP_DIR=$(mktemp -d)
    # The AUR (aur.archlinux.org) has been down for days at a time (DDoS),
    # and git would wait for it forever: a minute, then the same PKGBUILD
    # from the AUR's official GitHub mirror (one branch per package). No
    # credential prompt either: it would sit behind the progress screen
    if ! GIT_TERMINAL_PROMPT=0 timeout 60 git clone --progress --depth 1 \
        https://aur.archlinux.org/yay.git "$TEMP_DIR/yay"; then
        log_warn "The AUR isn't answering: yay comes from its GitHub mirror"
        rm -rf "$TEMP_DIR/yay"
        GIT_TERMINAL_PROMPT=0 timeout 300 git clone --progress --depth 1 --single-branch \
            --branch yay https://github.com/archlinux/aur.git "$TEMP_DIR/yay" || return 1
    fi
    (cd "$TEMP_DIR/yay" && makepkg -si --noconfirm) || return 1
    rm -rf "$TEMP_DIR"
}

step_base() {
    log_step "Installing GNU Stow and git..."
    sudo pacman -S --needed --noconfirm stow git
}

# step_nvidia <multilib 0|1>
step_nvidia() {
    source "$DOTFILES_DIR/.data/lyne-cli/lib/gpus.sh"
    source "$DOTFILES_DIR/.data/lyne-cli/lib/nvidia.sh"
    gpu_detect
    nvidia_plan "${1:-0}"
    nvidia_plan_lines | sed 's/^/[>>] Plan: /'
    nvidia_apply
}

# step_gpus <order spec>: /dev/dri links by PCI (udev) and the order
# Hyprland uses them in (local/gpus.lua, state.json)
step_gpus() {
    source "$DOTFILES_DIR/.data/lyne-cli/lib/gpus.sh"
    source "$DOTFILES_DIR/.data/lyne-cli/lib/gpu-order.sh"
    gpu_detect
    gpu_links
    gpu_rules_install
    [[ $? -eq 2 ]] && return 1
    local dup order=()
    for dup in $(gpu_rules_duplicates); do
        log_step "Removing $dup (makes the same links)"
        sudo rm -f "$dup"
    done
    local resolved
    resolved="$(gpu_order_resolve "${1:-auto}")" || return 1
    [[ -n "$resolved" ]] && mapfile -t order <<<"$resolved"
    gpu_order_write "${order[@]}" || return 1
    log_info "GPU order: ${order[*]:-automatic} (local/gpus.lua)"
}

step_stow() {
    source "$SETUP_DIR/stow.sh"
    run_stow_main
}

# The lyne-dots logo as a system icon (used by lyne update notifications)
step_icons() {
    log_step "Installing the lyne-dots icon..."
    local DOTS_DIR="$DOTFILES_DIR"
    source "$DOTFILES_DIR/.data/lyne-cli/lib/install-icons.sh"
}

step_hyprland() {
    source "$SETUP_DIR/hyprland.sh"
    run_hyprland_main
}

step_state_aur_helper() {
    local STATE_FILE="$HOME/.config/quickshell/state.json"

    if [[ ! -f "$STATE_FILE" ]]; then
        log_warn "state.json not found. Skipping AUR helper configuration."
        return 0
    fi

    if ! command -v jq &>/dev/null; then
        log_warn "jq not found. Skipping AUR helper configuration."
        return 0
    fi

    log_step "Setting AUR helper in state.json..."
    LYNE_STATE_FILE="$STATE_FILE" lyne_state_set '.system.aurHelper = $helper' --arg helper "$AUR_HELPER"
    log_info "AUR helper set to: $AUR_HELPER"
}

step_mimetypes() {
    # Folders, links and text files open with the default apps of
    # Settings > System > Apps (Dolphin, Zen Browser and Neovim at first),
    # and Dolphin's "Open terminal here" uses the default terminal
    log_step "Setting the default apps for xdg-open..."
    "$DOTFILES_DIR/quickshell/.config/quickshell/scripts/default-apps.sh" apply-all

    # Update KDE services database
    if command -v kbuildsycoca6 &>/dev/null; then
        log_step "Updating KDE services cache..."
        kbuildsycoca6 >/dev/null 2>&1
    fi
}

step_tela_icons() {
    source "$PACKAGES_DIR/fonts.sh"
    install_tela_icons
}

step_zsh() {
    # Change default shell to zsh (sudo: the install can't stop for chsh's
    # password prompt)
    if [[ "$SHELL" != *"zsh"* ]]; then
        log_step "Changing default shell to Zsh..."
        sudo chsh -s "$(command -v zsh)" "$USER" || return 1
        log_info "Shell changed to Zsh. Log out/in to apply."
    else
        log_info "Zsh is already the default shell."
    fi

    # Install Oh-My-Zsh
    local ZSH_DIR="$HOME/.oh-my-zsh"
    if [[ ! -d "$ZSH_DIR" ]]; then
        log_step "Installing Oh-My-Zsh..."
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH_DIR" || return 1
        log_info "Oh-My-Zsh installed."
    else
        log_info "Oh-My-Zsh is already installed."
    fi

    # Install plugins and themes
    local ZSH_CUSTOM_DIR="$ZSH_DIR/custom"
    local ZSH_DEPS=(
        "https://github.com/zsh-users/zsh-autosuggestions|plugins/zsh-autosuggestions"
        "https://github.com/zsh-users/zsh-syntax-highlighting|plugins/zsh-syntax-highlighting"
        "https://github.com/jeffreytse/zsh-vi-mode|plugins/zsh-vi-mode"
        "https://github.com/romkatv/powerlevel10k|themes/powerlevel10k"
    )

    local item
    for item in "${ZSH_DEPS[@]}"; do
        local URL="${item%%|*}"
        local DEST="${item##*|}"
        local NAME
        NAME=$(basename "$DEST")

        if [[ ! -d "$ZSH_CUSTOM_DIR/$DEST" ]]; then
            log_step "Installing $NAME..."
            if git clone --depth=1 "$URL" "$ZSH_CUSTOM_DIR/$DEST"; then
                log_info "$NAME installed."
            else
                log_warn "Could not install $NAME"
            fi
        else
            log_info "$NAME is already installed."
        fi
    done
}

step_tmux() {
    # Install TPM (Tmux Plugin Manager)
    local TPM_DIR="$HOME/.tmux/plugins/tpm"
    if [[ ! -d "$TPM_DIR" ]]; then
        log_step "Installing TPM (Tmux Plugin Manager)..."
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR" || return 1
        log_info "TPM installed. Use prefix + I inside tmux to install plugins."
    else
        log_info "TPM is already installed."
    fi
}

step_services() {
    # Bluetooth
    if systemctl list-unit-files | grep -q "bluetooth.service"; then
        log_step "Enabling Bluetooth..."
        sudo systemctl enable --now bluetooth.service || log_warn "Could not enable Bluetooth"
    fi

    # NetworkManager
    if systemctl list-unit-files | grep -q "NetworkManager.service"; then
        log_step "Enabling NetworkManager..."
        sudo systemctl enable --now NetworkManager.service || log_warn "Could not enable NetworkManager"
    fi

    # i2c-dev: ddcutil reaches external monitors through /dev/i2c-* (brightness)
    if [[ ! -f /etc/modules-load.d/i2c-dev.conf ]]; then
        log_step "Loading i2c-dev at boot..."
        echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
        sudo modprobe i2c-dev
    fi
    # ddcutil's udev rule gives the user access to nodes that already exist
    sudo udevadm trigger --subsystem-match=i2c-dev
}

step_wallpaper() {
    local CURRENT_FILE="$HOME/.local/wallpapers/.current"
    local WALLPAPER
    if [[ -f "$CURRENT_FILE" ]]; then
        WALLPAPER="$(cat "$CURRENT_FILE")"
    fi
    # Fallback to default if .current doesn't exist or points to a missing file
    if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
        WALLPAPER="$HOME/.local/wallpapers/themes/tokyonight/lyne-tokyonight-contour.jpg"
    fi

    # Check if awww is installed
    if ! command -v awww &>/dev/null; then
        log_warn "awww is not installed. Skipping wallpaper configuration."
        return 0
    fi

    # Check if the wallpaper exists
    if [[ ! -f "$WALLPAPER" ]]; then
        log_warn "Wallpaper not found: $WALLPAPER"
        return 0
    fi

    # Check if running in a Wayland session
    if [[ -z "$WAYLAND_DISPLAY" ]]; then
        log_info "Not in a Wayland session: the wallpaper will be applied when Hyprland starts."
        return 0
    fi

    log_step "Starting awww daemon..."
    # Start daemon if not running
    if ! pgrep -f "awww-daemon" &>/dev/null; then
        awww-daemon >/dev/null 2>&1 &
    fi
    sleep 3

    # Check if daemon started
    if ! pgrep -f "awww-daemon" &>/dev/null; then
        log_warn "Could not start awww daemon."
        return 0
    fi

    log_step "Applying wallpaper"
    if awww img "$WALLPAPER" --transition-type grow --transition-duration 2 2>/dev/null; then
        log_info "Wallpaper configured successfully!"
    else
        log_warn "Failed to apply wallpaper."
    fi
}

step_theming() {
    source "$PACKAGES_DIR/theming.sh"
    setup_theming
}

step_migrations() {
    local MIGRATIONS_DIR="$DOTFILES_DIR/.data/lyne-cli/migrations"
    local DONE_FILE="$HOME/.local/share/lyne/migrations-done"

    mkdir -p "$(dirname "$DONE_FILE")"
    touch "$DONE_FILE"

    # Mark all current migrations as done (fresh installs don't need them)
    local count=0 migration name
    for migration in "$MIGRATIONS_DIR"/*.sh; do
        [[ -f "$migration" ]] || continue
        name="$(basename "$migration")"
        if ! grep -qxF "$name" "$DONE_FILE" 2>/dev/null; then
            echo "$name" >>"$DONE_FILE"
            count=$((count + 1))
        fi
    done

    log_info "Marked $count migrations as done (fresh install)"
}

# The steps for the answers, in install order
plan_steps() {
    step_add step_connection "Checking the internet connection" 1 0 1
    step_add step_aur_helper "AUR helper (yay or paru)" 2 0 1
    step_add step_base "GNU Stow and git" 1 2 1

    local category missing official aur
    for category in "${CATEGORIES[@]}"; do
        read -r official aur <<<"$(missing_packages "$category")"
        # AUR packages are built here: they weigh more
        step_add "install_packages $category" "Packages $G_DOT $category" \
            $((1 + official + aur * 4)) $((official + aur))
    done

    if [[ "${ANSWERS[nvidia]}" == driver* ]]; then
        # DKMS builds the module for every kernel: a long step
        local multilib=0
        [[ "${ANSWERS[nvidia]}" == driver+multilib ]] && multilib=1
        nvidia_plan "$multilib"
        local count
        count=$(_nv_missing "${NV_REPO[@]}" "${NV_AUR[@]}" | wc -l)
        step_add "step_nvidia $multilib" "NVIDIA driver" $((2 + count * 2)) "$count"
    fi

    step_add step_stow "Linking the dotfiles (stow)" 1
    step_add step_icons "lyne-dots icon"
    step_add step_hyprland "Hyprland local files"
    gpu_multi && step_add "step_gpus ${ANSWERS[gpu_order]:-auto}" "GPU links and order"
    step_add step_state_aur_helper "Quickshell settings"
    step_add step_mimetypes "Default apps"
    has_category fonts && step_add step_tela_icons "Tela icon theme" 2
    if has_category terminal; then
        step_add step_zsh "Zsh and Oh My Zsh" 2
        step_add step_tmux "Tmux plugin manager"
    fi
    has_category utils && step_add step_services "Services (Bluetooth, network, i2c)"
    has_category core && step_add step_wallpaper "Wallpaper"
    has_category theming && step_add step_theming "GTK theme and matugen"
    step_add step_migrations "Lyne CLI"
}

# =============================================================================
# Questionnaire
# =============================================================================
q_categories() {
    ask_multi categories "What should be installed?" \
        "The dotfiles are always linked; these are the packages that go with them." \
        "${CATEGORY_OPTIONS[@]}"
}

# The GPUs found (gpus.sh), then what to do about NVIDIA: the driver
# (nvidia.sh) and the environment variables, only the variables, or nothing
_graphics_rows() {
    local i name_w=$((UI_WIDTH - 2 - 8 - 22 - 12))
    ((name_w > 34)) && name_w=34
    # (none found: the text above already says it)
    for ((i = 0; i < GPU_COUNT; i++)); do
        local outputs
        outputs="$(gpu_connected "$i")"
        ui_add "  $C_BOLD$(ui_pad "${GPU_BRAND[i]}" 8)$C_RESET$(ui_pad "${GPU_NAME[i]}" "$name_w") $C_DIM$(ui_pad "$(gpu_kind_label "$i")" 21)$(ui_fit "$outputs" 11)$C_RESET"
        if [[ -n "${GPU_FAMILY[i]}" ]]; then
            ui_add "          $C_DIM$(ui_fit "$(gpu_driver_note "${GPU_FAMILY[i]}")" $((UI_WIDTH - 10)))$C_RESET"
        fi
    done
    UI_LINES+=("")
    ui_add "$_GRAPHICS_ASK"
}

# The package that installs the driver for this GPU
_nvidia_driver_pkg() {
    [[ "$NV_FAMILY" == open ]] && echo nvidia-open-dkms || echo "nvidia-580xx-dkms (AUR)"
}

q_graphics() {
    local ASK_EXTRA=_graphics_rows setup options=()
    setup="$(gpu_setup_label)"
    case "$NV_ACTION" in
    install | replace | ok)
        local driver
        case "$NV_ACTION" in
        install) driver="install $(_nvidia_driver_pkg)" ;;
        replace) driver="switch to $(_nvidia_driver_pkg)" ;;
        ok) driver="$NV_CURRENT is installed: check it" ;;
        esac
        _GRAPHICS_ASK="NVIDIA driver and environment variables for Hyprland and UWSM?"
        options+=("driver|Driver + environment|$driver|1")
        nv_multilib_on || options+=("driver+multilib|Driver + 32-bit|also enables multilib (Steam, Wine)")
        options+=("env|Environment only|the driver is set up another way" "none|Nothing|")
        ;;
    unsupported)
        _GRAPHICS_ASK="NVIDIA environment variables for Hyprland and UWSM?"
        options+=("none|No|nouveau drives this GPU|1" "env|Yes|only with a driver you set up yourself")
        ;;
    *)
        _GRAPHICS_ASK="NVIDIA environment variables for Hyprland and UWSM?"
        options+=("env|Yes|for an NVIDIA GPU not listed here" "none|No|no NVIDIA GPU was found|1")
        ;;
    esac
    ask_single nvidia "Graphics" "${setup^}." "${options[@]}"
}

# Hybrid machines: which GPU renders Hyprland (gpu-order.sh). Same screen
# title and GPU list as the question before
q_gpu_order() {
    ((GPU_HYBRID)) && gpu_multi || return 3
    # shellcheck disable=SC2034 # ASK_EXTRA is read by the ask_* functions this calls
    local ASK_EXTRA=_graphics_rows _GRAPHICS_ASK="Which GPU renders the desktop?"
    local igpu dgpu i
    for ((i = 0; i < GPU_COUNT; i++)); do
        [[ "${GPU_KIND[i]}" == integrated && -z "${igpu:-}" ]] && igpu=${GPU_BRAND[i]}
        [[ "${GPU_KIND[i]}" == dedicated && -z "${dgpu:-}" ]] && dgpu=${GPU_BRAND[i]}
    done
    ask_single gpu_order "Graphics" "Both GPUs stay in use: the other one drives the monitors plugged into it. Change it later with lyne gpu order." \
        "igpu|$igpu (integrated)|uses less power, recommended for laptops|1" \
        "dgpu|$dgpu (dedicated)|faster, and no copy for monitors on it" \
        "auto|Automatic|Hyprland picks: the GPU of the built-in screen"
}

# "Intel renders, then NVIDIA"
_gpu_order_label() {
    local spec=$1 pci i names=()
    [[ "$spec" == auto ]] && { echo "automatic"; return; }
    while read -r pci; do
        i="$(_gpu_index_of_pci "$pci")" && names+=("${GPU_BRAND[i]}")
    done < <(gpu_order_resolve "$spec" 2>/dev/null)
    local label="${names[0]} renders"
    ((${#names[@]} > 1)) && label+=", then ${names[*]:1}"
    echo "$label"
}

q_reboot() {
    ask_single reboot "Reboot when it's done?" \
        "Hyprland needs a new session. The reboot waits $REBOOT_SECONDS seconds (any key cancels it) and never happens after a failure." \
        "yes|Reboot|after a $REBOOT_SECONDS second countdown|1" \
        "no|Don't reboot|reboot or log out yourself later"
}

# Short list of the targets that go to the backup: "hypr, kitty, +2"
backup_summary() {
    local -a names=()
    local target
    while IFS= read -r target; do
        [[ -n "$target" ]] && names+=("$(basename "$target")")
    done < <(source "$SETUP_DIR/stow.sh" && stow_existing_targets)
    ((${#names[@]} == 0)) && return
    local shown="${names[*]:0:3}"
    shown="${shown// /, }"
    ((${#names[@]} > 3)) && shown+=", +$((${#names[@]} - 3))"
    printf '%s to %s' "$shown" "${LYNE_BACKUP_DIR/#$HOME/\~}"
}

q_review() {
    local -a rows=()
    local categories=${ANSWERS[categories]}
    rows+=("Packages|${categories:-none, only the dotfiles}")
    rows+=("Graphics|$(gpu_summary)")
    case "${ANSWERS[nvidia]}" in
    driver*)
        local driver="$(_nvidia_driver_pkg), kernel headers, initramfs drop-in"
        [[ "$NV_ACTION" == replace ]] && driver="replaces $NV_CURRENT with $driver"
        [[ "$NV_ACTION" == ok ]] && driver="check $NV_CURRENT (headers, initramfs drop-in)"
        [[ "${ANSWERS[nvidia]}" == driver+multilib ]] && driver+=", multilib"
        rows+=("NVIDIA|$driver; environment")
        ;;
    env) rows+=("NVIDIA|environment variables only") ;;
    *) rows+=("NVIDIA|no") ;;
    esac
    if gpu_multi; then
        local gpu_order=auto
        ((GPU_HYBRID)) && gpu_order=${ANSWERS[gpu_order]:-auto}
        rows+=("GPU order|$(_gpu_order_label "$gpu_order") (/dev/dri links by PCI)")
    fi
    local backup
    backup="$(backup_summary)"
    rows+=("Backup|${backup:-nothing to move}")
    if [[ " $categories " == *" terminal "* && "$SHELL" != *zsh* ]]; then
        rows+=("Shell|Zsh becomes the default shell")
    fi
    if [[ "${ANSWERS[reboot]}" == yes ]]; then
        rows+=("Reboot|after a $REBOOT_SECONDS second countdown")
    else
        rows+=("Reboot|no")
    fi
    local log="${XDG_CACHE_HOME:-$HOME/.cache}/lyne/install-$STAMP.log"
    rows+=("Log|${log/#$HOME/\~}")
    [[ -n "${LYNE_DRY_RUN:-}" ]] && rows+=("Dry run|HOME is ${LYNE_DRY_HOME}")

    ask_review "Ready to install" \
        "Nothing else is asked after this: the sudo password comes next, then everything runs on its own." \
        "${rows[@]}"
}

QUESTIONS=(q_categories q_graphics q_gpu_order q_reboot q_review)

# Answers not in an --answers file
answer_defaults() {
    if [[ ! -v "ANSWERS[categories]" ]]; then
        local opt
        ANSWERS[categories]=""
        for opt in "${CATEGORY_OPTIONS[@]}"; do
            ANSWERS[categories]+="${opt%%|*} "
        done
    fi
    # nvidia=driver|driver+multilib|env|none; nvidia_env=yes|no (the step 2
    # answer) still means env or none; multilib=yes adds it to the driver
    if [[ ! -v "ANSWERS[nvidia]" ]]; then
        if [[ -v "ANSWERS[nvidia_env]" ]]; then
            [[ "${ANSWERS[nvidia_env]}" == yes ]] && ANSWERS[nvidia]="env" || ANSWERS[nvidia]=none
        else
            case "$NV_ACTION" in
            install | replace | ok) ANSWERS[nvidia]=driver ;;
            *) ANSWERS[nvidia]=none ;;
            esac
        fi
    fi
    if [[ "${ANSWERS[nvidia]}" == driver && "${ANSWERS[multilib]:-}" == yes ]]; then
        ANSWERS[nvidia]="driver+multilib"
    fi
    # GPU order (hybrid machines): integrated first unless answered
    if [[ ! -v "ANSWERS[gpu_order]" ]]; then
        ANSWERS[gpu_order]=auto
        ((GPU_HYBRID)) && ANSWERS[gpu_order]=igpu
    fi
    # Only a GPU with a driver can get one
    if [[ "${ANSWERS[nvidia]}" == driver* ]]; then
        case "$NV_ACTION" in
        install | replace | ok) ;;
        *) ANSWERS[nvidia]=none ;;
        esac
    fi
    [[ -v "ANSWERS[reboot]" ]] || ANSWERS[reboot]=no
}

# =============================================================================
# Summary and reboot
# =============================================================================
show_summary() {
    local i mark
    echo ""
    if ((RUN_CANCELLED)); then
        log_warn "Installation cancelled."
    elif ((RUN_ABORTED)); then
        log_header "Installation stopped"
    elif run_ok; then
        log_header "Installation Complete!"
    else
        log_header "Installation finished with problems"
    fi

    for i in "${!STEP_FNS[@]}"; do
        # shellcheck disable=SC2153 # the G_* glyphs come from .install/lib/ui.sh
        case ${STEP_STATUS[i]} in
        ok) mark="$C_OK$G_OK" ;;
        warn) mark="$C_WARN$G_WARN" ;;
        fail) mark="$C_FAIL$G_FAIL" ;;
        *) mark="$C_DIM$G_SKIP" ;;
        esac
        printf '  %s%s %s' "$mark" "$C_RESET" "${STEP_LABELS[i]}"
        [[ -n "${STEP_NOTES[i]}" ]] && printf '  %s%s%s' "$C_DIM" "${STEP_NOTES[i]}" "$C_RESET"
        printf '\n'
    done
    echo ""
    echo "  Took $(_run_clock "$RUN_SECONDS"). Full output: ${LOG_FILE/#$HOME/\~}"
    if [[ -d "$LYNE_BACKUP_DIR" ]]; then
        echo "  Your previous files are in ${LYNE_BACKUP_DIR/#$HOME/\~}"
    fi
    [[ -n "${LYNE_DRY_RUN:-}" ]] && echo "  Dry run: the files written are in $LYNE_DRY_HOME"

    if ((RUN_CANCELLED || RUN_ABORTED)); then
        echo ""
        echo "  The steps marked $G_SKIP didn't run. Run ./install.sh again to finish."
        echo ""
        return
    fi

    echo ""
    echo -e "${C_WARN}Next steps:${C_RESET}"
    echo "  1. Log out and select 'Hyprland (uwsm)' in your display manager"
    echo "  2. Or start manually with: uwsm start hyprland-uwsm.desktop"
    echo ""
    echo "  3. Set up your monitors in Settings › Hyprland › Monitors"
    echo "  4. Each monitor gets its own workspaces automatically"
    echo ""

    if has_category terminal; then
        echo "  5. In tmux, use prefix + I to install plugins"
    fi

    if gpu_multi; then
        echo ""
        echo -e "${C_WARN}GPUs:${C_RESET}"
        echo "  - Links and order: lyne gpu (lyne gpu order changes which GPU renders)"
    fi

    if [[ "$LYNE_NVIDIA_ENV" == yes ]]; then
        echo ""
        echo -e "${C_WARN}NVIDIA:${C_RESET}"
        [[ "${ANSWERS[nvidia]}" == driver* ]] && echo "  - After the reboot, check the driver with: lyne nvidia"
        echo "  - Review ~/.config/hypr/local/extra_environment.lua"
    fi

    echo ""
    log_info "Enjoy your new setup!"
    echo ""
}

# The reboot chosen in the questionnaire: a countdown any key cancels, and
# only after a clean install
reboot_countdown() {
    [[ "${ANSWERS[reboot]}" == yes ]] || {
        log_info "Remember to reboot the system to apply all changes."
        return
    }
    if ! run_ok; then
        log_warn "Not rebooting: some steps failed (see the log). Reboot when they're fixed."
        return
    fi

    local left key
    # Keys pressed during the install would cancel it at once
    while IFS= read -rsn1 -t 0.01 key </dev/tty 2>/dev/null; do :; done
    for ((left = REBOOT_SECONDS; left > 0; left--)); do
        printf '\r%sRebooting in %2d s%s %s press any key to cancel ' "$C_WARN" "$left" "$C_RESET" "$G_DOT"
        if IFS= read -rsn1 -t 1 key </dev/tty 2>/dev/null; then
            printf '\n'
            log_info "Reboot cancelled. Remember to reboot to apply all changes."
            return
        fi
    done
    printf '\n'
    log_info "Rebooting..."
    sudo reboot
}

# =============================================================================
# Main
# =============================================================================
cleanup() {
    ui_leave
    run_sudo_stop
    [[ -n "${RUN_STATE:-}" ]] && rm -f "$RUN_STATE"
}

main() {
    check_arch
    check_not_root

    STAMP="$(date +%Y%m%d-%H%M%S)"
    export LYNE_BACKUP_DIR="$HOME/.lyne-dots-backup/$STAMP"
    # The GPUs, for the Graphics question and the log
    source "$DOTFILES_DIR/.data/lyne-cli/lib/gpus.sh"
    source "$DOTFILES_DIR/.data/lyne-cli/lib/nvidia.sh"
    source "$DOTFILES_DIR/.data/lyne-cli/lib/gpu-order.sh"
    gpu_detect
    gpu_links
    nvidia_plan 0

    ui_setup
    # Plain summary when the output goes to a file
    [[ -t 1 ]] || C_RESET="" C_DIM="" C_OK="" C_WARN="" C_FAIL=""
    trap cleanup EXIT

    # FIRST: every question (nothing is installed before the review)
    if [[ -n "$ANSWERS_FILE" ]]; then
        ask_load "$ANSWERS_FILE"
        answer_defaults
    else
        if [[ ! -t 0 || ! -t 1 ]]; then
            log_error "The installer needs a terminal (or answers from a file: --answers FILE)."
            exit 1
        fi
        trap 'ui_leave; echo; log_info "Installation cancelled."; exit 130' INT TERM
        ui_enter
        if ! ask_run "${QUESTIONS[@]}"; then
            ui_leave
            log_info "Installation cancelled."
            exit 0
        fi
        ui_leave
    fi

    read -ra CATEGORIES <<<"${ANSWERS[categories]}"
    LYNE_NVIDIA_ENV=no
    [[ "${ANSWERS[nvidia]}" == none ]] || LYNE_NVIDIA_ENV=yes
    export LYNE_NVIDIA_ENV

    # sudo once, kept alive until the end
    log_step "The installation needs your sudo password (asked only now)."
    if ! run_sudo_start; then
        log_error "sudo failed; nothing was installed."
        exit 1
    fi

    run_log_init "$STAMP"
    {
        echo "lyne-dots install $(date -Iseconds)"
        echo "dotfiles: $DOTFILES_DIR ($(git -C "$DOTFILES_DIR" rev-parse --short HEAD 2>/dev/null))"
        local key
        for key in "${!ANSWERS[@]}"; do echo "answer $key=${ANSWERS[$key]}"; done
        [[ -n "${LYNE_DRY_RUN:-}" ]] && echo "dry run, HOME=$HOME"
        echo ""
        gpu_status
    } >>"$LOG_FILE"

    plan_steps

    trap run_cancel INT TERM
    if [[ -t 1 ]]; then
        ui_enter
        ui_keys_off
        run_steps
        ui_leave
    else
        RUN_PLAIN=1 run_steps
    fi
    trap - INT TERM

    show_summary
    ((RUN_CANCELLED)) && exit 130
    ((RUN_ABORTED)) && exit 1
    reboot_countdown
    run_ok
}

usage() {
    echo "Usage: ./install.sh [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h        Show this help"
    echo "  --stow-only       Only run stow (symlinks; existing files go to a backup)"
    echo "  --setup-only      Only run Hyprland setup"
    echo "  --packages PKG    Install only the specified category"
    echo "  --answers FILE    Take the answers from FILE (id=value lines) instead of"
    echo "                    asking: categories=core terminal ...,"
    echo "                    nvidia=driver|env|none (default: the driver when the GPU"
    echo "                    found has one), multilib=yes (lib32 driver),"
    echo "                    gpu_order=igpu|dgpu|auto (hybrid machines), reboot=yes|no"
    echo "  --dry-run         Change nothing: a throwaway HOME and stand-ins for sudo,"
    echo "                    pacman -S, yay, stow, systemctl... (LYNE_DRY_HOME=dir"
    echo "                    reuses one)"
    echo ""
    echo "Available categories:"
    echo "  core, terminal, editor, apps, utils, fonts, quickshell, theming, nvidia"
}

# =============================================================================
# Command line arguments
# =============================================================================
MODE=install
ANSWERS_FILE=""
PACKAGE_CATEGORY=""
while (($#)); do
    case "$1" in
    --help | -h)
        usage
        exit 0
        ;;
    --stow-only) MODE=stow ;;
    --setup-only) MODE=setup ;;
    --packages)
        MODE=packages
        PACKAGE_CATEGORY="${2:-}"
        [[ $# -gt 1 ]] && shift
        ;;
    --answers)
        ANSWERS_FILE="${2:-}"
        if [[ ! -f "$ANSWERS_FILE" ]]; then
            log_error "Answers file not found: $ANSWERS_FILE"
            exit 1
        fi
        ANSWERS_FILE="$(realpath "$ANSWERS_FILE")"
        shift
        ;;
    --dry-run) DRY_RUN=1 ;;
    *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
    shift
done

[[ -n "${DRY_RUN:-}" ]] && run_dry_setup

case "$MODE" in
stow)
    check_arch
    sudo pacman -S --needed --noconfirm stow
    source "$SETUP_DIR/stow.sh"
    run_stow_main
    ;;
setup)
    check_arch
    source "$SETUP_DIR/hyprland.sh"
    run_hyprland_main
    ;;
packages)
    check_arch
    if [[ -z "$PACKAGE_CATEGORY" ]]; then
        log_error "Please specify a category!"
        exit 1
    fi
    RUN_STATE="$(mktemp)"
    step_connection || exit 1
    step_aur_helper || exit 1
    source "$RUN_STATE"
    rm -f "$RUN_STATE"
    if [[ "$PACKAGE_CATEGORY" == nvidia ]]; then
        # The driver for the GPU found (like lyne nvidia install, no questions)
        sudo -v || exit 1
        step_nvidia 0
    else
        install_packages "$PACKAGE_CATEGORY"
    fi
    ;;
*)
    main
    ;;
esac
