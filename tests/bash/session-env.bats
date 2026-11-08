#!/usr/bin/env bats
# lib/session-env.sh: a terminal from before the current Hyprland session

load helpers

setup() {
    lyne_setup
    export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/run" FAKE_SYSTEMD_ENV="$BATS_TEST_TMPDIR/systemd-env"
    mkdir -p "$XDG_RUNTIME_DIR/hypr/old" "$XDG_RUNTIME_DIR/hypr/new"
    printf 'HYPRLAND_INSTANCE_SIGNATURE=new\nWAYLAND_DISPLAY=wayland-2\nOTHER=x\n' >"$FAKE_SYSTEMD_ENV"
}

# A live Hyprland's socket
live() { python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$XDG_RUNTIME_DIR/hypr/$1/.socket.sock"; }
env_after() { in_lyne session-env -- 'lyne_session_env; echo "$HYPRLAND_INSTANCE_SIGNATURE $WAYLAND_DISPLAY"'; }

@test "a dead signature is replaced by the session's from systemd" {
    live new
    HYPRLAND_INSTANCE_SIGNATURE=old WAYLAND_DISPLAY=wayland-1 run env_after
    assert_output "new wayland-2"
}

@test "a live signature, none at all, or a dead one in systemd too: unchanged" {
    live old
    live new
    HYPRLAND_INSTANCE_SIGNATURE=old WAYLAND_DISPLAY=wayland-1 run env_after
    assert_output "old wayland-1"
    unset HYPRLAND_INSTANCE_SIGNATURE
    WAYLAND_DISPLAY=wayland-1 run env_after
    assert_output " wayland-1"
    rm "$XDG_RUNTIME_DIR/hypr/old/.socket.sock" "$XDG_RUNTIME_DIR/hypr/new/.socket.sock"
    HYPRLAND_INSTANCE_SIGNATURE=old WAYLAND_DISPLAY=wayland-1 run env_after
    assert_output "old wayland-1"
}

@test "the lyne CLI fixes them before running any command" {
    local entry="$REPO/local/.local/bin/lyne" fix run_cmd
    fix=$(grep -n '^lyne_session_env$' "$entry" | cut -d: -f1)
    run_cmd=$(grep -n '_lyne_run "\$@"$' "$entry" | cut -d: -f1)
    assert [ -n "$fix" ]
    assert [ "$fix" -lt "$run_cmd" ]
}
