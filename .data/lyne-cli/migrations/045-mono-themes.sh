# 045-mono-themes.sh - The Mono and Mono Light themes
#
# Two neutral presets: grey surfaces with no hue, a white (Mono) or near black
# (Mono Light) accent, and faint pastel status and terminal colors. Installs
# their JSON when missing (a theme the user edited stays) and their three
# wallpapers, the contour one also in the root folder (the "all" view).

THEMES_SRC="$DOTS_DIR/.data/themes"
THEMES_DEST="$HOME/.local/themes"
WALLPAPERS_SRC="$DOTS_DIR/.data/wallpapers/themes"
WALLPAPERS_DEST="$HOME/.local/wallpapers"

mkdir -p "$THEMES_DEST"
count=0
for theme in mono mono-light; do
    if [[ ! -f "$THEMES_DEST/$theme.json" ]]; then
        cp "$THEMES_SRC/$theme.json" "$THEMES_DEST/"
        ((count++))
    fi
    mkdir -p "$WALLPAPERS_DEST/themes/$theme"
    cp -n "$WALLPAPERS_SRC/$theme/"lyne-*.jpg "$WALLPAPERS_DEST/themes/$theme/" 2>/dev/null
    cp -n "$WALLPAPERS_SRC/$theme/lyne-$theme-contour.jpg" "$WALLPAPERS_DEST/" 2>/dev/null
done
((count)) && echo "   Added the Mono and Mono Light themes"
true
