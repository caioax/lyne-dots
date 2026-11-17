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
# cover it is stored scaled down to that, as H.264 mp4 without sound; the
# source file is left as it is. The copy remembers its source, so adding the
# same video again is still skipped. While it's scaled (Settings shows a
# tile with a progress ring):
#   fitting:<the copy in DEST><TAB><the source's poster>
#   progress:<the copy in DEST><TAB><0-99>
# then added:, or failed:/cancelled: with the copy's path. A line with the
# copy's path in the file $LYNE_ADD_CANCEL stops its scaling. A video ffprobe
# can't read is left out with failed:<PATH's file>.

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
here="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

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

# video_size VIDEO: "W H" of its picture; nothing when ffprobe can't read it
video_size() {
    local vw vh
    read -r vw vh < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
        -of csv=p=0:s=x -- "$1" 2>/dev/null | tr x ' ')
    [[ "$vw" =~ ^[0-9]+$ && "$vh" =~ ^[0-9]+$ ]] && echo "$vw $vh"
}

# fit_size W H: the size to scale a W x H video down to, the smallest of its
# shape that still covers --fit (even numbers); nothing when it already fits
fit_size() {
    [[ "$fit" =~ ^([0-9]+)x([0-9]+)$ ]] || return 0
    local sw="${BASH_REMATCH[1]}" sh="${BASH_REMATCH[2]}" vw="$1" vh="$2"
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

# scale SRC TARGET W H TAG: the scaled copy, reporting its progress
scale() {
    local src="$1" target="$2" w="$3" h="$4" tag="$5" duration pct last=-1 line us fd ffmpeg_pid
    local tmp="$dest/.adding-$$.mp4" cancelled=0
    duration="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 -- "$src" 2>/dev/null)"
    duration="${duration%%.*}"
    printf 'fitting:%s\t%s\n' "$target" "$("$here/wallpaper-poster.sh" "$src" 2>/dev/null)"
    # Nice: it takes every core for a few seconds
    exec {fd}< <(exec nice -n 10 ffmpeg -nostdin -loglevel error -nostats -progress pipe:1 -y -i "$src" -an \
        -vf "scale=$w:$h:flags=lanczos" -c:v libx264 -preset veryfast -crf 18 -pix_fmt yuv420p \
        -movflags +faststart -metadata "comment=$tag" "$tmp")
    ffmpeg_pid=$!
    while IFS= read -r -u "$fd" line; do
        if [[ -n "${LYNE_ADD_CANCEL:-}" && -f "$LYNE_ADD_CANCEL" ]] && grep -qxF -- "$target" "$LYNE_ADD_CANCEL"; then
            kill "$ffmpeg_pid" 2>/dev/null
            cancelled=1
            break
        fi
        [[ "$line" == out_time_us=* && "${duration:-0}" -gt 0 ]] || continue
        us="${line#out_time_us=}"
        [[ "$us" =~ ^[0-9]+$ ]] || continue
        pct=$((us / 10000 / duration))
        ((pct > 99)) && pct=99
        if ((pct != last)); then
            printf 'progress:%s\t%s\n' "$target" "$pct"
            last=$pct
        fi
    done
    exec {fd}<&-
    wait "$ffmpeg_pid" 2>/dev/null
    if ((!cancelled)) && [[ -s "$tmp" && "$(copy_tag "$tmp")" == "$tag" ]]; then
        mv -f -- "$tmp" "$target"
        return 0
    fi
    rm -f -- "$tmp"
    ((cancelled)) && echo "cancelled:$target" || echo "failed:$target"
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
        local dims
        dims="$(video_size "$src")"
        # Not a video ffprobe can read: it would never play
        if [[ -z "$dims" ]]; then
            echo "failed:$src"
            return
        fi
        # shellcheck disable=SC2086 # "W H"
        size="$(fit_size $dims)"
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
