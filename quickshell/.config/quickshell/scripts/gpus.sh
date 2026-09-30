#!/usr/bin/env bash
# GPUs for Settings › Hyprland › Graphics (GpuService), from the lyne libs
# (.data/lyne-cli/lib/gpus.sh, gpu-order.sh, nvidia.sh).
#
#   gpus.sh json            GPUs, links, the order in use and the NVIDIA
#                           driver state, as one JSON object
#   gpus.sh write <pci>...  ~/.config/hypr/local/gpus.lua for that order (none
#                           = automatic). state.json is written by Quickshell
#
# Changing the udev rules or the driver needs sudo: the page opens
# `lyne gpu links` / `lyne nvidia install` in a terminal instead.

set -uo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
DOTS_DIR="$(cd "$(dirname "$SELF")/../../../.." && pwd)"

source "$DOTS_DIR/.install/lib/log.sh"
source "$DOTS_DIR/.data/lyne-cli/lib/gpus.sh"
source "$DOTS_DIR/.data/lyne-cli/lib/gpu-order.sh"
source "$DOTS_DIR/.data/lyne-cli/lib/nvidia.sh"

# JSON array of strings from the arguments
_array() {
    if (($#)); then printf '%s\n' "$@" | jq -R . | jq -sc .; else echo '[]'; fi
}

json() {
    gpu_detect
    gpu_links
    local i links=() present=() running=()

    for ((i = 0; i < GPU_COUNT; i++)); do
        links+=("${GPU_LINK[i]}")
        if [[ -n "${GPU_LINK[i]}" && -e "/dev/dri/${GPU_LINK[i]}" ]]; then present+=(true); else present+=(false); fi
    done
    mapfile -t running < <(gpu_running_order)

    local rules=none
    if gpu_multi; then
        if [[ ! -f "$GPU_RULES" ]]; then
            rules=missing
        elif [[ "$(cat "$GPU_RULES")" != "$(gpu_rules_content)" ]]; then
            rules=changed
        else
            rules=ok
        fi
    fi
    local duplicates=() others=()
    mapfile -t duplicates < <(gpu_rules_duplicates)
    mapfile -t others < <(grep -lE '^[[:space:]]*hl\.env\([[:space:]]*"AQ_DRM_DEVICES"' "$GPU_HYPR_DIR"/local/*.lua 2>/dev/null | grep -v '/gpus.lua$')

    # The order the saved gpus.lua was written for
    local lua_order=""
    lua_order="$(sed -nE 's/^lyne_gpus_file = "(.*)"$/\1/p' "$GPU_LUA" 2>/dev/null)"

    # NVIDIA: what lyne nvidia status says
    nvidia_plan 0
    local nv='null'
    if ((NV_GPU >= 0)); then
        local notes=() version="" loaded="" changes=false
        mapfile -t notes < <(nvidia_status | sed -n 's/^  ! //p')
        [[ -n "$NV_CURRENT" ]] && version="$(_nv_version "$NV_CURRENT")"
        [[ -r /sys/module/nvidia/version ]] && loaded="$(</sys/module/nvidia/version)"
        nvidia_plan_lines_changes && changes=true
        nv="$(jq -nc --arg action "$NV_ACTION" --arg family "$NV_FAMILY" --arg arch "$NV_ARCH" \
            --arg current "$NV_CURRENT" --arg version "$version" --arg loaded "$loaded" \
            --arg note "$(gpu_driver_note "$NV_FAMILY")" --argjson changes "$changes" \
            --argjson notes "$(_array "${notes[@]}")" --argjson gpu "$NV_GPU" \
            '{gpu: $gpu, action: $action, family: $family, arch: $arch, current: $current,
              version: $version, loaded: $loaded, note: $note, changes: $changes, notes: $notes}')"
    fi

    gpu_json | jq -c \
        --argjson links "$(_array "${links[@]}")" \
        --argjson present "$(printf '%s\n' "${present[@]}" | jq -sc . 2>/dev/null || echo '[]')" \
        --argjson running "$(_array "${running[@]}")" \
        --argjson explicit "$(gpu_running_explicit && echo true || echo false)" \
        --argjson multi "$(gpu_multi && echo true || echo false)" \
        --arg rules "$rules" --arg rulesPath "$GPU_RULES" \
        --argjson duplicates "$(_array "${duplicates[@]}")" \
        --argjson others "$(_array "${others[@]}")" \
        --arg luaOrder "$lua_order" \
        --argjson nvidia "$nv" '
        .gpus |= [to_entries[] | .value + {link: $links[.key], present: ($present[.key] // false)}]
        | . + {multi: $multi, running: $running, runningExplicit: $explicit,
               rules: $rules, rulesPath: $rulesPath, duplicates: $duplicates,
               otherAq: $others, luaOrder: $luaOrder, nvidia: $nvidia}'
}

case "${1:-}" in
json) json ;;
write)
    shift
    gpu_detect
    gpu_links
    gpu_lua_write "$@"
    ;;
*)
    echo "usage: gpus.sh json | write <pci>..." >&2
    exit 1
    ;;
esac
