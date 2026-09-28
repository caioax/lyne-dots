# 020-lyne-wallpapers.sh - New default theme wallpapers
#
# Every preset theme now ships three generated lyne-dots wallpapers in 4K
# (lake, waves, contour; see .data/wallpapers/generator/generate.py), and the
# contour one is the theme's wallpaper. The old theme-*.jpg defaults were
# removed from the repo; the copies already in ~/.local/wallpapers stay.
# A theme only switches to the new wallpaper while it still uses its old
# default: wallpapers the user picked for a theme are kept.

WALLPAPERS_SRC="$DOTS_DIR/.data/wallpapers/themes"
WALLPAPERS_DEST="$HOME/.local/wallpapers"
THEMES_DEST="$HOME/.local/themes"

if [[ ! -d "$WALLPAPERS_SRC" ]]; then
    echo "   $WALLPAPERS_SRC not found, skipping"
    return 0
fi

count=0
for dir in "$WALLPAPERS_SRC"/*/; do
    theme="$(basename "$dir")"
    mkdir -p "$WALLPAPERS_DEST/themes/$theme"
    for file in "$dir"lyne-*.jpg; do
        [[ -f "$file" ]] || continue
        if [[ ! -f "$WALLPAPERS_DEST/themes/$theme/$(basename "$file")" ]]; then
            cp "$file" "$WALLPAPERS_DEST/themes/$theme/"
            ((count++))
        fi
    done
    # The theme's default also goes to the root folder (the "all" view)
    cp -n "$dir"lyne-*-contour.jpg "$WALLPAPERS_DEST/" 2>/dev/null
done
echo "   $count new theme wallpaper(s) added to ~/.local/wallpapers/themes/"

switched=0
for dir in "$WALLPAPERS_SRC"/*/; do
    theme="$(basename "$dir")"
    json="$THEMES_DEST/$theme.json"
    new="themes/$theme/lyne-$theme-contour.jpg"
    [[ -f "$json" && -f "$WALLPAPERS_DEST/$new" ]] || continue
    current="$(jq -r '.wallpaper // ""' "$json")"
    # Old defaults were themes/<theme>/theme-*.jpg|png
    if [[ -z "$current" || "$(basename "$current")" == theme-* ]]; then
        tmp="$(mktemp)"
        jq --arg w "$new" '.wallpaper = $w' "$json" > "$tmp" && mv "$tmp" "$json"
        ((switched++))
    fi
done
echo "   $switched theme(s) now use the new lyne-dots wallpaper"
