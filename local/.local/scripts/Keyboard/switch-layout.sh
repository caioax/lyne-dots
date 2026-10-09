#!/usr/bin/env bash
# Switches the keyboard typed on last, and the others with the same layouts,
# to the next or previous layout (next | prev). Keyboards with layouts of
# their own (Settings › Hyprland › Keyboard › devices) keep theirs, as with
# the shell's layout switcher (KeyboardService.switchLayout)

direction=${1:-next}
case "$direction" in
next | prev) ;;
*)
    echo "usage: $0 next|prev" >&2
    exit 1
    ;;
esac

names=$(hyprctl devices -j | jq -r '
    .keyboards as $all
    | ($all | map(select(.main)) | first) as $main
    | if $main == null then empty
      else $all[] | select(.layout == $main.layout and .variant == $main.variant) | .name end')
[ -z "$names" ] && exit 0

commands=()
while IFS= read -r name; do
    commands+=("switchxkblayout $name $direction")
done <<<"$names"
batch=$(printf '%s ; ' "${commands[@]}")
hyprctl --batch "${batch% ; }" >/dev/null
