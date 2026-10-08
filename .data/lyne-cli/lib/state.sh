# state.sh - Writes to the shell's state.json
#
# Quickshell watches state.json and reapplies what changed. A write in place
# (`>`, cp) can be read half written, and one write per key makes it apply
# each step, so every writer goes through these: one jq filter for all the
# keys, a temporary file in the same folder, and a rename. A write that
# changes nothing doesn't touch the file.
#
#   lyne_state_set FILTER [jq options]   e.g.
#       lyne_state_set '.theme.mode = "preset" | .theme.name = $n' --arg n nord
#   lyne_state_replace <file             the whole file, from stdin
#
# Usage: source this file. LYNE_STATE_FILE points them at another file

lyne_state_file() {
    printf '%s\n' "${LYNE_STATE_FILE:-$HOME/.config/quickshell/state.json}"
}

lyne_state_set() {
    local filter="$1"
    shift
    local state
    state="$(lyne_state_file)"
    [[ -f "$state" ]] || return 1
    jq "$filter" "$@" <"$state" | lyne_state_replace
    local codes=("${PIPESTATUS[@]}")
    [[ "${codes[0]}" == 0 && "${codes[1]}" == 0 ]]
}

lyne_state_replace() {
    local state tmp
    state="$(lyne_state_file)"
    # Through the symlinks, so the rename lands next to the real file
    state="$(realpath -m "$state")"
    tmp="$(mktemp "$state.XXXXXX")" || return 1
    cat >"$tmp"
    # Empty when jq failed: keep the file as it is
    if [[ ! -s "$tmp" ]] || cmp -s "$tmp" "$state"; then
        rm -f "$tmp"
        return 0
    fi
    [[ -f "$state" ]] && chmod --reference="$state" "$tmp"
    mv -f "$tmp" "$state" || {
        rm -f "$tmp"
        return 1
    }
}
