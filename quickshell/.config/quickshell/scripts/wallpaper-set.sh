#!/bin/bash
# =============================================================================
# wallpaper-set.sh PATH [TYPE] [SPEED]
# =============================================================================
# Shows PATH with awww, with the transition chosen in Settings › Wallpaper.
# Every path that changes the wallpaper goes through here (WallpaperService
# and the boot script), so they all look the same.
#
#   TYPE   none | fade | grow | wipe | wave | random (one of the others)
#   SPEED  fast | normal | slow
#
# Left out (the boot script), both come from wallpaper.transition and
# wallpaper.transitionSpeed in the shell's state.json; fade and normal when
# that has neither. Exits 3 when PATH is not a file.
# =============================================================================

path="$1"
type="$2"
speed="$3"

[[ -f "$path" ]] || {
    echo "not found: $path" >&2
    exit 3
}

state="$HOME/.config/quickshell/state.json"
if [[ -z "$type" || -z "$speed" ]] && [[ -f "$state" ]] && command -v jq >/dev/null; then
    [[ -z "$type" ]] && type="$(jq -r '.wallpaper.transition // empty' "$state" 2>/dev/null)"
    [[ -z "$speed" ]] && speed="$(jq -r '.wallpaper.transitionSpeed // empty' "$state" 2>/dev/null)"
fi

if [[ "$type" == random ]]; then
    kinds=(fade grow wipe wave)
    type="${kinds[RANDOM % ${#kinds[@]}]}"
fi
case "$type" in
    none | fade | grow | wipe | wave) ;;
    *) type=fade ;;
esac

case "$speed" in
    fast) duration=0.6 ;;
    slow) duration=2 ;;
    *) duration=1.2 ;;
esac

if [[ "$type" == none ]]; then
    exec awww img "$path" --transition-type none
fi
exec awww img "$path" --transition-type "$type" --transition-duration "$duration" \
    --transition-fps 60 --transition-step 90
