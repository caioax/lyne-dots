#!/usr/bin/env bash
# Copies images and videos into the wallpaper library (WallpaperService: Add
# and Add folder in Settings › Wallpaper).
#
#   wallpapers-add.sh [--fit WxH] DEST PATH...
#
# Each PATH is a wallpaper, or a folder searched for them in its subfolders
# too (hidden ones left out). Wallpapers are images (png, jpg, jpeg, webp)
# and videos (mp4, webm, mkv), in any case. A name already in DEST gets -1,
# -2... unless that file is the same wallpaper, which is skipped; so are
# files already inside DEST (adding the library itself, or its themes/
# folder). Prints one line per wallpaper:
#   added:<the copy in DEST>
#   skipped:<PATH's file>
#
# --fit WxH (the largest screen, in pixels): a video larger than needed to
# cover it is stored scaled down to that, as H.264 mp4 without sound, with a
# progress notification ($LYNE_FIT_TITLE, translated by the caller); the
# source file is left as it is. The copy remembers its source, so adding the
# same video again is still skipped.

set -uo pipefail

fit=""
if [[ "${1:-}" == --fit ]]; then
    fit="${2:-}"
    shift 2
fi
dest="${1:?usage: wallpapers-add.sh [--fit WxH] DEST PATH...}"
shift
mkdir -p "$dest" || exit 1
real_dest="$(realpath "$dest")"

ext_of() {
    local ext="${1##*.}"
    echo "${ext,,}"
}

is_video() {
    case "$(ext_of "$1")" in
    mp4 | webm | mkv) return 0 ;;
    esac
    return 1
}

is_wallpaper() {
    is_video "$1" && return 0
    case "$(ext_of "$1")" in
    png | jpg | jpeg | webp) return 0 ;;
    esac
    return 1
}

# fit_size VIDEO: "W H" to scale VIDEO down to, the smallest size of its
# shape that still covers --fit (even numbers); nothing when it already fits
fit_size() {
    [[ "$fit" =~ ^([0-9]+)x([0-9]+)$ ]] || return 0
    local sw="${BASH_REMATCH[1]}" sh="${BASH_REMATCH[2]}" vw vh
    read -r vw vh < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
        -of csv=p=0:s=x -- "$1" 2>/dev/null | tr x ' ')
    [[ "$vw" =~ ^[0-9]+$ && "$vh" =~ ^[0-9]+$ ]] || return 0
    # Covering the screen takes scale max(sw/vw, sh/vh); below 1 it shrinks
    if ((sw * vh >= sh * vw)); then
        ((vw > sw)) || return 0
        echo "$sw $(((vh * sw / vw + 1) / 2 * 2))"
    else
        ((vh > sh)) || return 0
        echo "$(((vw * sh / vh + 1) / 2 * 2)) $sh"
    fi
}

# Tag the scaled copy carries: the source's checksum
source_tag() {
    echo "lyne-source:$(sha1sum -- "$1" | cut -d' ' -f1)"
}

copy_tag() {
    ffprobe -v error -show_entries format_tags=comment -of default=nw=1:nk=1 -- "$1" 2>/dev/null
}

# scale SRC TARGET W H TAG: the scaled copy, with a progress notification
scale() {
    local src="$1" target="$2" w="$3" h="$4" tag="$5" duration id="" pct last=-1 line us
    local tmp="$dest/.adding-$$.mp4"
    duration="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 -- "$src" 2>/dev/null)"
    duration="${duration%%.*}"
    local title="${LYNE_FIT_TITLE:-Fitting a video to your screen}"
    id="$(notify-send -a Settings -i preferences-desktop-wallpaper -p -h int:value:0 "$title" "${src##*/}" 2>/dev/null)"
    while IFS= read -r line; do
        [[ "$line" == out_time_us=* && "${duration:-0}" -gt 0 ]] || continue
        us="${line#out_time_us=}"
        [[ "$us" =~ ^[0-9]+$ ]] || continue
        pct=$((us / 10000 / duration))
        ((pct > 99)) && pct=99
        # Every 5%, not every frame
        if ((pct / 5 != last / 5)) && [[ -n "$id" ]]; then
            notify-send -a Settings -i preferences-desktop-wallpaper -r "$id" -h "int:value:$pct" "$title" "${src##*/}" 2>/dev/null
            last=$pct
        fi
    # Nice: it takes every core for a few seconds
    done < <(nice -n 10 ffmpeg -nostdin -loglevel error -nostats -progress pipe:1 -y -i "$src" -an \
        -vf "scale=$w:$h:flags=lanczos" -c:v libx264 -preset veryfast -crf 18 -pix_fmt yuv420p \
        -movflags +faststart -metadata "comment=$tag" "$tmp")
    if [[ -s "$tmp" && "$(copy_tag "$tmp")" == "$tag" ]]; then
        mv -f -- "$tmp" "$target"
        [[ -n "$id" ]] && notify-send -a Settings -i preferences-desktop-wallpaper -r "$id" -t 2000 \
            -h int:value:100 "$title" "${src##*/}" 2>/dev/null
        return 0
    fi
    rm -f -- "$tmp"
    [[ -n "$id" ]] && notify-send -a Settings -i preferences-desktop-wallpaper -r "$id" -t 1 "$title" "" 2>/dev/null
    return 1
}

copy_one() {
    local src="$1" real name base ext target n=1 size="" tag=""
    real="$(realpath "$src")"
    if [[ "$real" == "$real_dest"/* ]]; then
        echo "skipped:$src"
        return
    fi
    name="${src##*/}"
    base="${name%.*}"
    ext="${name##*.}"
    if is_video "$src"; then
        size="$(fit_size "$src")"
        if [[ -n "$size" ]]; then
            ext=mp4
            tag="$(source_tag "$src")"
        fi
    fi
    target="$dest/$base.$ext"
    while [[ -e "$target" ]]; do
        if cmp -s -- "$src" "$target" || { [[ -n "$tag" ]] && [[ "$(copy_tag "$target")" == "$tag" ]]; }; then
            echo "skipped:$src"
            return
        fi
        target="$dest/$base-$n.$ext"
        n=$((n + 1))
    done
    if [[ -n "$size" ]]; then
        # shellcheck disable=SC2086 # "W H"
        scale "$src" "$target" $size "$tag" && echo "added:$target"
    else
        cp -- "$src" "$target" && echo "added:$target"
    fi
}

for path in "$@"; do
    if [[ -d "$path" ]]; then
        while IFS= read -r -d '' file; do
            is_wallpaper "$file" && copy_one "$file"
        done < <(find "$path" -mindepth 1 -name '.*' -prune -o -type f -print0 | sort -z)
    elif [[ -f "$path" ]] && is_wallpaper "$path"; then
        copy_one "$path"
    fi
done
exit 0
