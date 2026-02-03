# 002-themes-to-local.sh - Move themes to ~/.local/themes/
#
# Theme JSON files were previously read directly from the git repo
# at ~/.lyne-dots/.data/themes/. They now live in ~/.local/themes/
# (gitignored, same pattern as wallpapers) so users can freely
# create/edit themes without git conflicts.

THEMES_SRC="$DOTS_DIR/.data/themes"
THEMES_DEST="$HOME/.local/themes"

mkdir -p "$THEMES_DEST"

# Only copy if destination has no JSON files yet
file_count=$(find "$THEMES_DEST" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l)

if [[ "$file_count" -eq 0 ]]; then
    cp -n "$THEMES_SRC"/*.json "$THEMES_DEST/" 2>/dev/null
    echo "   Themes copied to ~/.local/themes/"
else
    echo "   Themes already exist in ~/.local/themes/, skipping"
fi
