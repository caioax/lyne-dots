#!/bin/bash
# =============================================================================
# Wallpaper Boot Script
# =============================================================================
# awww-daemon restores its last wallpaper on its own. This makes sure the one
# saved in ~/.local/wallpapers/.current (written by Quickshell's
# WallpaperService) is shown, and falls back to the first wallpaper only when
# nothing is displayed at all.
# =============================================================================

CURRENT_FILE="$HOME/.local/wallpapers/.current"
WALLPAPER_DIR="$HOME/.local/wallpapers"

# Wait for the daemon (started right before this script)
for _ in $(seq 1 20); do
    awww query >/dev/null 2>&1 && break
    sleep 0.25
done

[[ -f "$CURRENT_FILE" ]] && WALLPAPER="$(head -n 1 "$CURRENT_FILE")"

if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
    # Keep what the daemon restored from its cache
    awww query 2>/dev/null | grep -q "image:" && exit 0
    WALLPAPER="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) | sort | head -1)"
fi

# Already on screen (restored from the cache): nothing to do
[[ "$(realpath "$WALLPAPER" 2>/dev/null)" == "$(awww query 2>/dev/null | sed -n 's/.*image: //p' | head -n 1)" ]] && exit 0

# Same transition as a change from the shell (Settings › Wallpaper)
if [[ -n "$WALLPAPER" && -f "$WALLPAPER" ]]; then
    "$HOME/.config/quickshell/scripts/wallpaper-set.sh" "$WALLPAPER"
fi
