# managed-files.sh - Tracked files that the lyne or the apps rewrite
#
# They're in git, but a change to one isn't the user's work: lyne update and
# Settings › About don't count them as uncommitted changes, and the update
# puts each back after the pull by its policy:
#   local  the user's copy always stays
#   repo   the repo's copy wins when the update changes the file (the user's
#          goes to $MANAGED_BACKUP_DIR); otherwise the user's stays
#
# Usage: source this file (expects $DOTS_DIR to be set)

local MANAGED_BACKUP_DIR="$HOME/.local/share/lyne/backup"

# path:policy
local MANAGED_FILES=(
    # :Lazy update rewrites it; the versions pinned in the repo still reach
    # the user when the repo's lock changes
    "nvim/.config/nvim/lazy-lock.json:repo"
    # Default terminal (Settings › System › Apps) and KDE apps write to it
    "kde/.config/kdeglobals:local"
    # Written by ThemeService on every theme change and shell start
    "kitty/.config/kitty/current-theme.conf:local"
)

# Pathspecs that leave the managed files out of a git status/stash
local MANAGED_EXCLUDES=()
local _entry
for _entry in "${MANAGED_FILES[@]}"; do
    MANAGED_EXCLUDES+=(":(exclude)${_entry%:*}")
done

# Saved copies, as path:policy:copy, filled by managed_save
local MANAGED_SAVED=()
local MANAGED_SAVE_DIR=""

# Copies the managed files that differ from HEAD aside and checks them out,
# so the pull (and a stash or discard) sees a clean tree
managed_save() {
    local entry path
    for entry in "${MANAGED_FILES[@]}"; do
        path="${entry%:*}"
        [[ -f "$DOTS_DIR/$path" ]] || continue
        git -C "$DOTS_DIR" diff --quiet HEAD -- "$path" 2>/dev/null && continue
        if [[ -z "$MANAGED_SAVE_DIR" ]]; then
            MANAGED_SAVE_DIR="$(mktemp -d)" || return 1
        fi
        local copy="$MANAGED_SAVE_DIR/${#MANAGED_SAVED[@]}"
        cp "$DOTS_DIR/$path" "$copy" || return 1
        git -C "$DOTS_DIR" checkout HEAD -- "$path" || return 1
        MANAGED_SAVED+=("$entry:$copy")
    done
}

# Whether $1 changed between the commits $2 and $3 (HEAD by default)
managed_changed() {
    ! git -C "$DOTS_DIR" diff --quiet "$2" "${3:-HEAD}" -- "$1" 2>/dev/null
}

# Puts the saved copies back after the pull. $1: the commit before it (the
# repo's version wins only when it changed since)
managed_restore() {
    local old_head="$1" saved path policy copy
    for saved in "${MANAGED_SAVED[@]}"; do
        copy="${saved##*:}"
        path="${saved%:*}"
        policy="${path##*:}"
        path="${path%:*}"
        if [[ "$policy" == repo ]] && managed_changed "$path" "$old_head"; then
            local backup="$MANAGED_BACKUP_DIR/$(basename "$path").$(date +%F-%H%M%S)"
            mkdir -p "$MANAGED_BACKUP_DIR" && cp "$copy" "$backup"
            echo "   $path: the update brings a new version, yours is in $backup"
        else
            mkdir -p "$(dirname "$DOTS_DIR/$path")"
            cp "$copy" "$DOTS_DIR/$path"
        fi
    done
    MANAGED_SAVED=()
    [[ -n "$MANAGED_SAVE_DIR" ]] && rm -rf "$MANAGED_SAVE_DIR"
    MANAGED_SAVE_DIR=""
}
