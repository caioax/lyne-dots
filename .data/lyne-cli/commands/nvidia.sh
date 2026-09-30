# lyne nvidia - NVIDIA driver status and setup

local subcmd="${1:-status}"

source "$DOTS_DIR/.install/lib/log.sh"
source "$DOTS_DIR/.data/lyne-cli/lib/gpus.sh"
source "$DOTS_DIR/.data/lyne-cli/lib/nvidia.sh"

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne nvidia [status|install]"
        echo ""
        echo "The driver that supports the NVIDIA GPU found (nvidia-open for Turing and"
        echo "newer, nvidia-580xx from the AUR for Maxwell to Volta, nouveau for older"
        echo "cards), the headers of every kernel, and an initramfs drop-in"
        echo "(/etc/mkinitcpio.conf.d/lyne-nvidia.conf) without the kms hook."
        echo ""
        echo "Subcommands:"
        echo "  status    GPU, driver, kernels and what's off (default)"
        echo "  install   Show the changes, ask, then install or fix the driver (sudo)"
        ;;
    status)
        gpu_detect
        nvidia_plan 0
        nvidia_status
        ;;
    install)
        gpu_detect
        nvidia_plan 0
        case "$NV_ACTION" in
            none|unsupported)
                nvidia_plan_lines
                return 0
                ;;
        esac

        local answer
        if ! nv_multilib_on; then
            read -rp "Enable multilib for the 32-bit driver (Steam, Wine)? It edits /etc/pacman.conf and runs pacman -Syu [y/N] " answer
            [[ "$answer" =~ ^[Yy]$ ]] && nvidia_plan 1
        fi

        if ! nvidia_plan_lines_changes; then
            nvidia_plan_lines
            return 0
        fi
        echo "Changes:"
        nvidia_plan_lines | sed 's/^/  - /'
        echo ""
        read -rp "Apply them? [y/N] " answer
        [[ "$answer" =~ ^[Yy]$ ]] || { echo "Nothing changed."; return 0; }

        local AUR_HELPER
        AUR_HELPER="$(jq -r '.system.aurHelper // empty' "$DOTS_DIR/quickshell/.config/quickshell/state.json" 2>/dev/null)"
        command -v "$AUR_HELPER" &>/dev/null || AUR_HELPER=""
        [[ -n "$AUR_HELPER" ]] || AUR_HELPER="$(command -v yay || command -v paru)"
        AUR_HELPER="${AUR_HELPER##*/}"

        sudo -v || return 1
        nvidia_apply || return 1
        if ! grep -qs 'LIBVA_DRIVER_NAME' "$HOME/.config/hypr/local/extra_environment.lua"; then
            echo ""
            echo "Hyprland doesn't have the NVIDIA variables yet: copy"
            echo "  $DOTS_DIR/.data/hyprland/templates/extra_environment_nvidia.lua"
            echo "to ~/.config/hypr/local/extra_environment.lua"
        fi
        ;;
    *)
        echo "lyne nvidia: unknown subcommand '$subcmd'"
        echo "Run 'lyne nvidia --help' for usage information."
        return 1
        ;;
esac
