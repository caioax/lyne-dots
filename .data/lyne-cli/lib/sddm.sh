#!/bin/bash
# =============================================================================
# sddm.sh - The login screen (lyne-sddm) following the shell theme
# =============================================================================
# lyne-sddm (~/Dev/lyne-sddm, docs/sync.md) creates /var/lib/lyne-sddm owned
# by the user who ran it; the greeter runs as the sddm user and can't read ~,
# so everything it shows is copied there (world-readable, never linked):
#   theme.conf.user     [General] overrides of theme.conf: the applied palette
#                       (~/.cache/lyne/nvim.json, auto mode too),
#                       backgroundOpacity, wallpaper= (absolute path), layout=
#   wallpaper.<ext>     the current wallpaper, its extension kept
#   avatars/<user>.png  the profile picture (Qt reads it by content)
# Every file goes to a temp name inside the dir and is renamed into place, and
# only when its content changed. Shows on the next login, nothing restarts.
# Only lyne-sddm creates and removes the dir, and nothing under /usr is
# written (the theme links its theme.conf.user here). With the sync off the
# file is only reset when lyne-dots wrote it: one written by `lyne-sddm
# --preset/--layout/...` (manual) is left alone, with its wallpaper.
#
#   sddm_state           ok, absent (theme not installed), missing (no dir)
#                        or foreign <owner> (dir not writable)
#   sddm_problem         why it can't sync, with what to run; 1 when it can't
#   sddm_installed       0 when the dir is there and writable
#   sddm_active          0 when SDDM's config selects the lyne theme
#   sddm_mode            who wrote theme.conf.user: synced (lyne-dots),
#                        manual (lyne-sddm) or default (its template)
#   sddm_layouts         "<id> <thumbnail or empty>" per layout of the theme
#                        (layouts/<Name>.qml, id = lowercase name)
#   sddm_apply           sync on: write the overrides; off: sddm_reset when
#                        the file is ours
#   sddm_reset           back to the theme's defaults (Tokyo Night)
#
# Options (state.json): sddm.sync, sddm.layout, wallpaper.current,
# profile.avatar, opacity.background. LYNE_SDDM_OPTIONS ({"sync", "layout",
# "wallpaper", "avatar", "opacity"}) overrides them, as the shell saves
# state.json a moment later. LYNE_SDDM_DIR, LYNE_SDDM_THEME,
# LYNE_SDDM_PALETTE and LYNE_STATE_FILE point it at test files.
# =============================================================================

SDDM_THEME_NAME="lyne"
SDDM_THEME="${LYNE_SDDM_THEME:-/usr/share/sddm/themes/$SDDM_THEME_NAME}"
SDDM_DIR="${LYNE_SDDM_DIR:-/var/lib/lyne-sddm}"
# wallpaper= is written as an absolute path
[[ "$SDDM_DIR" == /* ]] || SDDM_DIR="$PWD/$SDDM_DIR"
SDDM_DIR="${SDDM_DIR%/}"
SDDM_PALETTE="${LYNE_SDDM_PALETTE:-${XDG_CACHE_HOME:-$HOME/.cache}/lyne/nvim.json}"
SDDM_STATE="${LYNE_STATE_FILE:-$DOTS_DIR/quickshell/.config/quickshell/state.json}"
SDDM_AVATAR="$SDDM_DIR/avatars/$(id -un).png"

# First comment line of theme.conf.user, by writer
SDDM_HEADER_SYNCED="# Written by lyne-dots"
SDDM_HEADER_MANUAL="# Written by lyne-sddm"

# The empty file lyne-sddm installs
SDDM_DEFAULT_CONF='[General]
# Overrides of theme.conf, written by lyne-dots (see docs/sync.md).
# Empty: the theme'"'"'s defaults (Tokyo Night).'

sddm_state() {
    if [[ -d "$SDDM_DIR" ]]; then
        if [[ -w "$SDDM_DIR" ]]; then
            echo ok
        else
            echo "foreign $(stat -c %U "$SDDM_DIR")"
        fi
    elif [[ -z "${LYNE_SDDM_DIR:-}" && ! -f "$SDDM_THEME/metadata.desktop" ]]; then
        echo absent
    else
        echo missing
    fi
}

sddm_problem() {
    local state
    state=$(sddm_state)
    case "$state" in
        ok) return 0 ;;
        absent) echo "lyne-sddm isn't installed" ;;
        missing) echo "$SDDM_DIR doesn't exist: run lyne-sddm" ;;
        "foreign $(id -un)") echo "$SDDM_DIR isn't writable: run lyne-sddm" ;;
        *) echo "$SDDM_DIR isn't writable, ${state#foreign } owns it: run lyne-sddm to take it over" ;;
    esac
    return 1
}

sddm_installed() {
    [[ -d "$SDDM_DIR" && -w "$SDDM_DIR" ]]
}

# SDDM reads /usr/lib/sddm/sddm.conf.d, then /etc/sddm.conf.d, then
# /etc/sddm.conf, each in order: the last Current= wins
sddm_active() {
    local current
    current=$(cat /usr/lib/sddm/sddm.conf.d/*.conf /etc/sddm.conf.d/*.conf /etc/sddm.conf 2>/dev/null |
        sed -n 's/^[[:space:]]*Current[[:space:]]*=[[:space:]]*//p' | tail -n1)
    [[ "$current" == "$SDDM_THEME_NAME" ]]
}

sddm_mode() {
    local header
    header=$(grep -m1 '^# Written by ' "$SDDM_DIR/theme.conf.user" 2>/dev/null)
    case "$header" in
        "$SDDM_HEADER_SYNCED"*) echo synced ;;
        "$SDDM_HEADER_MANUAL"*) echo manual ;;
        *) echo default ;;
    esac
}

sddm_layouts() {
    local f name
    for f in "$SDDM_THEME"/layouts/*.qml; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f" .qml)
        [[ "$name" =~ ^[A-Za-z0-9]+$ ]] || continue
        printf '%s %s\n' "${name,,}" "$([[ -f "${f%.qml}.png" ]] && echo "${f%.qml}.png")"
    done
}

# A layout id as the theme reads it: one lowercase word, else center
_sddm_layout_id() {
    local id="${1,,}"
    [[ "$id" =~ ^[a-z0-9]+$ ]] && echo "$id" || echo center
}

# An option from LYNE_SDDM_OPTIONS, else state.json (jq path into it). A key
# in the options wins even when empty (no avatar): "=" marks that it's there
_sddm_option() {
    local key="$1" path="$2" v
    if [[ -n "${LYNE_SDDM_OPTIONS:-}" ]]; then
        v=$(jq -r --arg k "$key" '.[$k] | select(. != null) | "=\(.)"' <<< "$LYNE_SDDM_OPTIONS" 2>/dev/null)
        [[ -n "$v" ]] && { printf '%s\n' "${v#=}"; return; }
    fi
    # select, not //: a false value is kept
    jq -r "$path | select(. != null)" "$SDDM_STATE" 2>/dev/null
}

# stdin to <dest>, world-readable, unless it already holds the same
_sddm_write() {
    local dest="$1" tmp
    tmp=$(mktemp "$SDDM_DIR/.lyne.XXXXXX") || return 1
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

# The [General] section: palette, opacity, wallpaper (absolute path), layout
_sddm_conf() {
    local opacity="$1" wallpaper="$2" layout="$3"
    echo "[General]"
    echo "$SDDM_HEADER_SYNCED (lyne sddm), edits here are lost."
    # Values with a comma are quoted, or SDDM reads them as a list
    jq -r '.palette // {} | to_entries[] | select(.value | type == "string")
        | "\(.key)=\(if (.value | contains(",")) then "\"\(.value)\"" else .value end)"' "$SDDM_PALETTE"
    if [[ "$opacity" =~ ^[0-9.]+$ ]]; then echo "backgroundOpacity=$opacity"; fi
    if [[ -n "$wallpaper" ]]; then echo "wallpaper=$wallpaper"; fi
    echo "layout=$(_sddm_layout_id "$layout")"
}

sddm_apply() {
    sddm_problem >&2 || return 1
    if [[ "$(_sddm_option sync .sddm.sync)" == "false" ]]; then
        # Manual choices (lyne-sddm) and the template stay as they are
        if [[ "$(sddm_mode)" == synced ]]; then sddm_reset; fi
        return
    fi
    [[ -f "$SDDM_PALETTE" ]] || { echo "lyne sddm: no palette at $SDDM_PALETTE yet" >&2; return 1; }

    # Wallpaper: a copy that keeps its extension; copies with another go
    local src ext wallpaper="" f
    src=$(_sddm_option wallpaper .wallpaper.current)
    if [[ -f "$src" && -r "$src" ]]; then
        ext="${src##*.}"
        wallpaper="$SDDM_DIR/wallpaper.${ext,,}"
        _sddm_copy "$src" "$wallpaper" || return 1
    fi
    for f in "$SDDM_DIR"/wallpaper.*; do
        [[ -e "$f" && "$f" != "$wallpaper" ]] && rm -f "$f"
    done

    # Avatar: none chosen leaves the account icon, then a silhouette.
    # avatars/ is lyne-sddm's, but put back if it went (the dir itself never)
    src=$(_sddm_option avatar .profile.avatar)
    if [[ -f "$src" && -r "$src" ]]; then
        mkdir -p "$SDDM_DIR/avatars" && _sddm_copy "$src" "$SDDM_AVATAR" || return 1
    else
        rm -f "$SDDM_AVATAR"
    fi

    local conf
    conf=$(_sddm_conf "$(_sddm_option opacity .opacity.background)" "$wallpaper" \
        "$(_sddm_option layout .sddm.layout)") || return 1
    printf '%s\n' "$conf" | _sddm_write "$SDDM_DIR/theme.conf.user"
}

sddm_reset() {
    sddm_problem >&2 || return 1
    rm -f "$SDDM_DIR"/wallpaper.* "$SDDM_AVATAR"
    printf '%s\n' "$SDDM_DEFAULT_CONF" | _sddm_write "$SDDM_DIR/theme.conf.user"
}
