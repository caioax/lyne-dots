# 047-hybrid-gpu-env.sh - gpus.lua follows the GPU that renders
#
# Hyprland 0.57 turned on quirks:skip_non_kms_dmabuf_formats: with the
# dedicated GPU rendering and no monitor plugged into it (a laptop away from
# its external monitor), apps are offered only formats they can't draw with
# and the desktop never shows. gpus.lua is written again in its new form: on
# laptops a first GPU without a monitor at login gives way to one with one, the
# dedicated GPU first turns the quirk off, and on hybrid laptops it sets
# the NVIDIA variables only when NVIDIA renders. So the copies of those
# variables set for the whole session (local/extra_environment.lua and
# uwsm's env.d/global_hardware.sh, from the NVIDIA templates) are commented
# out on hybrid laptops: they sent every app to NVIDIA even while the
# integrated GPU rendered. Desktops keep them. The GPU order doesn't change.

source "$DOTS_DIR/.install/lib/log.sh"
source "$DOTS_DIR/.data/lyne-cli/lib/gpus.sh"
source "$DOTS_DIR/.data/lyne-cli/lib/gpu-order.sh"

gpu_detect
gpu_links

if ! gpu_multi; then
    echo "   One GPU here: nothing to change"
    return 0
fi

local order=()
mapfile -t order < <(gpu_order_saved)
gpu_lua_write "${order[@]}" || return 1
echo "   local/gpus.lua written again (GPU order kept)"

gpu_hybrid_laptop || return 0

local vars='LIBVA_DRIVER_NAME|__GLX_VENDOR_LIBRARY_NAME|NVD_BACKEND'
local env_file="$GPU_HYPR_DIR/local/extra_environment.lua"
local uwsm_file="$HOME/.config/uwsm/env.d/global_hardware.sh"
local lua_re='^[[:space:]]*hl\.env\([[:space:]]*"('"$vars"')"'
local sh_re='^[[:space:]]*export[[:space:]]+('"$vars"')='

if [[ -f "$env_file" ]] && grep -qE "$lua_re" "$env_file"; then
    sed -i -E 's/^([[:space:]]*)(hl\.env\([[:space:]]*"('"$vars"')")/\1-- Set in local\/gpus.lua now, only when NVIDIA renders: \2/' "$env_file" || return 1
    echo "   NVIDIA variables in local/extra_environment.lua commented out (gpus.lua sets them when NVIDIA renders)"
fi
if [[ -f "$uwsm_file" ]] && grep -qE "$sh_re" "$uwsm_file"; then
    sed -i -E 's/^([[:space:]]*)(export[[:space:]]+('"$vars"')=)/\1# Set in ~\/.config\/hypr\/local\/gpus.lua now, only when NVIDIA renders: \2/' "$uwsm_file" || return 1
    echo "   NVIDIA variables in uwsm env.d/global_hardware.sh commented out"
fi
return 0
