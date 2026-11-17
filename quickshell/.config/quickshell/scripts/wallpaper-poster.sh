#!/bin/bash
# =============================================================================
# wallpaper-poster.sh VIDEO
# =============================================================================
# Prints the poster of an animated wallpaper: its first frame as a JPEG,
# made once with ffmpeg and cached by path, size and modification time, so
# a replaced video gets a new one. The poster stands in for the video
# wherever a still image is needed: under the video while it starts, colors
# (matugen), thumbnails, the lock screen and the login screen.
#
# Exits 3 when VIDEO is not a file, 4 when ffmpeg can't read it.
# =============================================================================

video="$1"

[[ -f "$video" ]] || {
    echo "not found: $video" >&2
    exit 3
}

cache="${XDG_CACHE_HOME:-$HOME/.cache}/lyne/wallpaper-posters"
real="$(realpath "$video")"
key="$(printf '%s|%s' "$real" "$(stat -c '%s|%Y' "$real")" | sha1sum | cut -d' ' -f1)"
poster="$cache/$key.jpg"

if [[ ! -s "$poster" ]]; then
    mkdir -p "$cache"
    # Written aside and moved, so a reader never gets half a file
    tmp="$cache/.$key.$$.jpg"
    if ! ffmpeg -nostdin -loglevel error -y -i "$real" -frames:v 1 -q:v 2 "$tmp" || [[ ! -s "$tmp" ]]; then
        rm -f "$tmp"
        echo "no frame from: $video" >&2
        exit 4
    fi
    mv -f "$tmp" "$poster"
fi

printf '%s\n' "$poster"
