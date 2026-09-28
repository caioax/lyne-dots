# 019-default-apps.sh - Default apps for xdg-open, Dolphin and text files
#
# The terminal, file manager, browser and editor are now chosen in
# Settings › System › Apps and used by the whole shell (launcher, keybinds,
# lyne update). This sets them as the system defaults once: folders and
# links open with them through xdg-open, Dolphin's "Open terminal here" uses
# the terminal, and plain text files open in the editor (Neovim in the
# terminal, instead of whatever app claimed text/plain).
# The old launcher.terminal setting was moved to apps.terminal by the state
# sync that runs before migrations.

script="$DOTS_DIR/quickshell/.config/quickshell/scripts/default-apps.sh"

if [[ -x "$script" ]] && command -v xdg-mime &>/dev/null; then
    "$script" apply-all && echo "   Set the default apps for folders, links and text files"
else
    echo "   xdg-mime not found, skipping (set them in Settings › System › Apps)"
fi
