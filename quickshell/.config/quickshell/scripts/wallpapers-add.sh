#!/usr/bin/env bash
# Copies images into the wallpaper library (WallpaperService: Add and Add
# folder in Settings › Wallpaper).
#
#   wallpapers-add.sh DEST PATH...
#
# Each PATH is an image, or a folder searched for images in its subfolders
# too (hidden ones left out). Images are png, jpg, jpeg, webp and gif, in any
# case. A name already in DEST gets -1, -2... unless that file is the same
# image, which is skipped; so are images already inside DEST (adding the
# library itself, or its themes/ folder). Prints one line per image:
#   added:<the copy in DEST>
#   skipped:<PATH's image>

set -uo pipefail

dest="${1:?usage: wallpapers-add.sh DEST PATH...}"
shift
mkdir -p "$dest" || exit 1
real_dest="$(realpath "$dest")"

is_image() {
    local ext="${1##*.}"
    case "${ext,,}" in
    png | jpg | jpeg | webp | gif) return 0 ;;
    esac
    return 1
}

copy_one() {
    local src="$1" real name base ext target n=1
    real="$(realpath "$src")"
    if [[ "$real" == "$real_dest"/* ]]; then
        echo "skipped:$src"
        return
    fi
    name="${src##*/}"
    base="${name%.*}"
    ext="${name##*.}"
    target="$dest/$name"
    while [[ -e "$target" ]]; do
        if cmp -s -- "$src" "$target"; then
            echo "skipped:$src"
            return
        fi
        target="$dest/$base-$n.$ext"
        n=$((n + 1))
    done
    cp -- "$src" "$target" && echo "added:$target"
}

for path in "$@"; do
    if [[ -d "$path" ]]; then
        while IFS= read -r -d '' file; do
            is_image "$file" && copy_one "$file"
        done < <(find "$path" -mindepth 1 -name '.*' -prune -o -type f -print0 | sort -z)
    elif [[ -f "$path" ]] && is_image "$path"; then
        copy_one "$path"
    fi
done
exit 0
