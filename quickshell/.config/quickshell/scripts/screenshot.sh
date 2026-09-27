#!/bin/sh
# Finishes a capture from the Quickshell screenshot overlay: crops the frozen
# monitor, saves and/or copies it, and shows a notification whose buttons
# open, edit, show or delete it (or save it, when it was only copied).
#
# Usage: screenshot.sh ACTION SOURCE GEOMETRY FOLDER NAME [TEMP_FILE...]
#   ACTION     save (file + clipboard) | copy (clipboard only) | edit (satty first)
#   SOURCE     capture of the whole monitor; GEOMETRY  WxH+X+Y in its pixels
#   FOLDER     where to save; empty = <XDG pictures dir>/Screenshots
#   NAME       date(1) format of the file name, without .png
#   TEMP_FILE  captures of every monitor, deleted once cropped

action="$1"
src="$2"
geometry="$3"
folder="$4"
pattern="${5:-Screenshot_%Y-%m-%d_%H-%M-%S}"
shift 5

# Copied-only shots stay here for the notification thumbnail, a day at most
cache="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/screenshots"
mkdir -p "$cache"
find "$cache" -name '*.png' -mmin +1440 -delete 2>/dev/null

if [ -z "$folder" ]; then
    folder="$(xdg-user-dir PICTURES 2>/dev/null)"
    { [ -n "$folder" ] && [ "$folder" != "$HOME" ]; } || folder="$HOME/Pictures"
    folder="$folder/Screenshots"
fi
case "$folder" in
"~" | "~/"*) folder="$HOME${folder#\~}" ;;
esac

name="$(date +"$pattern" | tr '/' '-')"
[ -n "$name" ] || name="$(date +%Y-%m-%d_%H-%M-%S)"

# $1 with -1, -2... before .png while it exists
unique() {
    base="${1%.png}"
    path="$1"
    i=1
    while [ -e "$path" ]; do
        path="$base-$i.png"
        i=$((i + 1))
    done
    printf '%s' "$path"
}

shot="$(unique "$cache/$name.png")"
magick "$src" -crop "$geometry" +repage "$shot"
rm -f "$@"
[ -f "$shot" ] || exit 1

edit() {
    satty --filename "$1" --output-filename "$1" --early-exit --init-tool brush --disable-notifications
}

# Closing satty without saving drops the capture
if [ "$action" = edit ]; then
    edited="$cache/.edit-$$.png"
    satty --filename "$shot" --output-filename "$edited" --early-exit --init-tool brush --disable-notifications
    if [ ! -f "$edited" ]; then
        rm -f "$shot"
        exit 0
    fi
    mv -f "$edited" "$shot"
    action=save
fi

saved=false
if [ "$action" = save ]; then
    mkdir -p "$folder" || exit 1
    out="$(unique "$folder/$name.png")"
    mv "$shot" "$out" || exit 1
    saved=true
else
    out="$shot"
fi

wl-copy --type image/png <"$out"

# The notification comes back (same id) after Edit and Save; it waits for a
# choice while it lives in the history too, up to an hour
# libnotify sends -i as the image, so the capture goes there and the app
# icon as the desktop entry (the shell's notifications take its icon)
notify() {
    set -- -a Screenshot -i "$out" -h string:desktop-entry:org.xfce.screenshooter "$@"
    timeout 1h notify-send -p ${id:+-r "$id"} "$@"
}
id=""
while :; do
    size="$(magick identify -format '%w × %h' "$out" 2>/dev/null)"
    if [ "$saved" = true ]; then
        shown="$(printf '%s' "$out" | sed "s|^$HOME|~|")"
        reply="$(notify \
            -A default=Open -A open=Open -A edit=Edit -A folder=Folder -A delete=Delete \
            "Screenshot saved" "$size · copied to the clipboard
$shown")"
    else
        reply="$(notify \
            -A default=Open -A save=Save -A edit=Edit \
            "Screenshot copied" "$size · not saved to a file")"
    fi
    id="$(printf '%s\n' "$reply" | sed -n 1p)"
    choice="$(printf '%s\n' "$reply" | sed -n 2p)"

    case "$choice" in
    default | open)
        xdg-open "$out" >/dev/null 2>&1 &
        break
        ;;
    edit)
        edit "$out"
        wl-copy --type image/png <"$out"
        ;;
    save)
        mkdir -p "$folder" || break
        dest="$(unique "$folder/$(basename "$out")")"
        mv "$out" "$dest" || break
        out="$dest"
        saved=true
        ;;
    folder)
        # Selects the file where the file manager supports it
        gdbus call --session --dest org.freedesktop.FileManager1 \
            --object-path /org/freedesktop/FileManager1 \
            --method org.freedesktop.FileManager1.ShowItems "['file://$out']" "" >/dev/null 2>&1 ||
            xdg-open "$(dirname "$out")" >/dev/null 2>&1 &
        break
        ;;
    delete)
        rm -f "$out"
        break
        ;;
    *)
        break
        ;;
    esac
done
