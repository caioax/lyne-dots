# Shared setup for the bats tests: load with `load helpers` and call
# `lyne_setup` from setup().
#
# Every test gets a throwaway HOME and runs with stand-ins (tests/bash/stubs)
# for sudo, pacman, systemctl, udevadm, mkinitcpio and yay first in PATH:
# they log each call to $STUB_LOG and keep a fake package database
# ($FAKE_PKGS, "name version" lines) and enabled units ($FAKE_ENABLED).

bats_load_library bats-support
bats_load_library bats-assert

REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
# LYNE_TEST_LIB points the tests at another copy of the libs
LIB="${LYNE_TEST_LIB:-$REPO/.data/lyne-cli/lib}"
# shellcheck disable=SC2034 # used by the .bats files
FIXTURES="$BATS_TEST_DIRNAME/fixtures"

lyne_setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    # Set in the user's session: with a fake HOME they'd still point at the
    # real ~/.local/state and friends
    unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_DATA_HOME
    # Nor the graphical session: nothing may reach the user's Hyprland
    unset HYPRLAND_INSTANCE_SIGNATURE LYNE_HYPR_LOG WAYLAND_DISPLAY DISPLAY
    export DOTS_DIR="$HOME/.lyne-dots"

    export PATH="$BATS_TEST_DIRNAME/stubs:$PATH"
    export STUB_LOG="$BATS_TEST_TMPDIR/stub.log"
    export FAKE_PKGS="$BATS_TEST_TMPDIR/pkgs"
    export FAKE_ENABLED="$BATS_TEST_TMPDIR/enabled"
    : >"$STUB_LOG"
    : >"$FAKE_PKGS"
    : >"$FAKE_ENABLED"

    # git without the user's config (signing, hooks, templates)
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
    export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
}

# pkgs NAME[=VERSION]...: packages in the fake database
pkgs() {
    local p
    for p in "$@"; do
        [[ "$p" == *=* ]] && echo "${p%%=*} ${p#*=}" >>"$FAKE_PKGS" || echo "$p 1.0-1" >>"$FAKE_PKGS"
    done
}

# in_lyne LIB... -- CODE: runs CODE in a new bash the way the lyne CLI runs
# its commands: state.sh and log.sh sourced, then each lib sourced inside a
# function (some declare `local` at their top level)
in_lyne() {
    local libs=()
    while (($#)) && [[ "$1" != -- ]]; do
        libs+=("$1")
        shift
    done
    shift
    LYNE_TEST_CODE="$1" bash -c '
        source "$1/state.sh"
        source "$2"
        _lyne_test() {
            local _lyne_test_lib
            for _lyne_test_lib in "${@:3}"; do
                source "$1/$_lyne_test_lib.sh" || return 1
            done
            eval "$LYNE_TEST_CODE"
        }
        _lyne_test "$@"' _ "$LIB" "$REPO/.install/lib/log.sh" "${libs[@]}"
}

# fx_gpu ROOT PCI VENDOR:DEVICE [key=value...]: one display controller in a
# fake sysfs at ROOT (LYNE_SYSFS). Keys: driver, card, outputs ("eDP-1:connected
# HDMI-A-1:disconnected"), boot_vga, vram (bytes), class
fx_gpu() {
    local root=$1 pci=$2 ids=$3
    shift 3
    local driver="" card="" outputs="" boot_vga=0 vram="" class=0x030000 kv
    for kv in "$@"; do
        case "$kv" in
        driver=*) driver=${kv#*=} ;;
        card=*) card=${kv#*=} ;;
        outputs=*) outputs=${kv#*=} ;;
        boot_vga=*) boot_vga=${kv#*=} ;;
        vram=*) vram=${kv#*=} ;;
        class=*) class=${kv#*=} ;;
        esac
    done
    local dev="$root/devices/pci0000:00/$pci"
    mkdir -p "$dev" "$root/bus/pci/devices"
    ln -sfn "$dev" "$root/bus/pci/devices/$pci"
    echo "$class" >"$dev/class"
    echo "0x${ids%:*}" >"$dev/vendor"
    echo "0x${ids#*:}" >"$dev/device"
    echo "$boot_vga" >"$dev/boot_vga"
    [[ -n "$vram" ]] && echo "$vram" >"$dev/mem_info_vram_total"
    if [[ -n "$driver" ]]; then
        mkdir -p "$root/bus/pci/drivers/$driver"
        ln -sfn "$root/bus/pci/drivers/$driver" "$dev/driver"
    fi
    if [[ -n "$card" ]]; then
        mkdir -p "$dev/drm/$card" "$root/class/drm"
        ln -sfn "$dev/drm/$card" "$root/class/drm/$card"
        ln -sfn "$dev" "$dev/drm/$card/device"
        local out
        for out in $outputs; do
            mkdir -p "$dev/drm/$card/$card-${out%:*}"
            echo "${out#*:}" >"$dev/drm/$card/$card-${out%:*}/status"
        done
    fi
}

# fake_dots [MIGRATIONS_DIR]: $DOTS_DIR as the repo seen through per-item
# links, except what tests write to: the shell config folder is a real one
# with its own state.json (from defaults.json, linked from
# ~/.config/quickshell like an install does), and .data/lyne-cli/migrations
# can point elsewhere (LYNE_TEST_MIGRATIONS for a copy). Writing through a link would change the repo: tests
# that use this call `repo_unchanged` in teardown.
fake_dots() {
    local item cfg="$DOTS_DIR/quickshell/.config/quickshell"
    mkdir -p "$DOTS_DIR/.data/lyne-cli" "$cfg" "$HOME/.config"
    for item in "$REPO"/* "$REPO"/.[!.]*; do
        case "${item##*/}" in
        .git | .data | quickshell) ;;
        *) ln -s "$item" "$DOTS_DIR/" ;;
        esac
    done
    for item in "$REPO"/.data/*; do
        [[ "${item##*/}" == lyne-cli ]] || ln -s "$item" "$DOTS_DIR/.data/"
    done
    ln -s "$LIB" "$DOTS_DIR/.data/lyne-cli/lib"
    ln -s "$REPO/.data/lyne-cli/commands" "$DOTS_DIR/.data/lyne-cli/"
    ln -s "${1:-${LYNE_TEST_MIGRATIONS:-$REPO/.data/lyne-cli/migrations}}" "$DOTS_DIR/.data/lyne-cli/migrations"
    for item in "$REPO"/quickshell/.config/quickshell/*; do
        [[ "${item##*/}" == state.json ]] || ln -s "$item" "$cfg/"
    done
    cp "$REPO/.data/quickshell/defaults.json" "$cfg/state.json"
    ln -s "$cfg" "$HOME/.config/quickshell"
    REPO_STATUS="$(git -C "$REPO" status --porcelain)"
}

repo_unchanged() {
    [[ -z "${REPO_STATUS+x}" ]] && return 0
    local now
    now="$(git -C "$REPO" status --porcelain)"
    if [[ "$now" != "$REPO_STATUS" ]]; then
        echo "the test changed the repo:" >&2
        diff <(echo "$REPO_STATUS") <(echo "$now") >&2
        return 1
    fi
}

# Every file under $HOME (links listed, not followed) with a hash of its
# content, plus the fake package list: two snapshots differ when anything
# was written
snapshot() {
    (
        cd "$HOME" || exit 1
        find . -path ./.lyne-dots -prune -o -type l -printf '%p -> %l\n' | sort
        find . -path ./.lyne-dots -prune -o -type f -print0 | xargs -0 -r sha1sum | sort -k2
        find .lyne-dots -type f -print0 | xargs -0 -r sha1sum | sort -k2
    )
    sort "$FAKE_PKGS"
}
