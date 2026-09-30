# lyne gpu - The graphics cards of this machine and the order Hyprland uses

local subcmd="${1:-status}"

source "$DOTS_DIR/.install/lib/log.sh"
source "$DOTS_DIR/.data/lyne-cli/lib/gpus.sh"
source "$DOTS_DIR/.data/lyne-cli/lib/gpu-order.sh"

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne gpu [status|--json|order <which>|links]"
        echo ""
        echo "Lists the GPUs found in sysfs: integrated or dedicated, the NVIDIA"
        echo "generation and the driver branch that supports it, the kernel driver in"
        echo "use and the outputs of each GPU. With more than one GPU, each gets a"
        echo "stable /dev/dri link (/dev/dri/intel-igpu, nvidia-dgpu...) and Hyprland"
        echo "uses them in the order saved here (AQ_DRM_DEVICES, from"
        echo "~/.config/hypr/local/gpus.lua): the first renders, the ones left out"
        echo "aren't used. A new order applies at the next login."
        echo ""
        echo "Subcommands:"
        echo "  status        Readable list, links and order (default)"
        echo "  --json        The GPUs as JSON"
        echo "  order auto    Let Hyprland pick (the GPU with the built-in screen first)"
        echo "  order igpu    Integrated GPU renders, the dedicated one is still used"
        echo "  order dgpu    Dedicated GPU renders, the integrated one is still used"
        echo "  order only-igpu | only-dgpu"
        echo "                Only that GPU (monitors on the other one stay dark)"
        echo "  order <pci>...  Explicit order by PCI address (see status)"
        echo "  links         Write the udev rules for the links (sudo), e.g. after"
        echo "                changing GPUs"
        ;;
    status)
        gpu_detect
        gpu_links
        gpu_status
        if gpu_multi; then
            echo ""
            local i pci order=() missing=()
            mapfile -t order < <(gpu_order_saved)
            if ((${#order[@]} == 0)); then
                echo "Order: automatic (the GPU with the built-in screen renders)"
            else
                echo "Order (next login; first renders):"
                local n=1
                for pci in "${order[@]}"; do
                    if i="$(_gpu_index_of_pci "$pci")"; then
                        echo "  $n. ${GPU_BRAND[i]} ${GPU_NAME[i]} (/dev/dri/${GPU_LINK[i]})"
                    else
                        echo "  $n. $pci (not found)"
                    fi
                    n=$((n + 1))
                done
            fi
            local running=() names=()
            mapfile -t running < <(gpu_running_order)
            if ((${#running[@]})); then
                for pci in "${running[@]}"; do
                    i="$(_gpu_index_of_pci "$pci")" && names+=("${GPU_LINK[i]}")
                done
                echo "In use now: ${names[*]}$(gpu_running_explicit || echo " (automatic)")"
            fi
            echo ""
            for ((i = 0; i < GPU_COUNT; i++)); do
                [[ -n "${GPU_LINK[i]}" ]] || continue
                if [[ ! -e "/dev/dri/${GPU_LINK[i]}" ]]; then
                    missing+=("${GPU_LINK[i]}")
                fi
                # A monitor on a GPU left out of the order stays dark
                if ((${#order[@]})) && [[ " ${order[*]} " != *" ${GPU_PCI[i]} "* && -n "$(gpu_connected "$i")" ]]; then
                    echo "  ! $(gpu_connected "$i") is plugged into the ${GPU_BRAND[i]} GPU, which isn't in the order"
                fi
            done
            if [[ ! -f "$GPU_RULES" ]]; then
                echo "  ! No GPU links yet: lyne gpu links"
            elif [[ "$(cat "$GPU_RULES")" != "$(gpu_rules_content)" ]]; then
                echo "  ! The GPUs changed since the links were made: lyne gpu links"
            elif ((${#missing[@]})); then
                echo "  ! /dev/dri/${missing[*]} missing (rules not loaded yet? reboot or lyne gpu links)"
            fi
            local dup
            for dup in $(gpu_rules_duplicates); do
                echo "  ! $dup makes the same links (lyne gpu links removes it)"
            done
            local other
            other="$(grep -lE '^[[:space:]]*hl\.env\([[:space:]]*"AQ_DRM_DEVICES"' "$GPU_HYPR_DIR"/local/*.lua 2>/dev/null | grep -v '/gpus.lua$')"
            [[ -n "$other" ]] && echo "  ! $other also sets AQ_DRM_DEVICES: the order here may not apply"
        fi
        return 0
        ;;
    --json|json)
        gpu_detect
        gpu_json
        ;;
    order)
        shift
        gpu_detect
        gpu_links
        if ! gpu_multi; then
            echo "lyne gpu: only one GPU here, nothing to order"
            return 1
        fi
        if [[ $# -eq 0 ]]; then
            echo "Usage: lyne gpu order auto|igpu|dgpu|only-igpu|only-dgpu|<pci>..."
            return 1
        fi
        local order=() resolved
        resolved="$(gpu_order_resolve "$@")" || return 1
        [[ -n "$resolved" ]] && mapfile -t order <<<"$resolved"
        gpu_order_write "${order[@]}" || { echo "lyne gpu: could not write $GPU_LUA"; return 1; }
        if ((${#order[@]})); then
            local pci i names=()
            for pci in "${order[@]}"; do
                i="$(_gpu_index_of_pci "$pci")" && names+=("${GPU_LINK[i]}")
            done
            echo "GPU order: ${names[*]} (applies at the next login)"
        else
            echo "GPU order: automatic (applies at the next login)"
        fi
        [[ -f "$GPU_RULES" ]] || echo "No GPU links yet: run lyne gpu links"
        ;;
    links)
        gpu_detect
        gpu_links
        if ! gpu_multi; then
            echo "lyne gpu: only one GPU here, no links needed"
            return 0
        fi
        sudo -v || return 1
        gpu_rules_install
        local dup
        for dup in $(gpu_rules_duplicates); do
            log_step "Removing $dup (makes the same links)"
            sudo rm -f "$dup"
        done
        ;;
    *)
        echo "lyne gpu: unknown subcommand '$subcmd'"
        echo "Run 'lyne gpu --help' for usage information."
        return 1
        ;;
esac
