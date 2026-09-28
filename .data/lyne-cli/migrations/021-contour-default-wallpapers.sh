# 021-contour-default-wallpapers.sh - The contour scene is the theme default
#
# Migration 020 made each theme's lake wallpaper its default; the default is
# now the contour one. Themes still on their lake wallpaper switch to contour
# (any other choice is kept), and the contour files join the root folder
# (the "all" view).

WALLPAPERS_DEST="$HOME/.local/wallpapers"
THEMES_DEST="$HOME/.local/themes"

switched=0
for json in "$THEMES_DEST"/*.json; do
    [[ -f "$json" ]] || continue
    theme="$(basename "$json" .json)"
    new="themes/$theme/lyne-$theme-contour.jpg"
    [[ -f "$WALLPAPERS_DEST/$new" ]] || continue
    cp -n "$WALLPAPERS_DEST/$new" "$WALLPAPERS_DEST/" 2>/dev/null
    if [[ "$(jq -r '.wallpaper // ""' "$json")" == "themes/$theme/lyne-$theme-lake.jpg" ]]; then
        tmp="$(mktemp)"
        jq --arg w "$new" '.wallpaper = $w' "$json" > "$tmp" && mv "$tmp" "$json"
        ((switched++))
    fi
done
echo "   $switched theme(s) now use the contour wallpaper"
