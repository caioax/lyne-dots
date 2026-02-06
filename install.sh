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

set -e

# =============================================================================
# Configuration
# =============================================================================
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$DOTFILES_DIR/.install/packages"
SETUP_DIR="$DOTFILES_DIR/.install/setup"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# Logging functions
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
# Initial checks
# =============================================================================
check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        log_error "This script is for Arch Linux only!"
        exit 1
    fi
}

check_internet() {
    log_step "Checking internet connection..."
    if ! ping -c 1 google.com &>/dev/null; then
        log_error "No internet connection!"
        exit 1
    fi
    log_info "Connection OK"
}

check_aur_helper() {
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
        AUR_HELPER="paru"
    else
        log_warn "No AUR helper found (yay/paru)"
        log_info "Installing yay..."
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

# =============================================================================
# Category selection menu
# =============================================================================
show_menu() {
    echo ""
    echo -e "${CYAN}Select categories to install:${NC}"
    echo ""
    echo "  1) core                - Hyprland, UWSM, portal (ESSENTIAL)"
    echo "  2) terminal            - Kitty, Zsh, Tmux, Fastfetch"
    echo "  3) editor              - Neovim + development tools"
    echo "  4) apps                - Dolphin, Zen Browser, Spotify, mpv"
    echo "  5) utils               - Clipboard, playerctl, audio, etc"
    echo "  6) fonts               - Nerd Fonts, cursors, icons"
    echo "  7) quickshell          - QuickShell bar/shell"
    echo "  8) theming             - Qt/GTK theming"
    echo "  9) nvidia(developing)  - NVIDIA drivers (only if you have an NVIDIA GPU)"
    echo ""
    echo "  a) ALL                 - Install everything (except nvidia)"
    echo "  n) ALL+NVIDIA          - Install everything (including nvidia)"
    echo "  q) QUIT                - Exit"
    echo ""
}

get_selection() {
    local SELECTED=()

    while true; do
        show_menu
        echo -ne "${BLUE}Select numbers or letters separated by spaces: ${NC}"
        read -r input

        case "$input" in
        q | Q)
            log_info "Installation cancelled."
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
                *) log_warn "Invalid option: $num" ;;
                esac
            done

            if [[ ${#SELECTED[@]} -gt 0 ]]; then
                break
            fi
            ;;
        esac
    done

    # Remove duplicates
    CATEGORIES=($(printf "%s\n" "${SELECTED[@]}" | sort -u))
}

# =============================================================================
# Setup functions
# =============================================================================
run_stow() {
    log_header "Creating Symlinks (Stow)"
    source "$SETUP_DIR/stow.sh"
    run_stow_main
}

run_hyprland_setup() {
    log_header "Configuring Hyprland"
    source "$SETUP_DIR/hyprland.sh"
    run_hyprland_main
}

setup_zsh() {
    log_header "Configuring Zsh"

    # Change default shell to zsh
    if [[ "$SHELL" != *"zsh"* ]]; then
        log_step "Changing default shell to Zsh..."
        chsh -s $(which zsh)
        log_info "Shell changed to Zsh. Log out/in to apply."
    else
        log_info "Zsh is already the default shell."
    fi

    # Install Oh-My-Zsh
    local ZSH_DIR="$HOME/.oh-my-zsh"
    if [[ ! -d "$ZSH_DIR" ]]; then
        log_step "Installing Oh-My-Zsh..."
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH_DIR"
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

    for item in "${ZSH_DEPS[@]}"; do
        local URL="${item%%|*}"
        local DEST="${item##*|}"
        local NAME=$(basename "$DEST")

        if [[ ! -d "$ZSH_CUSTOM_DIR/$DEST" ]]; then
            log_step "Installing $NAME..."
            git clone --depth=1 "$URL" "$ZSH_CUSTOM_DIR/$DEST"
            log_info "$NAME installed."
        else
            log_info "$NAME is already installed."
        fi
    done
}

setup_tmux() {
    log_header "Configuring Tmux"

    # Install TPM (Tmux Plugin Manager)
    local TPM_DIR="$HOME/.tmux/plugins/tpm"
    if [[ ! -d "$TPM_DIR" ]]; then
        log_step "Installing TPM (Tmux Plugin Manager)..."
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
        log_info "TPM installed. Use prefix + I inside tmux to install plugins."
    else
        log_info "TPM is already installed."
    fi
}

setup_services() {
    log_header "Enabling Services"

    # Bluetooth
    if systemctl list-unit-files | grep -q "bluetooth.service"; then
        log_step "Enabling Bluetooth..."
        sudo systemctl enable --now bluetooth.service
    fi

    # NetworkManager
    if systemctl list-unit-files | grep -q "NetworkManager.service"; then
        log_step "Enabling NetworkManager..."
        sudo systemctl enable --now NetworkManager.service
    fi
}

setup_mimetypes() {
    log_header "Configuring Default Applications (MIME)"

    if command -v dolphin &>/dev/null; then
        log_step "Setting Dolphin as default file manager..."

        # Set Dolphin to open directories
        xdg-mime default org.kde.dolphin.desktop inode/directory

        # Update KDE services database
        if command -v kbuildsycoca6 &>/dev/null; then
            log_step "Updating KDE services cache..."
            kbuildsycoca6 >/dev/null 2>&1
        fi
    else
        log_warn "Dolphin not found. Skipping MIME types configuration."
    fi
}

setup_wallpaper() {
    log_header "Configuring Initial Wallpaper"

    local CURRENT_FILE="$HOME/.local/wallpapers/.current"
    local WALLPAPER
    if [[ -f "$CURRENT_FILE" ]]; then
        WALLPAPER="$(cat "$CURRENT_FILE")"
    fi
    # Fallback to default if .current doesn't exist or points to a missing file
    if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
        WALLPAPER="$HOME/.local/wallpapers/water.png"
    fi

    # Check if swww is installed
    if ! command -v swww &>/dev/null; then
        log_warn "swww is not installed. Skipping wallpaper configuration."
        return 0
    fi

    # Check if the wallpaper exists
    if [[ ! -f "$WALLPAPER" ]]; then
        log_warn "Wallpaper not found: $WALLPAPER"
        return 0
    fi

    # Check if running in a Wayland session
    if [[ -z "$WAYLAND_DISPLAY" ]]; then
        log_warn "Not in a Wayland session."
        log_info "The wallpaper will be applied automatically when Hyprland starts."
        return 0
    fi

    log_step "Starting swww daemon..."
    # Start daemon if not running
    if ! pgrep -f "swww-daemon" &>/dev/null; then
        swww-daemon >/dev/null 2>&1 &
    fi
    sleep 3

    # Check if daemon started
    if ! pgrep -f "swww-daemon" &>/dev/null; then
        log_warn "Could not start swww daemon."
        return 0
    fi

    log_step "Applying wallpaper"
    if swww img "$WALLPAPER" --transition-type grow --transition-duration 2 2>/dev/null; then
        log_info "Wallpaper configured successfully!"
    else
        log_warn "Failed to apply wallpaper."
    fi
}

setup_state_aur_helper() {
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
    local TEMP_FILE
    TEMP_FILE=$(mktemp)
    jq --arg helper "$AUR_HELPER" '.system.aurHelper = $helper' "$STATE_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$STATE_FILE"
    log_info "AUR helper set to: $AUR_HELPER"
}

# =============================================================================
# Full installation
# =============================================================================
full_install() {
    log_header "Starting Full Installation"

    # Check internet and AUR helper now (after selection)
    check_internet
    check_aur_helper

    # Install stow first
    log_step "Installing GNU Stow..."
    sudo pacman -S --needed --noconfirm stow git

    # Install selected packages
    for category in "${CATEGORIES[@]}"; do
        log_header "Installing: ${category^^}"
        install_packages "$category"
    done

    # Run setup scripts
    run_stow
    run_hyprland_setup
    setup_state_aur_helper
    setup_mimetypes

    # Install Tela icons from git (if fonts was selected)
    if [[ " ${CATEGORIES[*]} " =~ " fonts " ]]; then
        log_header "Installing Tela Icon Theme"
        install_tela_icons
    fi

    # Additional setup based on installed categories
    if [[ " ${CATEGORIES[*]} " =~ " terminal " ]]; then
        setup_zsh
        setup_tmux
    fi

    # Enable services
    if [[ " ${CATEGORIES[*]} " =~ " utils " ]]; then
        setup_services
    fi

    # Configure initial wallpaper
    if [[ " ${CATEGORIES[*]} " =~ " core " ]]; then
        setup_wallpaper
    fi

    # Apply GTK theme
    if [[ " ${CATEGORIES[*]} " =~ " theming " ]]; then
        setup_theming
    fi
}

# =============================================================================
# Reboot prompt
# =============================================================================
ask_reboot() {
    echo ""
    echo -ne "${YELLOW}Do you want to reboot the system now to apply all changes? [Y/n]: ${NC}"
    read -r do_reboot

    if [[ $do_reboot =~ ^[Yy]$ ]] || [[ -z "$do_reboot" ]]; then
        log_info "Rebooting..."
        sleep 2
        sudo reboot
    else
        log_info "Remember to reboot the system to apply all changes."
    fi
}

# =============================================================================
# Final summary
# =============================================================================
show_summary() {
    log_header "Installation Complete!"

    echo -e "${GREEN}Installed categories:${NC}"
    for cat in "${CATEGORIES[@]}"; do
        echo "  - $cat"
    done

    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Log out and select 'Hyprland (uwsm)' in your display manager"
    echo "  2. Or start manually with: uwsm start hyprland-uwsm.desktop"
    echo ""
    echo "  3. Configure your monitors with: nwg-displays"
    echo "  4. Workspaces will be configured automatically by workspace-manager"
    echo ""

    if [[ " ${CATEGORIES[*]} " =~ " terminal " ]]; then
        echo "  5. In tmux, use prefix + I to install plugins"
    fi

    if [[ " ${CATEGORIES[*]} " =~ " nvidia " ]]; then
        echo ""
        echo -e "${YELLOW}NVIDIA:${NC}"
        echo "  - Review ~/.config/hypr/local/extra_environment.conf"
        echo "  - For hybrid GPUs, uncomment the AQ_DRM_DEVICES line"
    fi

    echo ""
    log_info "Enjoy your new setup!"
    echo ""
}

# =============================================================================
# Show banner
# =============================================================================
show_banner() {
    echo ""
    echo -e "${CYAN}"
    cat <<'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║   █   █▄█ █▄ █ █▀▀ ▄▄ █▀▄ █▀█ ▀█▀ █▀                          ║
    ║   █▄▄  █  █ ▀█ ██▄    █▄▀ █▄█  █  ▄█                          ║
    ║                                                               ║
    ║   https://github.com/caioax/lyne-dots                         ║
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

    # Check if running on Arch Linux
    check_arch

    # FIRST: Category selection (before any installation)
    get_selection

    echo ""
    log_info "Selected categories: ${CATEGORIES[*]}"
    echo ""
    echo -ne "${YELLOW}Continue with the installation? [Y/n]: ${NC}"
    read -r confirm

    if [[ $confirm =~ ^[Nn]$ ]]; then
        log_info "Installation cancelled."
        exit 0
    fi

    # Run installation (checks and AUR helper here)
    full_install

    # Show summary
    show_summary

    # Prompt for reboot
    ask_reboot
}

# =============================================================================
# Command line arguments
# =============================================================================
case "${1:-}" in
--help | -h)
    echo "Usage: ./install.sh [option]"
    echo ""
    echo "Options:"
    echo "  --help, -h      Show this help"
    echo "  --stow-only     Only run stow (symlinks)"
    echo "  --setup-only    Only run Hyprland setup"
    echo "  --packages PKG  Install only the specified category"
    echo ""
    echo "Available categories:"
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
        log_error "Please specify a category!"
        exit 1
    fi
    install_packages "$2"
    exit 0
    ;;
*)
    main
    ;;
esac
