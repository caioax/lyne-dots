#!/bin/bash
# =============================================================================
# gpu-order.sh - Stable GPU paths and the order Hyprland uses them in
# =============================================================================
# Card numbers (/dev/dri/card0) change between boots, and AQ_DRM_DEVICES
# can't hold /dev/dri/by-path names (":" separates its entries). So on
# machines with more than one GPU:
#   /etc/udev/rules.d/90-lyne-gpus.rules  one symlink per GPU by PCI address:
#                                         /dev/dri/intel-igpu, nvidia-dgpu...
#   state.json gpus.order                 PCI addresses, first = renders
#                                         Hyprland ([] = automatic)
#   ~/.config/hypr/local/gpus.lua         generated from it: sets
#                                         AQ_DRM_DEVICES when Hyprland starts
# GPUs left out of the order aren't used at all (monitors plugged into them
# stay dark). Without AQ_DRM_DEVICES Aquamarine puts the GPU with the
# built-in screen first.
#
#   gpu_links                  GPU_LINK[i]: the /dev/dri name of each GPU
#   gpu_multi                  0 when there are 2+ real GPUs
#   gpu_rules_content          the rules file
#   gpu_rules_install          writes it (sudo) and reloads udev when changed
#   gpu_rules_duplicates       other rules files that only make our links
#   gpu_order_resolve <spec>   auto|igpu|dgpu|only-igpu|only-dgpu|<pci>... →
#                              PCI addresses (none = automatic); errors on
#                              stderr, so the output is only addresses
#   gpu_order_from_aq <value>  an AQ_DRM_DEVICES value → PCI addresses
#   gpu_lua_content <pci>...   the gpus.lua for an order
#   gpu_lua_write <pci>...     gpus.lua for an order (atomic)
#   gpu_order_write <pci>...   state.json + gpus.lua
#   gpu_order_saved            the order in state.json
#   gpu_running_order          the order the running Hyprland uses
#
# LYNE_UDEV_DIR, LYNE_HYPR_DIR and LYNE_STATE_FILE point it at test files.
# Usage: source gpus.sh and log.sh, run gpu_detect, then use these
# =============================================================================

GPU_UDEV_DIR="${LYNE_UDEV_DIR:-/etc/udev/rules.d}"
GPU_RULES="$GPU_UDEV_DIR/90-lyne-gpus.rules"
GPU_HYPR_DIR="${LYNE_HYPR_DIR:-$HOME/.config/hypr}"
GPU_LUA="$GPU_HYPR_DIR/local/gpus.lua"
GPU_STATE="${LYNE_STATE_FILE:-$HOME/.config/quickshell/state.json}"

# lyne_state_set
source "${BASH_SOURCE[0]%/*}/state.sh"

# shellcheck disable=SC2153 # GPU_KIND and the other GPU_* arrays come from gpus.sh
gpu_links() {
    GPU_LINK=()
    local i name n
    local -A used=()
    for ((i = 0; i < GPU_COUNT; i++)); do
        [[ "${GPU_KIND[i]}" == virtual ]] && { GPU_LINK[i]=""; continue; }
        case "${GPU_VENDOR[i]}" in
        intel | amd | nvidia) name=${GPU_VENDOR[i]} ;;
        *) name=gpu ;;
        esac
        [[ "${GPU_KIND[i]}" == integrated ]] && name+=-igpu || name+=-dgpu
        # Two of the same kind: nvidia-dgpu, nvidia-dgpu-2
        local link=$name
        n=1
        while [[ -n "${used[$link]:-}" ]]; do
            n=$((n + 1))
            link="$name-$n"
        done
        used[$link]=1
        GPU_LINK[i]=$link
    done
}

gpu_multi() {
    local i real=0
    for ((i = 0; i < GPU_COUNT; i++)); do
        [[ "${GPU_KIND[i]}" == virtual ]] || real=$((real + 1))
    done
    ((real >= 2))
}

_gpu_index_of_pci() {
    local i
    for ((i = 0; i < GPU_COUNT; i++)); do
        [[ "${GPU_PCI[i]}" == "$1" ]] && { echo "$i"; return 0; }
    done
    return 1
}

gpu_rules_content() {
    local i
    echo "# GPU links by PCI address, managed by lyne-dots (lyne gpu links)."
    echo "# /dev/dri/card* numbers change between boots; these names don't."
    for ((i = 0; i < GPU_COUNT; i++)); do
        [[ -n "${GPU_LINK[i]}" ]] || continue
        echo "# ${GPU_BRAND[i]} ${GPU_NAME[i]}"
        printf 'KERNEL=="card*", KERNELS=="%s", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/%s"\n' \
            "${GPU_PCI[i]}" "${GPU_LINK[i]}"
    done
}

# 0 when the rules file changed (and udev was told)
gpu_rules_install() {
    local content
    content="$(gpu_rules_content)"
    if [[ "$(cat "$GPU_RULES" 2>/dev/null)" == "$content" ]]; then
        log_info "GPU links already set up ($GPU_RULES)"
        return 1
    fi
    log_step "Writing $GPU_RULES..."
    printf '%s\n' "$content" | sudo tee "$GPU_RULES" >/dev/null || return 2
    # Only DRM devices: the links appear now, nothing else is touched
    sudo udevadm control --reload
    sudo udevadm trigger --subsystem-match=drm
    log_info "GPU links: $(for ((i = 0; i < GPU_COUNT; i++)); do [[ -n "${GPU_LINK[i]}" ]] && printf '/dev/dri/%s ' "${GPU_LINK[i]}"; done)"
    return 0
}

# Rules files (other than ours) whose every rule makes one of our links for
# the same GPU: left over from setting it up by hand
gpu_rules_duplicates() {
    local file line pci link i dup
    for file in "$GPU_UDEV_DIR"/*.rules; do
        [[ -f "$file" && "$file" != "$GPU_RULES" ]] || continue
        dup=0
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
            # Continuation lines (the wiki's example) joined
            while [[ "$line" == *\\ ]] && IFS= read -r next; do
                line="${line%\\}$next"
            done
            pci="" link=""
            [[ "$line" =~ KERNELS==\"([^\"]+)\" ]] && pci=${BASH_REMATCH[1]}
            [[ "$line" =~ SYMLINK\+=\"dri/([^\"]+)\" ]] && link=${BASH_REMATCH[1]}
            if [[ -n "$pci" && -n "$link" ]] && i="$(_gpu_index_of_pci "$pci")" &&
                [[ "${GPU_LINK[i]}" == "$link" ]]; then
                dup=1
            else
                dup=0
                break
            fi
        done <"$file"
        ((dup)) && echo "$file"
    done
    return 0
}

# gpu_order_resolve <spec>...
gpu_order_resolve() {
    local spec=${1:-auto} i out=()
    case "$spec" in
    auto) return 0 ;;
    igpu | dgpu | only-igpu | only-dgpu)
        local first=integrated
        [[ "$spec" == *dgpu ]] && first=dedicated
        for ((i = 0; i < GPU_COUNT; i++)); do
            [[ "${GPU_KIND[i]}" == "$first" && -n "${GPU_LINK[i]}" ]] && out+=("${GPU_PCI[i]}")
        done
        if [[ "$spec" == only-* ]]; then
            ((${#out[@]})) && out=("${out[0]}")
        else
            for ((i = 0; i < GPU_COUNT; i++)); do
                [[ "${GPU_KIND[i]}" != "$first" && -n "${GPU_LINK[i]}" ]] && out+=("${GPU_PCI[i]}")
            done
        fi
        ;;
    *)
        local pci
        for pci in "$@"; do
            i="$(_gpu_index_of_pci "$pci")" && [[ -n "${GPU_LINK[i]}" ]] || {
                log_error "No GPU at $pci" >&2
                return 1
            }
            out+=("$pci")
        done
        ;;
    esac
    ((${#out[@]})) || { log_error "No GPU for '$spec'" >&2; return 1; }
    printf '%s\n' "${out[@]}"
}

# "/dev/dri/nvidia-dgpu:/dev/dri/card1" → PCI addresses, through the links
# and the card's device in sysfs
gpu_order_from_aq() {
    local path card dev IFS=':'
    for path in $1; do
        [[ -n "$path" ]] || continue
        card="$(readlink -e "$path" 2>/dev/null)" || continue
        card="${card##*/}"
        dev="$(readlink -e "$GPU_SYSFS/class/drm/$card/device" 2>/dev/null)" || continue
        echo "${dev##*/}"
    done
}

gpu_lua_content() {
    local pci i paths=() label
    for pci in "$@"; do
        i="$(_gpu_index_of_pci "$pci")" || continue
        paths+=("\"/dev/dri/${GPU_LINK[i]}\", -- ${GPU_BRAND[i]} ${GPU_NAME[i]}")
    done
    label="${*:-automatic}"
    cat <<EOF
-- GPUs: managed by lyne (lyne gpu order). Read when Hyprland starts: a new
-- order applies at the next login. The first GPU renders; GPUs left out
-- aren't used (monitors plugged into them stay dark). The paths come from
-- /etc/udev/rules.d/90-lyne-gpus.rules.
EOF
    if ((${#paths[@]} == 0)); then
        printf '\n-- Automatic: Aquamarine picks (the GPU with the built-in screen first)\n'
    else
        printf '\nlocal order = {\n'
        printf '    %s\n' "${paths[@]}"
        cat <<'EOF'
}

-- Only the ones present now: a GPU turned off in the firmware or a missing
-- udev rule would otherwise leave Aquamarine without any GPU. (popen: the
-- status of os.execute is lost, Hyprland reaps its children)
local present = order
local probe = io.popen("for d in " .. table.concat(order, " ") .. "; do [ -e \"$d\" ] && echo \"$d\"; done")
if probe then
    local found = {}
    for line in probe:read("a"):gmatch("[^\n]+") do
        found[line] = true
    end
    probe:close()
    present = {}
    for _, path in ipairs(order) do
        if found[path] then
            present[#present + 1] = path
        end
    end
end
if #present > 0 then
    hl.env("AQ_DRM_DEVICES", table.concat(present, ":"))
end
EOF
    fi
    printf '\nlyne_gpus_file = "%s"\n' "$label"
}

# This session's Hyprland log ("" without one)
_gpu_hypr_log() {
    local log="${LYNE_HYPR_LOG:-}"
    if [[ -z "$log" && -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        log="${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log"
    fi
    [[ -r "$log" ]] && echo "$log"
}

# The GPUs the running Hyprland uses, in its order (first renders): the DRM
# backends Aquamarine started, from this session's log. Card numbers there
# belong to this boot, so sysfs still maps them. Nothing without a log
gpu_running_order() {
    local log card dev
    local -A seen=()
    log="$(_gpu_hypr_log)" || return 0
    while read -r card; do
        [[ -n "${seen[$card]:-}" ]] && continue
        seen[$card]=1
        dev="$(readlink -e "$GPU_SYSFS/class/drm/$card/device" 2>/dev/null)" || continue
        echo "${dev##*/}"
    done < <(grep -oE 'drm: Starting backend for /dev/dri/card[0-9]+' "$log" | grep -oE 'card[0-9]+$')
}

# 0 when the running Hyprland got an explicit list (AQ_DRM_DEVICES)
gpu_running_explicit() {
    local log
    log="$(_gpu_hypr_log)" && grep -q 'drm: Explicit device list' "$log"
}

gpu_order_saved() {
    command -v jq &>/dev/null || return 0
    jq -r '(.gpus.order // [])[]' "$GPU_STATE" 2>/dev/null
}

# gpus.lua alone (Quickshell keeps state.json itself)
gpu_lua_write() {
    mkdir -p "$GPU_HYPR_DIR/local"
    # Temp file outside local/ (Hyprland loads every local/*.lua), then one
    # move: Hyprland reloads on the write and must not see half a file
    local tmp
    tmp="$(mktemp "$GPU_HYPR_DIR/.gpus.lua.XXXXXX")" || return 1
    # shellcheck disable=SC2015 # the cleanup runs when any step fails
    gpu_lua_content "$@" >"$tmp" && chmod 644 "$tmp" && mv "$tmp" "$GPU_LUA" || {
        rm -f "$tmp"
        return 1
    }
}

gpu_order_write() {
    gpu_lua_write "$@" || return 1
    if [[ -f "$GPU_STATE" ]] && command -v jq &>/dev/null; then
        LYNE_STATE_FILE="$GPU_STATE" lyne_state_set '.gpus.order = $ARGS.positional' --args "$@"
    fi
    return 0
}
