# 030-whatsapp-chromium.sh - WhatsApp special workspace opens WhatsApp Web in Chromium
#
# The WhatsApp special workspace (SUPER+W) now opens WhatsApp Web as a
# Chromium app with its own profile (~/.local/share/lyne/whatsapp), lighter
# than ZapZap. A special still opening ZapZap moves to it; ZapZap stays
# installed and can be picked again in Settings › Hyprland › Specials.

if command -v pacman &>/dev/null; then
    if pacman -Q chromium &>/dev/null; then
        echo "   chromium already installed, skipping"
    else
        echo "   Installing chromium..."
        sudo pacman -S --needed --noconfirm chromium
    fi
elif ! command -v chromium &>/dev/null; then
    echo "   chromium not found. Please install it manually."
fi

local state="$HOME/.config/quickshell/state.json"
local defaults="$DOTS_DIR/.data/quickshell/defaults.json"

if [[ -f "$state" && -f "$defaults" ]] && command -v jq &>/dev/null \
    && jq -e '(.specials.list | type) == "array" and any(.specials.list[]; .command == "zapzap")' "$state" &>/dev/null; then
    local tmp
    tmp="$(mktemp)"
    # Command and class from the default WhatsApp special
    if jq --slurpfile d "$defaults" '
        ($d[0].specials.list[] | select(.id == "whatsapp")) as $web
        | .specials.list |= map(
            if .command == "zapzap" then .command = $web.command | .class = $web.class else . end)' "$state" >"$tmp"; then
        cat "$tmp" >"$state"
        echo "   WhatsApp special workspace now opens WhatsApp Web (scan the QR code once)"
        if pgrep -x zapzap &>/dev/null || pgrep -f '^/usr/bin/python /usr/bin/zapzap' &>/dev/null; then
            echo "   ZapZap is still running: close it, then press SUPER+W"
        fi
    fi
    rm -f "$tmp"
fi
