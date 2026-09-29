#!/usr/bin/env bash
# Monitor rules for Settings › Hyprland › Monitors (MonitorsService) and
# `lyne monitors`.
#
#   monitors.sh write <content>        validate with Hyprland, install
#                                      ~/.config/hypr/monitors.lua atomically,
#                                      wait until the reload ran it (ends a
#                                      trial: the rules are kept)
#   monitors.sh watch <token> <secs>   revert a trial unless it was kept
#                                      (run detached: it outlives Quickshell)
#   monitors.sh keep                   the trial stays: stop the watcher
#   monitors.sh revert                 drop a trial: reload the saved file
#   monitors.sh loaded                 hash of the monitors.lua Hyprland ran
#
# A trial is the new rules sent with `hyprctl eval` (not saved): a config
# reload brings the saved file back, so reverting is a reload.
#
# LYNE_HYPR_DIR and LYNE_HYPR_INSTANCE point the tests at a nested Hyprland.

set -u

HYPR_DIR="${LYNE_HYPR_DIR:-$HOME/.config/hypr}"
TARGET="$HYPR_DIR/monitors.lua"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
MARK="$RUNTIME/lyne-monitors-trial"

hypr() {
    if [[ -n "${LYNE_HYPR_INSTANCE:-}" ]]; then
        hyprctl -i "$LYNE_HYPR_INSTANCE" "$@"
    else
        hyprctl "$@"
    fi
}

lua_string() {
    printf '"%s"' "$(printf '%s' "$1" | sed 's/[\\"]/\\&/g')"
}

# Result of a Lua snippet that writes to the file named by the global `out`
# (hyprctl eval only answers "ok")
hypr_lua() {
    local result
    result="$(mktemp "$RUNTIME/lyne-monitors-XXXXXX")"
    hypr eval "local out = $(lua_string "$result"); $1" >/dev/null 2>&1
    cat "$result" 2>/dev/null
    rm -f "$result"
}

# The hash in the last line of the file (lyne_monitors_file = "...")
file_hash() {
    sed -nE 's/^lyne_monitors_file = "([^"]*)".*/\1/p' "$1" | tail -n 1
}

loaded() {
    hypr_lua 'local f = io.open(out, "w"); f:write(tostring(lyne_monitors_file or "")); f:close()'
}

write() {
    local content="$1" check
    # Saving ends a trial: its watcher must not revert what's kept
    rm -f "$MARK"
    check="$(mktemp "$RUNTIME/lyne-monitors-check-XXXXXX.lua")"
    printf '%s' "$content" >"$check"

    # Run it the way Hyprland will, with hl.monitor checking each call, in a
    # sandbox: a broken file would stop loading in silence after the reload
    local verdict
    verdict="$(hypr_lua "
        local problem
        local env = { hl = { monitor = function(spec)
            if type(spec) ~= 'table' or type(spec.output) ~= 'string' then
                problem = problem or 'hl.monitor needs a table with an output'
            end
        end } }
        local chunk, err = loadfile($(lua_string "$check"), 't', env)
        if chunk then
            local ok, run_err = pcall(chunk)
            if not ok then err = run_err end
        end
        local f = io.open(out, 'w')
        f:write(err and tostring(err) or problem or 'ok')
        f:close()")"
    if [[ "$verdict" != "ok" ]]; then
        rm -f "$check"
        echo "invalid: ${verdict:-no answer from Hyprland}"
        return 1
    fi

    # Same directory, then rename: Hyprland never reads a half-written file
    local tmp="$HYPR_DIR/.monitors.lua.new"
    cp "$check" "$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$TARGET"
    rm -f "$check"

    # Writing the file makes Hyprland reload; reload anyway in case the
    # watcher missed it, and wait until it ran this file
    local want i
    want="$(file_hash "$TARGET")"
    for i in $(seq 1 20); do
        sleep 0.15
        [[ "$(loaded)" == "$want" ]] && { echo "ok"; return 0; }
        [[ $i -eq 8 ]] && hypr reload >/dev/null 2>&1
    done
    echo "not loaded: Hyprland didn't run the new monitors.lua (check: hyprctl configerrors)"
    return 1
}

watch() {
    local token="$1" seconds="$2"
    printf '%s\n' "$token" >"$MARK"
    sleep "$seconds"
    if [[ -f "$MARK" && "$(cat "$MARK")" == "$token" ]]; then
        rm -f "$MARK"
        hypr reload >/dev/null 2>&1
        echo "reverted"
    fi
}

case "${1:-}" in
    write) write "${2:-}" ;;
    watch) watch "${2:?token}" "${3:-15}" ;;
    keep) rm -f "$MARK"; echo "ok" ;;
    revert) rm -f "$MARK"; hypr reload >/dev/null 2>&1; echo "ok" ;;
    loaded) loaded; echo ;;
    *)
        echo "usage: monitors.sh write <content> | watch <token> <secs> | keep | revert | loaded" >&2
        exit 2
        ;;
esac
