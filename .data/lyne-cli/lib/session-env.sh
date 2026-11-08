#!/bin/bash
# =============================================================================
# session-env.sh - The current Hyprland session's variables for the lyne CLI
# =============================================================================
# A terminal older than the Hyprland session (a tmux server that outlived a
# logout) keeps the old HYPRLAND_INSTANCE_SIGNATURE: hyprctl fails there, and
# a Quickshell that `lyne reload` or `lyne update` starts from it can't reach
# Hyprland (workspaces frozen on every monitor). uwsm keeps the current
# values in the systemd user environment.
#
#   lyne_session_env   when the signature's socket is gone, take
#                      HYPRLAND_INSTANCE_SIGNATURE and WAYLAND_DISPLAY from
#                      the systemd user environment (only if that one is live)
#
# Without a signature (a TTY, the tests) nothing changes: the CLI never
# reaches a session it wasn't started in.
# =============================================================================

lyne_session_env() {
    local his="${HYPRLAND_INSTANCE_SIGNATURE:-}" runtime="${XDG_RUNTIME_DIR:-/run/user/$UID}"
    local line new_his="" new_wl=""
    [[ -n "$his" ]] || return 0
    [[ -S "$runtime/hypr/$his/.socket.sock" ]] && return 0
    while IFS= read -r line; do
        case "$line" in
        HYPRLAND_INSTANCE_SIGNATURE=*) new_his="${line#*=}" ;;
        WAYLAND_DISPLAY=*) new_wl="${line#*=}" ;;
        esac
    done < <(systemctl --user show-environment 2>/dev/null)
    [[ -n "$new_his" && -S "$runtime/hypr/$new_his/.socket.sock" ]] || return 0
    export HYPRLAND_INSTANCE_SIGNATURE="$new_his"
    if [[ -n "$new_wl" ]]; then export WAYLAND_DISPLAY="$new_wl"; fi
}
