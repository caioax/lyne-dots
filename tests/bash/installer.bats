#!/usr/bin/env bats
# install.sh --dry-run: the whole install, unattended (--answers), with the
# installer's own stand-ins (a throwaway HOME, sudo/pacman/yay/stow/systemctl
# only logged) and a fake sysfs, so the result doesn't depend on this machine

load helpers

setup() {
    lyne_setup
    SYS="$BATS_TEST_TMPDIR/sys"
    DRY="$BATS_TEST_TMPDIR/dry"
    export LYNE_SYSFS="$SYS" LYNE_PCI_IDS="$FIXTURES/pci.ids" LYNE_MODULES_DIR="$BATS_TEST_TMPDIR/modules"
    export LYNE_DRY_HOME="$DRY" LYNE_DRY_FRESH=1 LYNE_DRY_DELAY=0
    export LYNE_PP_POWER_SUPPLY="$BATS_TEST_TMPDIR/power_supply" LYNE_PP_BUS_NAMES="" LYNE_PP_COMMANDS=""
    mkdir -p "$LYNE_MODULES_DIR/6.17.1-arch1-1" "$LYNE_PP_POWER_SUPPLY"
    echo linux >"$LYNE_MODULES_DIR/6.17.1-arch1-1/pkgbase"
    # This machine's pacman.conf and mkinitcpio files stay out of it
    local etc="$BATS_TEST_TMPDIR/etc"
    mkdir -p "$etc/mkinitcpio.d"
    printf '[core]\nInclude = /etc/pacman.d/mirrorlist\n\n#[multilib]\n#Include = /etc/pacman.d/mirrorlist\n' >"$etc/pacman.conf"
    printf 'MODULES=()\nHOOKS=(base udev kms block)\n' >"$etc/mkinitcpio.conf"
    export LYNE_PACMAN_CONF="$etc/pacman.conf" LYNE_MKINITCPIO_CONF="$etc/mkinitcpio.conf"
    export LYNE_MKINITCPIO_DIR="$etc/mkinitcpio.conf.d" LYNE_MKINITCPIO_PRESETS="$etc/mkinitcpio.d"
    ANSWERS="$BATS_TEST_TMPDIR/answers"
    # shellcheck disable=SC2034 # read by repo_unchanged
    REPO_STATUS="$(git -C "$REPO" status --porcelain)"
}

teardown() { repo_unchanged; }

hybrid() {
    fx_gpu "$SYS" 0000:01:00.0 10de:1f9d driver=nvidia card=card0 outputs="HDMI-A-1:connected"
    fx_gpu "$SYS" 0000:00:02.0 8086:3e9b driver=i915 card=card1 outputs="eDP-1:connected"
}

answers() { printf '%s\n' "$@" >"$ANSWERS"; }
install() { "$REPO/install.sh" --dry-run "$@"; }
log() { cat "$DRY"/.cache/lyne/install-*.log; }

@test "hybrid laptop: every step, packages by category, NVIDIA driver, GPU order" {
    hybrid
    answers "categories=core terminal utils fonts quickshell theming" "gpu_order=igpu" "reboot=no"
    run install --answers "$ANSWERS"
    assert_success
    refute_output --partial "[fail]"
    assert_line "[ok] Packages · quickshell"
    assert_line "[ok] NVIDIA driver"
    assert_line "[ok] GPU links and order"
    assert_line "[ok] Lyne CLI"
    run log
    assert_line --partial "[dry-run] yay -S --needed --noconfirm quickshell-git"
    assert_line "[dry-run] sudo pacman -S --needed --noconfirm linux-headers nvidia-open-dkms nvidia-utils libva-nvidia-driver nvidia-prime"
    assert_line --partial "[dry-run] sudo mkinitcpio -P"
    assert_line --partial "[dry-run] stow -d $REPO -t $DRY -R quickshell"
    # Not asked for
    refute_line --partial "Packages · editor"
    # The first login opens the welcome screen; settings from the answers
    local state="$DRY/.config/quickshell/state.json"
    assert_equal "$(jq -c '[.welcome.pending, .system.aurHelper, .gpus.order]' "$state")" '[true,"yay",["0000:00:02.0","0000:01:00.0"]]'
    grep -q '"/dev/dri/intel-igpu",' "$DRY/.config/hypr/local/gpus.lua"
}

@test "multilib asked for: enabled with a full sync, lib32 driver" {
    hybrid
    answers "categories=core" "nvidia=driver" "multilib=yes" "reboot=no"
    run install --answers "$ANSWERS"
    assert_success
    run log
    assert_line --partial "[dry-run] sudo pacman -Syu --noconfirm"
    assert_line --partial "lib32-nvidia-utils"
    refute_line --partial "pacman -Sy --noconfirm"
}

@test "no NVIDIA GPU: no driver step, no GPU order on one GPU" {
    fx_gpu "$SYS" 0000:03:00.0 1002:73ff driver=amdgpu card=card0 outputs="DP-1:connected"
    answers "categories=core" "reboot=no"
    run install --answers "$ANSWERS"
    assert_success
    refute_line --partial "NVIDIA driver"
    run log
    refute_line --partial "nvidia-open-dkms"
    refute_line --partial "90-lyne-gpus.rules"
}

@test "a failing package stops the install: summary, exit 1, never a reboot" {
    hybrid
    answers "categories=core terminal" "nvidia=none" "reboot=yes"
    LYNE_DRY_FAIL=pacman run install --answers "$ANSWERS"
    assert_failure
    assert_output --partial "[fail]"
    assert_output --partial "didn't run. Run ./install.sh again to finish."
    refute_output --partial "Rebooting"
    refute_output --partial "Enjoy your new setup"
    run log
    assert_line --partial "made to fail"
}

@test "--packages installs one category only" {
    hybrid
    run install --packages terminal
    assert_success
    assert_line --partial "[dry-run] sudo pacman -S --needed --noconfirm kitty zsh tmux fastfetch"
    refute_line --partial "hyprland uwsm"
}

@test "bad flags and missing answers file fail before anything runs" {
    run "$REPO/install.sh" --nope
    assert_failure
    assert_output --partial "Unknown option: --nope"
    run "$REPO/install.sh" --dry-run --answers "$BATS_TEST_TMPDIR/none"
    assert_failure
    assert_output --partial "Answers file not found"
    refute [ -e "$DRY" ]
}

@test "the dry run never reaches the real sudo" {
    hybrid
    answers "categories=core" "reboot=no"
    run install --answers "$ANSWERS"
    assert_success
    # Every sudo call went through the dry-run stand-in (logged), none to ours
    run grep -c '^sudo ' "$STUB_LOG"
    assert_output 0
    run log
    assert_line --partial "[dry-run] sudo"
}

@test "the sudo keepalive leaves nothing running" {
    hybrid
    answers "categories=core" "reboot=no"
    RUN_SUDO_KEEPALIVE=4747 run install --answers "$ANSWERS"
    assert_success
    sleep 0.3
    run /usr/bin/pgrep -fx "sleep 4747"
    assert_failure
}
