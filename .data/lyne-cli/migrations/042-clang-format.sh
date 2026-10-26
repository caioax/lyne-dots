# 042-clang-format.sh - ~/.clang-format comes with the nvim package
#
# The C/C++ style (clangd formats with it on save) is nvim/.clang-format now.
# lyne update doesn't link the packages again: where nvim is linked, a
# ~/.clang-format of the user's goes to the backup folder (lyne unlink nvim
# brings it back) and the package is linked again.

source "$DOTS_DIR/.install/setup/stow.sh"

stow_is_linked nvim || return 0
target="$HOME/.clang-format"
is_own_link "$target" && return 0

# Moved back if stow fails (a ~/.config/nvim it doesn't own): only a warning,
# so the migrations after this one still run
moved=""
if [[ -e "$target" || -L "$target" ]]; then
    backup="${LYNE_BACKUP_DIR:-$HOME/.lyne-dots-backup/$(date +%Y%m%d-%H%M%S)}"
    if ! { mkdir -p "$backup" && mv "$target" "$backup/"; }; then
        echo "   Error: could not move ~/.clang-format to $backup"
        return 1
    fi
    moved="$backup/.clang-format"
fi
if ! stow -d "$DOTS_DIR" -t "$HOME" -R nvim 2>&1; then
    [[ -n "$moved" ]] && mv "$moved" "$target" && rmdir "$backup" 2>/dev/null
    echo "   Warning: could not link ~/.clang-format; lyne link nvim tries again"
    return 0
fi
[[ -n "$moved" ]] && echo "   Your ~/.clang-format moved to the backup: ${backup/#$HOME/\~}"
echo "   Linked ~/.clang-format (C/C++ style)"
