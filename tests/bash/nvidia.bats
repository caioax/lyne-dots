#!/usr/bin/env bats
# lib/nvidia.sh: the driver plan, applying it (stand-ins only) and the status

load helpers

setup() {
    lyne_setup
    SYS="$BATS_TEST_TMPDIR/sys"
    ETC="$BATS_TEST_TMPDIR/etc"
    export LYNE_SYSFS="$SYS" LYNE_PCI_IDS="$FIXTURES/pci.ids"
    export LYNE_PACMAN_CONF="$ETC/pacman.conf" LYNE_MKINITCPIO_CONF="$ETC/mkinitcpio.conf"
    export LYNE_MKINITCPIO_DIR="$ETC/mkinitcpio.conf.d" LYNE_MKINITCPIO_PRESETS="$ETC/mkinitcpio.d"
    export LYNE_MODULES_DIR="$BATS_TEST_TMPDIR/modules"
    mkdir -p "$ETC/mkinitcpio.d" "$LYNE_MODULES_DIR/6.17.1-arch1-1" "$LYNE_MODULES_DIR/6.12.50-1-lts"
    echo linux >"$LYNE_MODULES_DIR/6.17.1-arch1-1/pkgbase"
    echo linux-lts >"$LYNE_MODULES_DIR/6.12.50-1-lts/pkgbase"
    printf '[options]\nHoldPkg = pacman glibc\n\n[core]\nInclude = /etc/pacman.d/mirrorlist\n\n#[multilib]\n#Include = /etc/pacman.d/mirrorlist\n' >"$LYNE_PACMAN_CONF"
    printf 'MODULES=()\nHOOKS=(base udev autodetect kms modconf block filesystems)\n' >"$LYNE_MKINITCPIO_CONF"
    echo 'PRESETS=(default)' >"$ETC/mkinitcpio.d/linux.preset"
}

laptop() {
    fx_gpu "$SYS" 0000:01:00.0 "10de:${1:-1f9d}" driver=nvidia card=card0
    fx_gpu "$SYS" 0000:00:02.0 8086:3e9b driver="${2-i915}" card=card1 outputs="eDP-1:connected"
}

desktop() { fx_gpu "$SYS" 0000:01:00.0 "10de:$1" driver=nouveau card=card0; }

# nv CODE [MULTILIB]: detect, plan, then CODE
nv() { in_lyne gpus nvidia -- "gpu_detect; nvidia_plan ${2:-0}; $1"; }

plan='echo "action=$NV_ACTION family=$NV_FAMILY current=$NV_CURRENT"; echo "remove=${NV_REMOVE[*]}"; echo "repo=${NV_REPO[*]}"; echo "aur=${NV_AUR[*]}"; echo "services=${NV_SERVICES[*]}"; echo "multilib=$NV_MULTILIB enable=$NV_ENABLE_MULTILIB igpu=$NV_IGPU_MODULE dropin=$NV_DROPIN_CHANGE"'

@test "no NVIDIA GPU: nothing to do" {
    fx_gpu "$SYS" 0000:00:02.0 8086:3e9b
    run nv "$plan; nvidia_plan_lines"
    assert_line --partial "action=none"
    assert_line "No NVIDIA GPU."
}

@test "Turing laptop, nothing installed: nvidia-open, headers of every kernel, prime, i915 early" {
    laptop
    run nv "$plan"
    assert_success
    assert_line "action=install family=open current="
    assert_line "remove="
    assert_line "repo=linux-headers linux-lts-headers nvidia-open-dkms nvidia-utils libva-nvidia-driver nvidia-prime"
    assert_line "aur="
    assert_line "services="
    assert_line "multilib=0 enable=0 igpu=i915 dropin=1"
    run nv 'nvidia_plan_lines'
    assert_line "Install: linux-headers linux-lts-headers nvidia-open-dkms nvidia-utils libva-nvidia-driver nvidia-prime"
    assert_line "Write $LYNE_MKINITCPIO_DIR/lyne-nvidia.conf (no kms hook, i915 early) and rebuild the initramfs"
}

@test "multilib: enabled on request, lib32 utils whenever it's on" {
    laptop
    run nv "$plan" 1
    assert_line --partial "repo=linux-headers linux-lts-headers nvidia-open-dkms nvidia-utils lib32-nvidia-utils"
    assert_line "multilib=1 enable=1 igpu=i915 dropin=1"
    sed -i 's/^#\[multilib\]/[multilib]/' "$LYNE_PACMAN_CONF"
    run nv "$plan"
    assert_line --partial "lib32-nvidia-utils"
    assert_line "multilib=1 enable=0 igpu=i915 dropin=1"
}

@test "Pascal desktop on nvidia-open: replaced by the 580xx AUR driver with suspend units" {
    desktop 1c03
    pkgs nvidia-open-dkms nvidia-utils linux-headers
    run nv "$plan"
    assert_line "action=replace family=580xx current=nvidia-open-dkms"
    assert_line "remove=nvidia-open-dkms nvidia-utils"
    assert_line "repo=linux-headers linux-lts-headers dkms libva-nvidia-driver"
    assert_line "aur=nvidia-580xx-dkms nvidia-580xx-utils"
    assert_line "services=nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service"
    # No integrated GPU: the drop-in only drops kms
    assert_line "multilib=0 enable=0 igpu= dropin=1"
    run nv 'nvidia_plan_lines'
    assert_line "Remove the open driver: nvidia-open-dkms nvidia-utils"
    assert_line "Install: linux-lts-headers dkms libva-nvidia-driver"
    assert_line "Install from the AUR: nvidia-580xx-dkms nvidia-580xx-utils"
}

@test "Kepler: unsupported, nouveau" {
    desktop 1004
    run nv "$plan; nvidia_plan_lines"
    assert_line --partial "action=unsupported family=470xx"
    assert_line "GeForce GTX 780 (kepler): only nvidia-470xx (AUR), too old for Wayland: nouveau."
}

@test "integrated GPU module: the bound driver, else the vendor's usual one" {
    laptop 1f9d xe
    run nv 'echo "$NV_IGPU_MODULE"'
    assert_output xe
    rm -rf "$SYS"
    laptop 1f9d vfio-pci
    run nv 'echo "$NV_IGPU_MODULE"'
    assert_output i915
    rm -rf "$SYS"
    fx_gpu "$SYS" 0000:01:00.0 10de:2882
    fx_gpu "$SYS" 0000:05:00.0 1002:15bf
    run nv 'echo "$NV_IGPU_MODULE"'
    assert_output amdgpu
}

@test "the drop-in, sourced like mkinitcpio does, drops kms and adds the iGPU module" {
    laptop
    run nv '_nv_dropin_content "$NV_IGPU_MODULE" >"$BATS_TEST_TMPDIR/dropin.conf"'
    run bash -c 'source "$1"; source "$2"; echo "HOOKS=${HOOKS[*]}"; echo "MODULES=${MODULES[*]}"; declare -p _lyne_hooks 2>/dev/null || echo clean' _ "$LYNE_MKINITCPIO_CONF" "$BATS_TEST_TMPDIR/dropin.conf"
    assert_line "HOOKS=base udev autodetect modconf block filesystems"
    assert_line "MODULES=i915"
    assert_line clean
}

@test "everything set up: nothing to change" {
    laptop
    pkgs linux-headers linux-lts-headers nvidia-open-dkms nvidia-utils libva-nvidia-driver nvidia-prime
    mkdir -p "$LYNE_MKINITCPIO_DIR"
    run nv '_nv_dropin_content i915 >"$NV_DROPIN"'
    run nv "$plan; nvidia_plan_lines; nvidia_plan_lines_changes || echo no-changes"
    assert_line "action=ok family=open current=nvidia-open-dkms"
    assert_line "multilib=0 enable=0 igpu=i915 dropin=0"
    assert_line "Nothing to change: nvidia-open-dkms is set up."
    assert_line no-changes
}

@test "apply: multilib, packages, drop-in and initramfs, in that order" {
    laptop
    pkgs linux-headers
    run nv 'nvidia_apply' 1
    assert_success
    assert_line --partial "Reboot to load it"
    grep -qx '\[multilib\]' "$LYNE_PACMAN_CONF"
    grep -qx 'Include = /etc/pacman.d/mirrorlist' <(sed -n '/^\[multilib\]/{n;p}' "$LYNE_PACMAN_CONF")
    grep -q '^MODULES+=(i915)$' "$LYNE_MKINITCPIO_DIR/lyne-nvidia.conf"
    run grep -E '^(pacman -S|pacman -Syu|mkinitcpio)' "$STUB_LOG"
    assert_line --index 0 "pacman -Syu --noconfirm"
    assert_line --index 1 "pacman -S --needed --noconfirm linux-lts-headers nvidia-open-dkms nvidia-utils lib32-nvidia-utils libva-nvidia-driver nvidia-prime"
    assert_line --index 2 "mkinitcpio -P"
    # Every package and system change went through sudo
    run grep -cE '^sudo ' "$STUB_LOG"
    assert_output 6
}

@test "apply: the 580xx driver needs an AUR helper; with one, suspend units get enabled" {
    desktop 1c03
    run nv 'nvidia_apply'
    assert_failure
    assert_output --partial "An AUR helper (yay or paru) is needed for nvidia-580xx-dkms nvidia-580xx-utils"
    refute [ -e "$LYNE_MKINITCPIO_DIR/lyne-nvidia.conf" ]
    : >"$STUB_LOG"
    run nv 'AUR_HELPER=yay nvidia_apply'
    assert_success
    run cat "$STUB_LOG"
    assert_line "yay -S --needed --noconfirm nvidia-580xx-dkms nvidia-580xx-utils"
    assert_line "systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service"
}

@test "apply: replacing removes the old branch with -Rdd" {
    desktop 1c03
    pkgs nvidia-open-dkms nvidia-utils nvidia-settings
    run nv 'AUR_HELPER=yay nvidia_apply'
    assert_success
    run cat "$STUB_LOG"
    assert_line "pacman -Rdd --noconfirm nvidia-open-dkms nvidia-utils nvidia-settings"
}

@test "status: notes on what's off" {
    laptop
    pkgs linux-headers nvidia-open-dkms=595.45-1
    echo nvidia-suspend.service >>"$FAKE_ENABLED"
    printf 'MODULES=(nvidia nvidia_drm)\n' >"$LYNE_MKINITCPIO_CONF"
    echo 'default_config="/etc/mkinitcpio-custom.conf"' >"$ETC/mkinitcpio.d/linux.preset"
    run nv 'nvidia_status'
    assert_success
    assert_line --partial "Driver     nvidia-open-dkms 595.45-1"
    assert_line "  ! linux-lts-headers is missing: DKMS can't build the driver for linux-lts"
    assert_line --partial "! nvidia-suspend are enabled: not needed with 595+ drivers"
    assert_line "  ! $ETC/mkinitcpio.d/linux.preset sets its own config, so mkinitcpio skips the drop-ins in $LYNE_MKINITCPIO_DIR"
    assert_line "  ! $LYNE_MKINITCPIO_CONF loads the NVIDIA modules early (MODULES): hibernation won't work"
    assert_line "  ! Not everything is set up (lyne nvidia install shows what's missing)"
}
