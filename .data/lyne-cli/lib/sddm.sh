#!/bin/bash
# =============================================================================
# sddm.sh - The login screen (lyne-sddm) following the shell theme
# =============================================================================
# lyne-sddm (~/Dev/lyne-sddm, docs/sync.md) leaves a user/ dir owned by the
# user in its theme folder; the greeter runs as the sddm user and can't read
# ~, so everything it shows is copied there (world-readable, never linked):
#   user/theme.conf.user     [General] overrides of theme.conf: the applied
#                            palette (~/.cache/lyne/nvim.json, auto mode
#                            too), backgroundOpacity, wallpaper=
#   user/wallpaper.<ext>     the current wallpaper, its extension kept
#   user/avatars/<user>.png  the profile picture (Qt reads it by content)
# Every file goes to a temp name inside user/ and is renamed into place, and
# only when its content changed. Shows on the next login, nothing restarts.
#
#   sddm_installed       0 when the theme's user/ dir is there and writable
#   sddm_active          0 when SDDM's config selects the lyne theme
#   sddm_apply           sync on: write the overrides; off: sddm_reset
#   sddm_reset           back to the theme's defaults (Tokyo Night)
#
# Options (state.json): sddm.sync, wallpaper.current, profile.avatar,
# opacity.background. LYNE_SDDM_OPTIONS ({"sync", "wallpaper", "avatar",
# "opacity"}) overrides them, as the shell saves state.json a moment later.
# LYNE_SDDM_THEME, LYNE_SDDM_PALETTE and LYNE_STATE_FILE point it at test
# files.
# =============================================================================

SDDM_THEME="${LYNE_SDDM_THEME:-/usr/share/sddm/themes/lyne}"
SDDM_USER_DIR="$SDDM_THEME/user"
SDDM_PALETTE="${LYNE_SDDM_PALETTE:-${XDG_CACHE_HOME:-$HOME/.cache}/lyne/nvim.json}"
SDDM_STATE="${LYNE_STATE_FILE:-$DOTS_DIR/quickshell/.config/quickshell/state.json}"
SDDM_AVATAR="$SDDM_USER_DIR/avatars/$(id -un).png"

# The empty file lyne-sddm installs
SDDM_DEFAULT_CONF='[General]
# Overrides of theme.conf, written by lyne-dots (see docs/sync.md).
# Empty: the theme'"'"'s defaults (Tokyo Night).'

sddm_installed() {
    [[ -d "$SDDM_USER_DIR" && -w "$SDDM_USER_DIR" ]]
}

# SDDM reads /usr/lib/sddm/sddm.conf.d, then /etc/sddm.conf.d, then
# /etc/sddm.conf, each in order: the last Current= wins
sddm_active() {
    local current
    current=$(cat /usr/lib/sddm/sddm.conf.d/*.conf /etc/sddm.conf.d/*.conf /etc/sddm.conf 2>/dev/null |
        sed -n 's/^[[:space:]]*Current[[:space:]]*=[[:space:]]*//p' | tail -n1)
    [[ "$current" == "$(basename "$SDDM_THEME")" ]]
}

# An option from LYNE_SDDM_OPTIONS, else state.json (jq path into it)
_sddm_option() {
    local key="$1" path="$2" v
    if [[ -n "${LYNE_SDDM_OPTIONS:-}" ]]; then
        v=$(jq -r --arg k "$key" '.[$k] | select(. != null)' <<< "$LYNE_SDDM_OPTIONS" 2>/dev/null)
        [[ -n "$v" ]] && { printf '%s\n' "$v"; return; }
    fi
    # select, not //: a false value is kept
    jq -r "$path | select(. != null)" "$SDDM_STATE" 2>/dev/null
}

# stdin to <dest>, world-readable, unless it already holds the same
_sddm_write() {
    local dest="$1" tmp
    tmp=$(mktemp "$SDDM_USER_DIR/.lyne.XXXXXX") || return 1
    cat > "$tmp"
    if cmp -s "$tmp" "$dest"; then
        rm -f "$tmp"
        return 0
    fi
    chmod 644 "$tmp" && mv -f "$tmp" "$dest"
}

_sddm_copy() {
    local src="$1" dest="$2"
    cmp -s "$src" "$dest" && return 0
    _sddm_write "$dest" < "$src"
}

# The [General] section: palette, opacity, wallpaper (relative to the theme)
_sddm_conf() {
    local opacity="$1" wallpaper="$2"
    echo "[General]"
    echo "# Written by lyne-dots (lyne sddm), edits here are lost."
    # Values with a comma are quoted, or SDDM reads them as a list
    jq -r '.palette // {} | to_entries[] | select(.value | type == "string")
        | "\(.key)=\(if (.value | contains(",")) then "\"\(.value)\"" else .value end)"' "$SDDM_PALETTE"
    [[ "$opacity" =~ ^[0-9.]+$ ]] && echo "backgroundOpacity=$opacity"
    [[ -n "$wallpaper" ]] && echo "wallpaper=$wallpaper"
}

sddm_apply() {
    sddm_installed || return 0
    [[ "$(_sddm_option sync .sddm.sync)" == "false" ]] && { sddm_reset; return; }
    [[ -f "$SDDM_PALETTE" ]] || { echo "lyne sddm: no palette at $SDDM_PALETTE yet" >&2; return 1; }

    # Wallpaper: a copy that keeps its extension; copies with another go
    local src ext rel="" f
    src=$(_sddm_option wallpaper .wallpaper.current)
    if [[ -f "$src" && -r "$src" ]]; then
        ext="${src##*.}"
        ext="${ext,,}"
        rel="user/wallpaper.$ext"
        _sddm_copy "$src" "$SDDM_THEME/$rel" || return 1
    fi
    for f in "$SDDM_USER_DIR"/wallpaper.*; do
        [[ -e "$f" && "$f" != "$SDDM_THEME/$rel" ]] && rm -f "$f"
    done

    # Avatar: none chosen leaves the account icon, then a silhouette
    src=$(_sddm_option avatar .profile.avatar)
    if [[ -f "$src" && -r "$src" ]]; then
        mkdir -p "$(dirname "$SDDM_AVATAR")" && _sddm_copy "$src" "$SDDM_AVATAR" || return 1
    else
        rm -f "$SDDM_AVATAR"
    fi

    local conf
    conf=$(_sddm_conf "$(_sddm_option opacity .opacity.background)" "$rel") || return 1
    printf '%s\n' "$conf" | _sddm_write "$SDDM_USER_DIR/theme.conf.user"
}

sddm_reset() {
    sddm_installed || return 0
    rm -f "$SDDM_USER_DIR"/wallpaper.* "$SDDM_AVATAR"
    printf '%s\n' "$SDDM_DEFAULT_CONF" | _sddm_write "$SDDM_USER_DIR/theme.conf.user"
}
