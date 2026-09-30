# 029-gpu-links.sh - Stable GPU links and a managed GPU order
#
# On machines with more than one GPU, /etc/udev/rules.d/90-lyne-gpus.rules
# gives each GPU a /dev/dri link by PCI address (intel-igpu, nvidia-dgpu...)
# and ~/.config/hypr/local/gpus.lua sets AQ_DRM_DEVICES from the order in
# state.json (lyne gpu order). An AQ_DRM_DEVICES set by hand in
# local/extra_environment.lua or uwsm's env.d/hyprland_hardware.sh becomes
# that order and its line is commented out, so the GPUs Hyprland uses don't
# change. Hand-written rules that only make the same links are removed.
# Needs sudo (the rules live in /etc).

source "$DOTS_DIR/.install/lib/log.sh"
source "$DOTS_DIR/.data/lyne-cli/lib/gpus.sh"
source "$DOTS_DIR/.data/lyne-cli/lib/gpu-order.sh"

gpu_detect
gpu_links

if ! gpu_multi; then
    echo "   One GPU here: no GPU links needed"
    return 0
fi

local env_file="$GPU_HYPR_DIR/local/extra_environment.lua"
local uwsm_file="$HOME/.config/uwsm/env.d/hyprland_hardware.sh"
local lua_re='^[[:space:]]*hl\.env\([[:space:]]*"AQ_DRM_DEVICES"[[:space:]]*,[[:space:]]*"([^"]*)"'
local sh_re='^[[:space:]]*export[[:space:]]+AQ_DRM_DEVICES=["'"'"']?([^"'"'"' ]*)'

# The order set by hand (Hyprland's file wins over uwsm's: it's set later),
# read while the old links still resolve
local aq="" line
while IFS= read -r line; do
    [[ "$line" =~ $sh_re ]] && aq=${BASH_REMATCH[1]}
done < <(cat "$uwsm_file" 2>/dev/null)
while IFS= read -r line; do
    [[ "$line" =~ $lua_re ]] && aq=${BASH_REMATCH[1]}
done < <(cat "$env_file" 2>/dev/null)

local order=() saved=()
mapfile -t saved < <(gpu_order_saved)
if ((${#saved[@]})); then
    order=("${saved[@]}")
elif [[ -n "$aq" ]]; then
    local pci
    while read -r pci; do
        _gpu_index_of_pci "$pci" >/dev/null && order+=("$pci")
    done < <(gpu_order_from_aq "$aq")
    if ((${#order[@]} == 0)); then
        echo "   AQ_DRM_DEVICES=$aq doesn't point at any GPU now: the order is automatic (lyne gpu order)"
    fi
fi

gpu_rules_install
[[ $? -eq 2 ]] && return 1
local dup
for dup in $(gpu_rules_duplicates); do
    echo "   Removing $dup (it makes the same link)"
    sudo rm -f "$dup" || return 1
done

gpu_order_write "${order[@]}" || return 1

# The hand-written lines would set it again after gpus.lua
if [[ -f "$env_file" ]] && grep -qE "$lua_re" "$env_file"; then
    sed -i -E 's/^([[:space:]]*)(hl\.env\([[:space:]]*"AQ_DRM_DEVICES")/\1-- Set in local\/gpus.lua now (lyne gpu order): \2/' "$env_file"
    echo "   AQ_DRM_DEVICES moved from local/extra_environment.lua to local/gpus.lua"
fi
if [[ -f "$uwsm_file" ]] && grep -qE "$sh_re" "$uwsm_file"; then
    sed -i -E 's/^([[:space:]]*)(export[[:space:]]+AQ_DRM_DEVICES=)/\1# Set in ~\/.config\/hypr\/local\/gpus.lua now (lyne gpu order): \2/' "$uwsm_file"
    echo "   AQ_DRM_DEVICES moved from uwsm env.d/hyprland_hardware.sh to hypr/local/gpus.lua"
fi

if ((${#order[@]})); then
    local names=() i
    for pci in "${order[@]}"; do
        i="$(_gpu_index_of_pci "$pci")" && names+=("${GPU_LINK[i]}")
    done
    echo "   GPU order: ${names[*]} (lyne gpu order changes it)"
else
    echo "   GPU order: automatic (lyne gpu order changes it)"
fi
return 0
