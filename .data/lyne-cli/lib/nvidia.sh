#!/bin/bash
# =============================================================================
# nvidia.sh - NVIDIA driver: what's installed, what should be, and applying it
# =============================================================================
# Follows the Arch wiki (NVIDIA, NVIDIA/Tips and tricks) as of the 590+
# drivers:
#   Turing and newer    nvidia-open-dkms + nvidia-utils (extra)
#   Maxwell to Volta    nvidia-580xx-dkms + nvidia-580xx-utils (AUR)
#   Kepler and older    nothing: nouveau (no driver worth using on Wayland)
# plus the headers of every installed kernel (DKMS builds for each),
# libva-nvidia-driver, nvidia-prime on hybrid machines and, with multilib,
# the lib32 utils. modeset and fbdev are on by default. The 595+ drivers keep
# video memory across suspend with kernel notifiers, so the
# nvidia-suspend/hibernate/resume services are only enabled for 580xx.
#
# The initramfs gets a drop-in (/etc/mkinitcpio.conf.d/lyne-nvidia.conf)
# instead of edits to mkinitcpio.conf: it drops the kms hook, which would put
# nouveau in the initramfs, and loads the integrated GPU's driver early in
# its place. The NVIDIA modules are NOT loaded early: that breaks
# hibernation. Deleting the file and running `mkinitcpio -P` undoes it.
#
#   nvidia_plan [multilib]  fills the NV_* values below (multilib: 1 = enable
#                           the repo for the lib32 packages when it's off)
#   nvidia_plan_lines       the changes, one per line (review, lyne nvidia)
#   nvidia_apply            makes them (needs sudo; AUR_HELPER for 580xx)
#   nvidia_status           readable state with what's off (lyne nvidia)
#
# LYNE_PACMAN_CONF, LYNE_MKINITCPIO_CONF, LYNE_MKINITCPIO_DIR and
# LYNE_MODULES_DIR point it at test files.
# Usage: source gpus.sh and log.sh, then this file
# =============================================================================

NV_PACMAN_CONF="${LYNE_PACMAN_CONF:-/etc/pacman.conf}"
NV_MKINITCPIO_CONF="${LYNE_MKINITCPIO_CONF:-/etc/mkinitcpio.conf}"
NV_MKINITCPIO_DIR="${LYNE_MKINITCPIO_DIR:-/etc/mkinitcpio.conf.d}"
NV_DROPIN="$NV_MKINITCPIO_DIR/lyne-nvidia.conf"
NV_MODULES_DIR="${LYNE_MODULES_DIR:-/usr/lib/modules}"

# Kernel module packages of each branch (old names included: they're what an
# older install may have)
NV_MODULE_PKGS=(nvidia-open-dkms nvidia-open nvidia-open-lts nvidia-dkms nvidia nvidia-lts
    nvidia-580xx-dkms nvidia-470xx-dkms nvidia-390xx-dkms)
NV_SUSPEND_UNITS=(nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service)

_nv_branch_of() {
    case "$1" in
    nvidia-580xx-*) echo 580xx ;;
    nvidia-470xx-*) echo 470xx ;;
    nvidia-390xx-*) echo 390xx ;;
    *) echo open ;;
    esac
}

# Everything of a branch that goes when switching to another one
_nv_branch_pkgs() {
    case "$1" in
    open) echo "${NV_MODULE_PKGS[*]:0:6} nvidia-utils lib32-nvidia-utils opencl-nvidia lib32-opencl-nvidia nvidia-settings" ;;
    *) echo "nvidia-$1-dkms nvidia-$1-utils lib32-nvidia-$1-utils opencl-nvidia-$1 lib32-opencl-nvidia-$1 nvidia-$1-settings" ;;
    esac
}

_nv_installed() { pacman -Qq "$1" &>/dev/null; }

_nv_version() { pacman -Q "$1" 2>/dev/null | awk '{ print $2 }'; }

# Presets that pass their own config (-c) make mkinitcpio skip the drop-ins
nv_presets_skipping_dropins() {
    grep -lE '^[[:space:]]*[A-Za-z_]*_config=' "${LYNE_MKINITCPIO_PRESETS:-/etc/mkinitcpio.d}"/*.preset 2>/dev/null
}

nv_multilib_on() { grep -qE '^\[multilib\]' "$NV_PACMAN_CONF" 2>/dev/null; }

# Kernel packages, from the pkgbase file each one installs
nv_kernels() {
    local f
    for f in "$NV_MODULES_DIR"/*/pkgbase; do
        [[ -r "$f" ]] && cat "$f"
    done | sort -u
}

# The drop-in for the initramfs (igpu module or "")
_nv_dropin_content() {
    cat <<'EOF'
# NVIDIA driver, managed by lyne-dots (lyne nvidia). Deleting this file and
# running `sudo mkinitcpio -P` undoes it.

# Without the kms hook the initramfs doesn't carry nouveau
_lyne_hooks=()
for _lyne_hook in "${HOOKS[@]}"; do
    [[ "$_lyne_hook" == kms ]] || _lyne_hooks+=("$_lyne_hook")
done
HOOKS=("${_lyne_hooks[@]}")
unset _lyne_hooks _lyne_hook
EOF
    if [[ -n "$1" ]]; then
        printf '\n# The integrated GPU still starts early (the kms hook did that). The\n'
        printf '# NVIDIA modules are left out on purpose: loading them early breaks\n'
        printf '# hibernation\nMODULES+=(%s)\n' "$1"
    fi
}

nvidia_plan() {
    local want_multilib=${1:-0} i
    NV_ACTION=none NV_GPU=-1 NV_FAMILY="" NV_ARCH="" NV_CURRENT="" NV_CURRENT_BRANCH=""
    NV_REMOVE=() NV_REPO=() NV_AUR=() NV_HEADERS=() NV_SERVICES=()
    NV_MULTILIB=0 NV_ENABLE_MULTILIB=0 NV_IGPU_MODULE="" NV_DROPIN_CHANGE=0

    ((GPU_NVIDIA >= 0)) || return 0
    NV_GPU=$GPU_NVIDIA
    NV_FAMILY=${GPU_FAMILY[NV_GPU]} NV_ARCH=${GPU_ARCH[NV_GPU]}

    local pkg
    for pkg in "${NV_MODULE_PKGS[@]}"; do
        if _nv_installed "$pkg"; then
            NV_CURRENT=$pkg NV_CURRENT_BRANCH="$(_nv_branch_of "$pkg")"
            break
        fi
    done

    case "$NV_FAMILY" in
    open | 580xx) ;;
    *)
        NV_ACTION=unsupported
        return 0
        ;;
    esac

    if [[ -z "$NV_CURRENT" ]]; then
        NV_ACTION=install
    elif [[ "$NV_CURRENT_BRANCH" == "$NV_FAMILY" ]]; then
        NV_ACTION=ok
    else
        NV_ACTION=replace
        for pkg in $(_nv_branch_pkgs "$NV_CURRENT_BRANCH"); do
            _nv_installed "$pkg" && NV_REMOVE+=("$pkg")
        done
    fi

    nv_multilib_on && NV_MULTILIB=1
    if ((!NV_MULTILIB && want_multilib)); then
        NV_ENABLE_MULTILIB=1 NV_MULTILIB=1
    fi

    local kernel
    while read -r kernel; do
        [[ -n "$kernel" ]] && NV_HEADERS+=("$kernel-headers")
    done < <(nv_kernels)

    NV_REPO=("${NV_HEADERS[@]}")
    if [[ "$NV_FAMILY" == open ]]; then
        NV_REPO+=(nvidia-open-dkms nvidia-utils)
        ((NV_MULTILIB)) && NV_REPO+=(lib32-nvidia-utils)
    else
        # dkms first: the AUR helper builds against the headers above
        NV_REPO+=(dkms)
        NV_AUR=(nvidia-580xx-dkms nvidia-580xx-utils)
        ((NV_MULTILIB)) && NV_AUR+=(lib32-nvidia-580xx-utils)
        NV_SERVICES=("${NV_SUSPEND_UNITS[@]}")
    fi
    NV_REPO+=(libva-nvidia-driver)
    ((GPU_HYBRID)) && NV_REPO+=(nvidia-prime)

    # The integrated GPU's driver (the one bound now, or its usual one)
    for ((i = 0; i < GPU_COUNT; i++)); do
        [[ "${GPU_KIND[i]}" == integrated ]] || continue
        NV_IGPU_MODULE=${GPU_DRIVER[i]}
        case "$NV_IGPU_MODULE" in
        i915 | xe | amdgpu | radeon) ;;
        *) [[ "${GPU_VENDOR[i]}" == amd ]] && NV_IGPU_MODULE=amdgpu || NV_IGPU_MODULE=i915 ;;
        esac
        break
    done
    if [[ "$(cat "$NV_DROPIN" 2>/dev/null)" != "$(_nv_dropin_content "$NV_IGPU_MODULE")" ]]; then
        NV_DROPIN_CHANGE=1
    fi
    return 0
}

# Packages of a list that aren't installed yet
_nv_missing() {
    local pkg
    for pkg in "$@"; do
        _nv_installed "$pkg" || echo "$pkg"
    done
}

nvidia_plan_lines() {
    local missing
    case "$NV_ACTION" in
    none)
        echo "No NVIDIA GPU."
        return
        ;;
    unsupported)
        echo "${GPU_NAME[NV_GPU]} ($NV_ARCH): $(gpu_driver_note "$NV_FAMILY")."
        return
        ;;
    esac
    ((NV_ENABLE_MULTILIB)) && echo "Enable the multilib repository in $NV_PACMAN_CONF (full sync: pacman -Syu)"
    ((${#NV_REMOVE[@]})) && echo "Remove the $NV_CURRENT_BRANCH driver: ${NV_REMOVE[*]}"
    missing="$(_nv_missing "${NV_REPO[@]}" | xargs)"
    [[ -n "$missing" ]] && echo "Install: $missing"
    missing="$(_nv_missing "${NV_AUR[@]}" | xargs)"
    [[ -n "$missing" ]] && echo "Install from the AUR: $missing"
    ((NV_DROPIN_CHANGE)) && echo "Write $NV_DROPIN (no kms hook${NV_IGPU_MODULE:+, $NV_IGPU_MODULE early}) and rebuild the initramfs"
    ((${#NV_SERVICES[@]})) && echo "Enable ${NV_SERVICES[*]}"
    if [[ "$NV_ACTION" == ok ]] && ! nvidia_plan_lines_changes; then
        echo "Nothing to change: $NV_CURRENT is set up."
    fi
}

# 0 when applying would change something
nvidia_plan_lines_changes() {
    ((NV_ENABLE_MULTILIB || ${#NV_REMOVE[@]} || NV_DROPIN_CHANGE)) && return 0
    [[ -n "$(_nv_missing "${NV_REPO[@]}" "${NV_AUR[@]}")" ]] && return 0
    local unit
    for unit in "${NV_SERVICES[@]}"; do
        [[ "$(systemctl is-enabled "$unit" 2>/dev/null)" == enabled ]] || return 0
    done
    return 1
}

nvidia_apply() {
    case "$NV_ACTION" in
    none | unsupported)
        log_info "$(nvidia_plan_lines)"
        return 0
        ;;
    esac
    local rebuild=0 missing

    if ((NV_ENABLE_MULTILIB)); then
        log_step "Enabling the multilib repository..."
        sudo sed -i '/^#[[:space:]]*\[multilib\]/{s/^#[[:space:]]*//;n;s/^#[[:space:]]*//}' "$NV_PACMAN_CONF" || return 1
        if ! grep -qE '^\[multilib\]' "$NV_PACMAN_CONF" && [[ -z "${LYNE_DRY_RUN:-}" ]]; then
            log_error "Could not enable multilib in $NV_PACMAN_CONF"
            return 1
        fi
        # A sync without the upgrade would leave a partial upgrade
        sudo pacman -Syu --noconfirm || return 1
    fi

    if ((${#NV_REMOVE[@]})); then
        log_step "Removing the $NV_CURRENT_BRANCH driver (${NV_REMOVE[*]})..."
        sudo pacman -Rdd --noconfirm "${NV_REMOVE[@]}" || return 1
        rebuild=1
    fi

    missing="$(_nv_missing "${NV_REPO[@]}" | xargs)"
    if [[ -n "$missing" ]]; then
        log_step "Installing $missing..."
        # shellcheck disable=SC2086
        sudo pacman -S --needed --noconfirm $missing || {
            log_error "Could not install the NVIDIA packages"
            return 1
        }
        rebuild=1
    fi

    missing="$(_nv_missing "${NV_AUR[@]}" | xargs)"
    if [[ -n "$missing" ]]; then
        if [[ -z "${AUR_HELPER:-}" ]]; then
            log_error "An AUR helper (yay or paru) is needed for $missing"
            return 1
        fi
        log_step "Installing $missing from the AUR..."
        # shellcheck disable=SC2086
        $AUR_HELPER -S --needed --noconfirm $missing || {
            log_error "Could not install $missing"
            return 1
        }
        rebuild=1
    fi

    if ((NV_DROPIN_CHANGE)); then
        log_step "Writing $NV_DROPIN..."
        sudo mkdir -p "$NV_MKINITCPIO_DIR" &&
            _nv_dropin_content "$NV_IGPU_MODULE" | sudo tee "$NV_DROPIN" >/dev/null || return 1
        rebuild=1
    fi

    if ((NV_DROPIN_CHANGE)); then
        local preset
        for preset in $(nv_presets_skipping_dropins); do
            log_warn "$preset sets its own config: mkinitcpio ignores $NV_DROPIN for it"
        done
    fi

    if ((rebuild)); then
        log_step "Rebuilding the initramfs..."
        sudo mkinitcpio -P || {
            log_error "mkinitcpio failed: check it before rebooting"
            return 1
        }
    fi

    if ((${#NV_SERVICES[@]})); then
        log_step "Enabling ${NV_SERVICES[*]}..."
        sudo systemctl enable "${NV_SERVICES[@]}" || log_warn "Could not enable the suspend services"
    fi

    if ((rebuild)); then
        log_info "NVIDIA driver set up. Reboot to load it."
    else
        log_info "NVIDIA driver already set up."
    fi
}

# Readable state, and what's off from the plan above
nvidia_status() {
    local notes=()
    echo "NVIDIA"
    if ((NV_GPU < 0)); then
        echo "  No NVIDIA GPU found."
        return 0
    fi
    printf '  %-10s %s (%s)\n' GPU "${GPU_NAME[NV_GPU]}" "$(_gpu_arch_label "$NV_ARCH")"
    printf '  %-10s %s\n' Branch "$(gpu_driver_note "$NV_FAMILY")"

    local driver="none (nouveau)" loaded=""
    if [[ -n "$NV_CURRENT" ]]; then
        driver="$NV_CURRENT $(_nv_version "$NV_CURRENT")"
    fi
    [[ -r /sys/module/nvidia/version ]] && loaded="$(</sys/module/nvidia/version)"
    printf '  %-10s %s%s\n' Driver "$driver" "${loaded:+, loaded $loaded}"
    printf '  %-10s %s\n' "In use" "${GPU_DRIVER[NV_GPU]:-nothing}"

    local kernel headers=()
    while read -r kernel; do
        [[ -z "$kernel" ]] && continue
        if _nv_installed "$kernel-headers"; then headers+=("$kernel (headers)"); else
            headers+=("$kernel (NO headers)")
            notes+=("$kernel-headers is missing: DKMS can't build the driver for $kernel")
        fi
    done < <(nv_kernels)
    printf '  %-10s %s\n' Kernels "${headers[*]:-?}"

    if nv_multilib_on; then
        printf '  %-10s %s\n' "32-bit" "multilib on"
    else
        printf '  %-10s %s\n' "32-bit" "multilib off (no lib32 driver for Steam/Wine)"
    fi

    if [[ -f "$NV_DROPIN" ]]; then
        printf '  %-10s %s\n' initramfs "$NV_DROPIN"
    else
        printf '  %-10s %s\n' initramfs "no lyne drop-in"
    fi
    local modeset fbdev
    modeset="$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null)"
    fbdev="$(cat /sys/module/nvidia_drm/parameters/fbdev 2>/dev/null)"
    [[ -n "$modeset" ]] && printf '  %-10s modeset %s, fbdev %s\n' DRM "$modeset" "${fbdev:-?}"

    # What's off
    case "$NV_ACTION" in
    install) notes+=("The driver isn't installed: lyne nvidia install") ;;
    replace) notes+=("$NV_CURRENT doesn't support this GPU anymore: lyne nvidia install switches to the $NV_FAMILY driver") ;;
    esac
    if [[ -n "$loaded" && -n "$NV_CURRENT" ]]; then
        local utils
        utils="$(pacman -Qqs '^nvidia(-[0-9]+xx)?-utils$' 2>/dev/null | head -n1)"
        local installed_ver
        installed_ver="$(_nv_version "$utils")"
        installed_ver="${installed_ver%-*}"
        [[ -n "$installed_ver" && "$installed_ver" != "$loaded" ]] &&
            notes+=("Driver $installed_ver is installed but $loaded is loaded: reboot")
    fi
    if [[ "$NV_FAMILY" == open ]]; then
        local enabled=() unit
        for unit in "${NV_SUSPEND_UNITS[@]}"; do
            [[ "$(systemctl is-enabled "$unit" 2>/dev/null)" == enabled ]] && enabled+=("${unit%.service}")
        done
        ((${#enabled[@]})) && notes+=("${enabled[*]} are enabled: not needed with 595+ drivers (kernel suspend notifiers); sudo systemctl disable ${enabled[*]}")
    fi
    local preset
    for preset in $(nv_presets_skipping_dropins); do
        notes+=("$preset sets its own config, so mkinitcpio skips the drop-ins in $NV_MKINITCPIO_DIR")
    done
    if grep -qE '^MODULES=.*nvidia' "$NV_MKINITCPIO_CONF" 2>/dev/null; then
        notes+=("$NV_MKINITCPIO_CONF loads the NVIDIA modules early (MODULES): hibernation won't work")
    fi
    if [[ "$NV_ACTION" == ok || "$NV_ACTION" == install || "$NV_ACTION" == replace ]] && nvidia_plan_lines_changes; then
        [[ "$NV_ACTION" == ok ]] && notes+=("Not everything is set up (lyne nvidia install shows what's missing)")
    fi

    if ((${#notes[@]})); then
        echo ""
        local note
        for note in "${notes[@]}"; do
            echo "  ! $note"
        done
    fi
    return 0
}
