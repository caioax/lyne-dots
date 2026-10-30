#!/bin/bash
# =============================================================================
# config-defaults.sh - Config files each machine keeps for itself
# =============================================================================
# The apps and the lyne rewrite these all the time: the icon theme
# (Settings › Icons, lyne icons), the default terminal (Settings › System ›
# Apps), qt6ct's, nwg-look's and KDE's own settings. They live in the stow
# packages, where the links reach them, but out of git (.gitignore): a choice
# made on one machine never shows in git status or a commit. The repo keeps
# their defaults in .data/config-defaults/, at the same paths, and a missing
# file is made from its default: before linking (the installer, lyne link),
# after each lyne update and by migration 046. A default that changes later
# reaches existing installs through a migration.
#
#   config_defaults_seed [ROOT]  makes each missing file under ROOT (the
#                                dotfiles, $DOTS_DIR by default) from the
#                                defaults in ROOT/.data/config-defaults;
#                                prints "created <path>" for each. A file
#                                that's there stays as it is
# =============================================================================

# shellcheck disable=SC2034 # read by the tests and the smoke
CONFIG_DEFAULT_FILES=(
    "kde/.config/kdeglobals"
    "theming/.config/qt6ct/qt6ct.conf"
    "theming/.config/qt5ct/qt5ct.conf"
    "theming/.config/gtk-3.0/settings.ini"
    "theming/.config/gtk-4.0/settings.ini"
)

config_defaults_seed() {
    local root="${1:-$DOTS_DIR}" path failed=0
    for path in "${CONFIG_DEFAULT_FILES[@]}"; do
        # A link (even a broken one) is the user's doing: left alone
        [[ -e "$root/$path" || -L "$root/$path" ]] && continue
        if [[ ! -f "$root/.data/config-defaults/$path" ]]; then
            echo "No default for $path in $root/.data/config-defaults" >&2
            failed=1
            continue
        fi
        if mkdir -p "$(dirname "$root/$path")" && cp "$root/.data/config-defaults/$path" "$root/$path"; then
            echo "created $path"
        else
            failed=1
        fi
    done
    return "$failed"
}
