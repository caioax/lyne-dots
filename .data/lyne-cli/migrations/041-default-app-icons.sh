# 041-default-app-icons.sh - The hidden default-app .desktop files get a name
# and an icon
#
# A terminal app chosen in Settings › System › Apps (Neovim as the editor,
# yazi as the file manager) opens through a hidden lyne-<slot>.desktop, which
# Dolphin's "Open with" lists. It was "nvim (lyne editor)" with no icon; now
# it takes the app's own name and icon. Only the slots that have one are
# written again, so no default the user changed elsewhere moves.

script="$DOTS_DIR/quickshell/.config/quickshell/scripts/default-apps.sh"

if [[ -x "$script" ]] && compgen -G "${XDG_DATA_HOME:-$HOME/.local/share}/applications/lyne-*.desktop" >/dev/null; then
    "$script" refresh && echo "   Gave the default apps' .desktop files their app's name and icon"
fi
