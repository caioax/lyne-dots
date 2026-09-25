#!/bin/sh
# (Re)starts the clipboard history watchers with the options saved in
# Settings › Clipboard (state.json "clipboard"): images or text only, and how
# many entries cliphist keeps. Run by Hyprland's autostart and by Quickshell
# when those settings change; the watchers outlive Quickshell.

state="$HOME/.config/quickshell/state.json"
images=true
max_items=750

if command -v jq >/dev/null && [ -f "$state" ]; then
    # Not `// true`: jq's // replaces false too
    images=$(jq -r 'if .clipboard.storeImages == false then "false" else "true" end' "$state")
    max_items=$(jq -r '.clipboard.maxItems // 750' "$state")
fi

command -v cliphist >/dev/null || exit 127

pkill -u "$(id -u)" -f "wl-paste --type (text|image) --watch cliphist" 2>/dev/null

setsid -f wl-paste --type text --watch cliphist -max-items "$max_items" store >/dev/null 2>&1
if [ "$images" = "true" ]; then
    setsid -f wl-paste --type image --watch cliphist -max-items "$max_items" store >/dev/null 2>&1
fi
