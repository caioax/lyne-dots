#!/bin/bash
# =============================================================================
# wallpaper-poster.sh PATH
# =============================================================================
# Prints the still image of a wallpaper: PATH itself for an image; for a
# video (mp4, webm, mkv) its poster: a frame as a JPEG, made once with ffmpeg
# and cached by path, size and modification time, so a replaced video gets a
# new one. The first frame, unless it's (nearly) black, as in a video that
# fades in: then the first of a few later ones that isn't, or the brightest
# of them in a dark video. The poster stands in for the video
# wherever a still image is needed: under the video while it starts, colors
# (matugen), thumbnails, the lock screen and the login screen.
#
# A poster is touched each time it's asked for; wallpaper-thumb.sh deletes
# the ones nothing asked for in a month (a deleted or replaced video's).
#
# Exits 3 when PATH is not a file, 4 when ffmpeg can't read the video.
# =============================================================================

video="$1"

[[ -f "$video" ]] || {
    echo "not found: $video" >&2
    exit 3
}

case "${video,,}" in
    *.mp4 | *.webm | *.mkv) ;;
    *)
        printf '%s\n' "$video"
        exit 0
        ;;
esac

cache="${XDG_CACHE_HOME:-$HOME/.cache}/lyne/wallpaper-posters"
real="$(realpath "$video")"
# v2: posters skip a black first frame (older ones are made again)
key="$(printf 'v2|%s|%s' "$real" "$(stat -c '%s|%Y' "$real")" | sha1sum | cut -d' ' -f1)"
poster="$cache/$key.jpg"

# Average brightness (0-255) of an image; 255 when it can't be measured, so
# a frame is never thrown away for that
brightness() {
    local y
    y="$(ffprobe -v error -f lavfi -i "movie=$1,signalstats" \
        -show_entries frame_tags=lavfi.signalstats.YAVG -of csv=p=0 2>/dev/null)"
    [[ "$y" =~ ^[0-9]+ ]] && echo "${BASH_REMATCH[0]}" || echo 255
}

# A frame darker than this is taken for black
dark=16

if [[ ! -s "$poster" ]]; then
    mkdir -p "$cache"
    # Frames are written aside and the chosen one moved, so a reader never
    # gets half a file
    best="" best_y=-1
    # Seconds into the video; past its end ffmpeg writes nothing
    for at in 0 1 2 3 5; do
        frame="$cache/.$key.$$.$at.jpg"
        ffmpeg -nostdin -loglevel error -y -ss "$at" -i "$real" -frames:v 1 -q:v 2 "$frame" >/dev/null 2>&1
        if [[ ! -s "$frame" ]]; then
            rm -f "$frame"
            continue
        fi
        y="$(brightness "$frame")"
        if ((y > best_y)); then
            [[ -n "$best" ]] && rm -f "$best"
            best="$frame" best_y="$y"
        else
            rm -f "$frame"
        fi
        ((y >= dark)) && break
    done
    if [[ -z "$best" ]]; then
        echo "no frame from: $video" >&2
        exit 4
    fi
    mv -f "$best" "$poster"
else
    # Still in use: wallpaper-thumb.sh prunes the ones left unused
    touch -c "$poster"
fi

printf '%s\n' "$poster"
