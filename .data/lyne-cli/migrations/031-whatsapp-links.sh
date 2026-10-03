# 031-whatsapp-links.sh - WhatsApp Web opens its links in the default browser
#
# The WhatsApp special workspace now runs `lyne whatsapp`, which starts the
# same Chromium app with a small extension that hands the links clicked in
# WhatsApp to the default browser. Specials running the previous chromium
# command move to it (same profile, no new QR code).

local state="$HOME/.config/quickshell/state.json"
local old='chromium --app=https://web.whatsapp.com --user-data-dir=$HOME/.local/share/lyne/whatsapp --no-first-run --no-default-browser-check'

if [[ -f "$state" ]] && command -v jq &>/dev/null \
    && jq -e --arg old "$old" '(.specials.list | type) == "array" and any(.specials.list[]; .command == $old)' "$state" &>/dev/null; then
    local tmp
    tmp="$(mktemp)"
    if jq --arg old "$old" '.specials.list |= map(if .command == $old then .command = "lyne whatsapp" else . end)' "$state" >"$tmp"; then
        cat "$tmp" >"$state"
        echo "   WhatsApp Web now opens links in your default browser"
        if pgrep -f -- "--user-data-dir=$HOME/.local/share/lyne/whatsapp" &>/dev/null; then
            echo "   Close WhatsApp and open it again (SUPER+W) to use it"
        fi
    fi
    rm -f "$tmp"
fi
