# 046-config-files-out-of-git.sh - kdeglobals, qt6ct/qt5ct.conf and the GTK settings.ini leave git
#
# The icon theme (Settings › Icons), the default terminal and qt6ct's, KDE's
# and nwg-look's own settings rewrote these tracked files: a choice showed in
# git status and could end up in a commit. Each machine keeps its own now
# (.gitignore), made from .data/config-defaults/ when missing (see
# lib/config-defaults.sh). The update that took them out of git kept the
# ones the user changed (they were managed files) and deleted the others:
# those come back from their defaults, the content they had. The shell,
# reloaded after the migrations, writes the icon theme in the state to them
# again.

source "$DOTS_DIR/.data/lyne-cli/lib/config-defaults.sh"

created="$(config_defaults_seed "$DOTS_DIR")"
rc=$?
while IFS= read -r line; do
    [[ -n "$line" ]] && echo "   Created from its default: ${line#created }"
done <<<"$created"
return "$rc"
