#!/bin/bash
# =============================================================================
# gpus.sh - The graphics cards of this machine
# =============================================================================
# Reads sysfs and pci.ids only (no lspci, no jq): it runs on a fresh Arch
# install before any package, where pciutils (base) brought hwdata's pci.ids.
# Used by install.sh (Graphics question), `lyne gpu`, and later the GPU
# settings. LYNE_SYSFS and LYNE_PCI_IDS point it at test fixtures.
#
#   gpu_detect      fills the GPU_* arrays below (integrated GPUs first)
#   gpu_status      readable list (lyne gpu)
#   gpu_json        the same as JSON
#   gpu_summary     one line: "Intel UHD Graphics + NVIDIA GeForce ... (hybrid)"
#
# Per GPU (same index in every array):
#   GPU_PCI        0000:01:00.0
#   GPU_IDS        10de:1f9d
#   GPU_VENDOR     intel | amd | nvidia | virtual | other
#   GPU_BRAND      Intel | AMD | NVIDIA | ... (for display)
#   GPU_NAME       GeForce GTX 1650 Mobile / Max-Q (the bracketed pci.ids name)
#   GPU_CHIP       TU117M (what comes before it)
#   GPU_KIND       integrated | dedicated | virtual
#   GPU_ARCH       NVIDIA generation: turing, pascal... ("" for others)
#   GPU_FAMILY     NVIDIA driver that supports it: open | 580xx | 470xx | none
#   GPU_DRIVER     kernel driver bound now (i915, nvidia, nouveau, amdgpu...)
#   GPU_BOOT_VGA   1 for the GPU the firmware used at boot
#   GPU_CARD       card1 (changes between boots: never store it)
#   GPU_OUTPUTS    "eDP-1:connected DP-1:disconnected"
# And:
#   GPU_COUNT, GPU_HYBRID (1 = an integrated and a dedicated GPU),
#   GPU_INTERNAL (index of the GPU with the built-in screen, -1 if none),
#   GPU_NVIDIA (index of the first NVIDIA GPU, -1 if none)
#
# Usage: source this file
# =============================================================================

GPU_SYSFS="${LYNE_SYSFS:-/sys}"
GPU_PCI_IDS="${LYNE_PCI_IDS:-/usr/share/hwdata/pci.ids}"

# AMD APUs, by the codename pci.ids gives their GPU
GPU_AMD_APU_RE='^(Wrestler|Sumo|SuperSumo|Trinity|Richland|Kaveri|Godavari|Kabini|Kalindi|Mullins|Beema|Carrizo|Bristol|Stoney|Wani|Raven|Picasso|Dali|Pollock|Renoir|Lucienne|Cezanne|Barcelo|Rembrandt|Mendocino|VanGogh|Van Gogh|Sephiroth|Aerith|Phoenix|HawkPoint|Hawk Point|Raphael|Granite Ridge|Strix|Krackan)'

# Name of a PCI device in pci.ids ("" when unknown or without the file)
_gpu_pci_name() {
    [[ -r "$GPU_PCI_IDS" ]] || return 0
    awk -v V="$1" -v D="$2" '
        index($0, V "  ") == 1 { v = 1; next }
        /^[0-9a-f][0-9a-f][0-9a-f][0-9a-f] / { if (v) exit; next }
        v && index($0, "\t" D "  ") == 1 { print substr($0, 8); exit }
    ' "$GPU_PCI_IDS"
}

# NVIDIA generation from the chip code, or from device id ranges when
# pci.ids doesn't know the card (approximate)
_gpu_nvidia_arch() {
    local chip=$1 id=$((16#$2))
    case "$chip" in
    GB*) echo blackwell ;;
    GH*) echo hopper ;;
    AD*) echo ada ;;
    GA*) echo ampere ;;
    TU*) echo turing ;;
    GV*) echo volta ;;
    GP*) echo pascal ;;
    GM*) echo maxwell ;;
    GK*) echo kepler ;;
    GF*) echo fermi ;;
    G[0-9]* | GT[0-9]* | NV* | MCP* | C[0-9]*) echo tesla ;;
    *)
        if ((id >= 0x2900)); then echo blackwell
        elif ((id >= 0x2600)); then echo ada
        elif ((id >= 0x2300 && id <= 0x233f)); then echo hopper
        elif ((id >= 0x2200 || (id >= 0x2080 && id <= 0x20ff))); then echo ampere
        elif ((id >= 0x1e00)); then echo turing
        elif ((id == 0x1d81 || (id >= 0x1db0 && id <= 0x1dbf))); then echo volta
        elif ((id >= 0x1b00 || (id >= 0x15f0 && id <= 0x15ff))); then echo pascal
        elif ((id >= 0x1340)); then echo maxwell
        elif ((id >= 0x0fc0)); then echo kepler
        else echo fermi
        fi
        ;;
    esac
}

# The driver branch that still supports a generation (Arch, since 590:
# nvidia-open for Turing and newer, nvidia-580xx-dkms in the AUR for
# Maxwell to Volta)
_gpu_nvidia_family() {
    case "$1" in
    turing | ampere | ada | hopper | blackwell) echo open ;;
    maxwell | pascal | volta) echo 580xx ;;
    kepler) echo 470xx ;;
    *) echo none ;;
    esac
}

gpu_driver_note() {
    case "$1" in
    open) echo "supported by nvidia-open (Turing or newer)" ;;
    580xx) echo "needs the legacy nvidia-580xx-dkms from the AUR (Maxwell to Volta)" ;;
    470xx) echo "only nvidia-470xx (AUR), too old for Wayland: nouveau" ;;
    *) echo "no NVIDIA driver supports it anymore: nouveau" ;;
    esac
}

_gpu_arch_label() {
    case "$1" in
    ada) echo "Ada Lovelace" ;;
    *) echo "${1^}" ;;
    esac
}

gpu_detect() {
    GPU_PCI=() GPU_IDS=() GPU_VENDOR=() GPU_BRAND=() GPU_NAME=() GPU_CHIP=()
    GPU_KIND=() GPU_ARCH=() GPU_FAMILY=() GPU_DRIVER=() GPU_BOOT_VGA=()
    GPU_CARD=() GPU_OUTPUTS=()
    GPU_COUNT=0 GPU_HYBRID=0 GPU_INTERNAL=-1 GPU_NVIDIA=-1

    local dev rows=()
    for dev in "$GPU_SYSFS"/bus/pci/devices/*; do
        [[ -r "$dev/class" ]] || continue
        # 0x03xxxx: display controllers (VGA, 3D, other)
        [[ "$(<"$dev/class")" == 0x03* ]] || continue

        local pci vendor device full chip name kind brand vtag arch="" family="" driver=""
        pci="$(basename "$dev")"
        vendor="$(<"$dev/vendor")" device="$(<"$dev/device")"
        vendor="${vendor#0x}" device="${device#0x}"
        full="$(_gpu_pci_name "$vendor" "$device")"
        if [[ "$full" == *"["*"]"* ]]; then
            chip="${full%% \[*}"
            name="${full#*\[}"
            name="${name%\]*}"
        else
            chip="$full" name="$full"
        fi

        case "$vendor" in
        8086)
            vtag=intel brand=Intel kind=integrated
            # Arc cards (DG1, Alchemist, Battlemage); by id, since Meteor
            # Lake's integrated GPU is called Arc too
            local id=$((16#$device))
            if ((id >= 0x4905 && id <= 0x4909)) || ((id >= 0x5690 && id <= 0x56cf)) ||
                ((id >= 0xe200 && id <= 0xe2ff)); then
                kind=dedicated
            fi
            ;;
        1002)
            vtag=amd brand=AMD kind=dedicated
            if [[ "$chip" =~ $GPU_AMD_APU_RE ]]; then
                kind=integrated
            elif [[ -z "$full" && -r "$dev/mem_info_vram_total" ]]; then
                # Unknown to pci.ids: APUs only reserve a little memory
                (($(<"$dev/mem_info_vram_total") <= 1073741824)) && kind=integrated
            fi
            ;;
        10de)
            vtag=nvidia brand=NVIDIA kind=dedicated
            arch="$(_gpu_nvidia_arch "$chip" "$device")"
            family="$(_gpu_nvidia_family "$arch")"
            ;;
        1af4 | 1b36 | 1234 | 15ad | 80ee)
            vtag=virtual brand=Virtual kind=virtual
            ;;
        *)
            vtag=other brand="PCI $vendor" kind=dedicated
            ;;
        esac
        [[ -n "$name" ]] || name="GPU $vendor:$device"
        [[ -L "$dev/driver" ]] && driver="$(basename "$(readlink "$dev/driver")")"

        local card="" outputs="" conn
        for conn in "$dev"/drm/card*; do
            [[ -d "$conn" ]] || continue
            card="$(basename "$conn")"
            break
        done
        if [[ -n "$card" ]]; then
            for conn in "$dev/drm/$card/$card"-*; do
                [[ -r "$conn/status" ]] || continue
                outputs+="${conn##*/"$card"-}:$(<"$conn/status") "
            done
        fi

        local order=2
        [[ "$kind" == integrated ]] && order=1
        [[ "$kind" == virtual ]] && order=3
        # One line per GPU, sorted below; "|" never appears in these values
        rows+=("$order $pci|$pci|$vendor:$device|$vtag|$brand|$name|$chip|$kind|$arch|$family|$driver|$(cat "$dev/boot_vga" 2>/dev/null || echo 0)|$card|${outputs% }")
    done

    local i=0 integrated=0 dedicated=0 _pci
    while IFS='|' read -r _ "GPU_PCI[i]" "GPU_IDS[i]" "GPU_VENDOR[i]" "GPU_BRAND[i]" "GPU_NAME[i]" "GPU_CHIP[i]" \
        "GPU_KIND[i]" "GPU_ARCH[i]" "GPU_FAMILY[i]" "GPU_DRIVER[i]" "GPU_BOOT_VGA[i]" "GPU_CARD[i]" "GPU_OUTPUTS[i]"; do
        [[ "${GPU_KIND[i]}" == integrated ]] && integrated=1
        [[ "${GPU_KIND[i]}" == dedicated ]] && dedicated=1
        ((GPU_NVIDIA < 0)) && [[ "${GPU_VENDOR[i]}" == nvidia ]] && GPU_NVIDIA=$i
        i=$((i + 1))
    done < <(((${#rows[@]})) && printf '%s\n' "${rows[@]}" | sort)
    GPU_COUNT=$i

    # The built-in screen: a connected eDP/LVDS/DSI output, or any of them
    # (some desktop boards list an eDP that's never connected)
    local pattern
    for pattern in ':connected' ':'; do
        for ((i = 0; i < GPU_COUNT; i++)); do
            if [[ " ${GPU_OUTPUTS[i]}" =~ \ (eDP|LVDS|DSI)-[^\ :]*$pattern ]]; then
                GPU_INTERNAL=$i
                break 2
            fi
        done
    done
    ((integrated && dedicated)) && GPU_HYBRID=1
    return 0
}

# "integrated", "dedicated, Turing"
gpu_kind_label() {
    local i=$1 label=${GPU_KIND[$1]}
    [[ -n "${GPU_ARCH[i]}" ]] && label+=", $(_gpu_arch_label "${GPU_ARCH[i]}")"
    printf '%s' "$label"
}

# The connected outputs: "eDP-1 HDMI-A-1"
gpu_connected() {
    local out list=()
    for out in ${GPU_OUTPUTS[$1]}; do
        [[ "$out" == *:connected ]] && list+=("${out%:*}")
    done
    printf '%s' "${list[*]}"
}

# What kind of machine: "hybrid laptop", "one GPU"...
gpu_setup_label() {
    if ((GPU_COUNT == 0)); then
        echo "no graphics card found"
    elif ((GPU_HYBRID)); then
        if ((GPU_INTERNAL >= 0)); then
            echo "hybrid: the built-in screen is on the ${GPU_BRAND[GPU_INTERNAL]} GPU"
        else
            echo "hybrid: an integrated and a dedicated GPU"
        fi
    elif ((GPU_COUNT == 1)); then
        echo "one GPU"
    else
        echo "$GPU_COUNT GPUs"
    fi
}

gpu_summary() {
    local i parts=()
    for ((i = 0; i < GPU_COUNT; i++)); do
        parts+=("${GPU_BRAND[i]} ${GPU_NAME[i]}")
    done
    if ((GPU_COUNT == 0)); then
        echo "none found"
        return
    fi
    local IFS='+'
    local joined="${parts[*]}"
    printf '%s' "${joined//+/ + }"
    ((GPU_HYBRID)) && printf ' (hybrid)'
    printf '\n'
}

gpu_status() {
    local i
    echo "Graphics: $(gpu_setup_label)"
    for ((i = 0; i < GPU_COUNT; i++)); do
        echo ""
        printf '  %d  %-7s %s\n' $((i + 1)) "${GPU_BRAND[i]}" "${GPU_NAME[i]}"
        local info="$(gpu_kind_label "$i")"
        [[ -n "${GPU_CHIP[i]}" && "${GPU_CHIP[i]}" != "${GPU_NAME[i]}" ]] && info+=" (${GPU_CHIP[i]})"
        info+=" · ${GPU_PCI[i]} · ${GPU_IDS[i]} · driver ${GPU_DRIVER[i]:-none}"
        [[ -n "${GPU_CARD[i]}" ]] && info+=" · ${GPU_CARD[i]}"
        echo "     $info"
        if [[ -n "${GPU_OUTPUTS[i]}" ]]; then
            local out outs=()
            for out in ${GPU_OUTPUTS[i]}; do
                if [[ "$out" == *:connected ]]; then outs+=("${out%:*} (on)"); else outs+=("${out%:*}"); fi
            done
            echo "     outputs: ${outs[*]}"
        fi
        [[ -n "${GPU_FAMILY[i]}" ]] && echo "     $(gpu_driver_note "${GPU_FAMILY[i]}")"
    done
    return 0
}

_gpu_json_str() {
    local s=${1//\\/\\\\}
    s=${s//\"/\\\"}
    printf '"%s"' "$s"
}

gpu_json() {
    local i out first
    printf '{"hybrid":%s,"internal":%d,"gpus":[' "$( ((GPU_HYBRID)) && echo true || echo false)" "$GPU_INTERNAL"
    for ((i = 0; i < GPU_COUNT; i++)); do
        ((i)) && printf ','
        printf '{"pci":%s,"ids":%s,"vendor":%s,"brand":%s,"name":%s,"chip":%s,"kind":%s,"arch":%s,"family":%s,"driver":%s,"bootVga":%s,"card":%s,"outputs":[' \
            "$(_gpu_json_str "${GPU_PCI[i]}")" "$(_gpu_json_str "${GPU_IDS[i]}")" \
            "$(_gpu_json_str "${GPU_VENDOR[i]}")" "$(_gpu_json_str "${GPU_BRAND[i]}")" \
            "$(_gpu_json_str "${GPU_NAME[i]}")" "$(_gpu_json_str "${GPU_CHIP[i]}")" \
            "$(_gpu_json_str "${GPU_KIND[i]}")" "$(_gpu_json_str "${GPU_ARCH[i]}")" \
            "$(_gpu_json_str "${GPU_FAMILY[i]}")" "$(_gpu_json_str "${GPU_DRIVER[i]}")" \
            "$([[ "${GPU_BOOT_VGA[i]}" == 1 ]] && echo true || echo false)" \
            "$(_gpu_json_str "${GPU_CARD[i]}")"
        first=1
        for out in ${GPU_OUTPUTS[i]}; do
            ((first)) || printf ','
            first=0
            printf '{"name":%s,"connected":%s}' "$(_gpu_json_str "${out%:*}")" \
                "$([[ "$out" == *:connected ]] && echo true || echo false)"
        done
        printf ']}'
    done
    printf ']}\n'
}
