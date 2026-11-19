#!/bin/bash
# =============================================================================
# wallpaper-thumb.sh WxH PATH...
# =============================================================================
# Prints "PATH<TAB>THUMB" for each wallpaper: a small JPEG that covers WxH
# (aspect kept), made once with ffmpeg and cached by the still's path, size,
# modification time and WxH, so a replaced file gets a new one. A video's
# still is its poster (wallpaper-poster.sh). Tiles load these
# instead of decoding the full image (a 5K PNG) every time one scrolls in.
#
# A few run at once. A path that is not a file, or that ffmpeg can't read,
# prints nothing (and a line on stderr); the exit status is 0 regardless,
# so one broken wallpaper doesn't hide the others.
#
# Both caches are keyed by hashes, so a deleted or replaced wallpaper leaves
# its files behind: each use touches a file, and once a day the ones unused
# for LYNE_CACHE_DAYS (30) days go, thumbnails and posters alike. Listing the
# library asks for every one in use, so only leftovers age out.
# =============================================================================

size="$1"
shift
[[ "$size" =~ ^([0-9]+)x([0-9]+)$ ]] || {
    echo "usage: wallpaper-thumb.sh WxH PATH..." >&2
    exit 2
}
width="${BASH_REMATCH[1]}"
height="${BASH_REMATCH[2]}"

cache="${XDG_CACHE_HOME:-$HOME/.cache}/lyne/wallpaper-thumbs"
posters="${XDG_CACHE_HOME:-$HOME/.cache}/lyne/wallpaper-posters"
poster_script="$(dirname "$(realpath "$0")")/wallpaper-poster.sh"
jobs_max="${LYNE_THUMB_JOBS:-4}"

thumb_of() {
    local path="$1" real key thumb tmp source
    if [[ ! -f "$path" ]]; then
        echo "not found: $path" >&2
        return
    fi
    # An image is its own still; a video stands as its poster. Keyed by
    # that still, so a new poster (a replaced video) makes a new thumbnail
    source="$("$poster_script" "$path" 2>/dev/null)" || {
        echo "no frame from: $path" >&2
        return
    }
    real="$(realpath "$source")"
    key="$(printf '%s|%s|%s' "$real" "$(stat -c '%s|%Y' "$real")" "$size" | sha1sum | cut -d' ' -f1)"
    thumb="$cache/$key.jpg"

    if [[ -s "$thumb" ]]; then
        touch -c "$thumb"
    else
        # Written aside and moved, so a reader never gets half a file
        tmp="$cache/.$key.$BASHPID.jpg"
        if ! ffmpeg -nostdin -loglevel error -y -i "$source" -frames:v 1 \
            -vf "scale=$width:$height:force_original_aspect_ratio=increase:flags=lanczos" \
            -q:v 3 "$tmp" >/dev/null || [[ ! -s "$tmp" ]]; then
            rm -f "$tmp"
            echo "no thumbnail from: $path" >&2
            return
        fi
        mv -f "$tmp" "$thumb"
    fi

    printf '%s\t%s\n' "$path" "$thumb"
}

# Once a day: files nothing used for that long (temporary ones a killed run
# left included)
prune() {
    local stamp="${cache%/*}/.wallpaper-cache-pruned" days="${LYNE_CACHE_DAYS:-30}"
    [[ -n "$(find "$stamp" -mmin -1440 2>/dev/null)" ]] && return
    touch "$stamp"
    find "$cache" "$posters" -maxdepth 1 -type f -name '*.jpg' -mtime "+$((days - 1))" -delete 2>/dev/null
}

mkdir -p "$cache"
for path in "$@"; do
    while (($(jobs -rp | wc -l) >= jobs_max)); do
        wait -n
    done
    thumb_of "$path" &
done
wait
# After the ones asked for were touched
prune
exit 0
