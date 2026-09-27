# install-icons.sh - Copy the lyne-dots logo into the user's hicolor icon theme
#
# Copied, not stowed: stow would fold hicolor/<size> into links to the repo,
# and apps that install user icons would then write into ~/.lyne-dots.
#
# Usage: source this file (expects $DOTS_DIR to be set)

local ICONS_SRC="$DOTS_DIR/.data/assets/logo/hicolor"
local ICONS_DEST="$HOME/.local/share/icons/hicolor"

mkdir -p "$ICONS_DEST"
cp -r "$ICONS_SRC/." "$ICONS_DEST/"

# A stale cache hides new icons from GTK apps
if [[ -f "$ICONS_DEST/icon-theme.cache" ]] && command -v gtk-update-icon-cache &>/dev/null; then
    gtk-update-icon-cache -f -t -q "$ICONS_DEST"
fi
