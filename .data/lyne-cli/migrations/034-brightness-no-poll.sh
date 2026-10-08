# 034-brightness-no-poll.sh - External monitors aren't polled over DDC/CI
#
# brightness.pollInterval now defaults to 0: ddcutil was the shell's only
# periodic process, and the brightness is read anyway when Quick Settings or
# the dashboard opens. Whoever still has the old default (60 s) gets the new
# one; a value picked in Settings › Brightness stays.

local state="$HOME/.config/quickshell/state.json"

if [[ -f "$state" ]] && command -v jq &>/dev/null && jq -e '.brightness.pollInterval == 60' "$state" &>/dev/null; then
    local tmp
    tmp="$(mktemp)"
    if jq '.brightness.pollInterval = 0' "$state" >"$tmp"; then
        lyne_state_replace <"$tmp"
        echo "   External monitor brightness is no longer polled (Settings › Brightness › Refresh)"
    fi
    rm -f "$tmp"
fi
return 0
