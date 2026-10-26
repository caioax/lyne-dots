# 043-qmlls-ini.sh - QML support in Neovim: the .qmlls.ini Quickshell fills
#
# Neovim's qmlls finds Quickshell's modules (qs.config, qs.services) through
# a .qmlls.ini next to shell.qml, which Quickshell fills in (a link to the
# folder it generates) each time it starts. The file is gitignored: made
# empty where the nvim package is linked, filled at the shell's next start.

source "$DOTS_DIR/.install/setup/stow.sh"

stow_is_linked nvim || return 0
dir="$HOME/.config/quickshell"
file="$dir/.qmlls.ini"
[[ -d "$dir" ]] || return 0
[[ -e "$file" || -L "$file" ]] && return 0

if ! : >"$file"; then
    echo "   Warning: could not create ~/.config/quickshell/.qmlls.ini (Neovim's QML server won't find Quickshell's modules)"
    return 0
fi
echo "   Created ~/.config/quickshell/.qmlls.ini (Quickshell fills it at its next start, for Neovim's QML server)"
