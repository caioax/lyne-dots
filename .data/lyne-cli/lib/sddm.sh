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
#   sddm_dm              the display manager systemd starts (sddm, gdm...)
#   sddm_install [ch]    build and install the lyne-sddm-git package for the
#     [tty]              channel (stable: newest release tag), then run
#                        lyne-sddm (sync dir + theme selected); a script
#                        install is replaced when the user agrees
#   sddm_target <ch>     "<ref> <sha>" the channel builds: the newest vX.Y.Z
#                        tag (stable, main when there's none) or main
#   sddm_update_check    SDDM_UPD_* for the channel: none (not a package),
#     <ch>               unknown (repo unreachable), current, ahead (a
#                        build past the stable release: never downgraded)
#                        or available
#   sddm_build <ref>     makepkg from the clone, a tag or main (""); with
#     [replace]          replace=1 the script install's theme files go
#                        only once the package is built
#   sddm_offer_update    lyne update: a newer build for the channel, asked
#     <ch> [tty]         before rebuilding (only with a terminal: sudo)
#
# Options (state.json): sddm.sync, sddm.layout, wallpaper.current,
# profile.avatar, opacity.background. LYNE_SDDM_OPTIONS ({"sync", "layout",
# "wallpaper", "avatar", "opacity"}) overrides them, as the shell saves
# state.json a moment later. LYNE_SDDM_DIR, LYNE_SDDM_THEME,
# LYNE_SDDM_PALETTE, LYNE_STATE_FILE, LYNE_DM_LINK, LYNE_SDDM_REPO and
# LYNE_SDDM_BUILD_DIR point it at test files.
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

# The display-manager.service link systemctl enable writes
SDDM_DM_LINK="${LYNE_DM_LINK:-/etc/systemd/system/display-manager.service}"
# lyne-sddm is built from its repo (the AUR was down for weeks in 2026-11);
# the clone stays for the next build
SDDM_REPO="${LYNE_SDDM_REPO:-https://github.com/caioax/lyne-sddm.git}"
SDDM_BUILD_DIR="${LYNE_SDDM_BUILD_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/lyne/lyne-sddm}"

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

sddm_dm() {
    [[ -e "$SDDM_DM_LINK" ]] || return 0
    basename "$(readlink -f "$SDDM_DM_LINK")" .service
}

# The theme files from the old script install (not pacman's): the package
# would clash with them
_sddm_script_install() {
    [[ -f "$SDDM_THEME/metadata.desktop" ]] &&
        ! pacman -Qqo "$SDDM_THEME/metadata.desktop" &>/dev/null
}

# Build lyne-sddm-git from its repo with makepkg (deps through pacman), then
# lyne-sddm creates the sync dir and selects the theme. Asks for sudo; never
# restarts SDDM. Once the AUR answers again this can become yay/paru
# Newest vX.Y.Z tag (stable) or main, from the repo without cloning it.
# Only annotated tags count (they have a peeled ^{} line): the package's
# pkgver comes from git describe, which skips lightweight ones
sddm_target() {
    local channel="$1" refs tag
    refs=$(GIT_TERMINAL_PROMPT=0 timeout 10 git ls-remote "$SDDM_REPO" HEAD 'refs/tags/v*' 2>/dev/null) || return 1
    [[ -n "$refs" ]] || return 1
    if [[ "$channel" == stable ]]; then
        tag=$(awk '$2 ~ /^refs\/tags\/v[0-9]+\.[0-9]+\.[0-9]+\^\{\}$/ { t = $2; sub(/^refs\/tags\//, "", t); sub(/\^\{\}$/, "", t); print t }' <<<"$refs" |
            sort -V | tail -n1)
        if [[ -n "$tag" ]]; then
            echo "$tag $(awk -v r="refs/tags/$tag^{}" '$2 == r { print $1 }' <<<"$refs")"
            return 0
        fi
    fi
    echo "main $(awk '$2 == "HEAD" { print $1 }' <<<"$refs")"
}

# The commit the installed package was built from (pkgver ...g<hash>, at
# least 7 characters), empty without the package
_sddm_installed_version() { pacman -Q lyne-sddm-git 2>/dev/null | awk '{ print $2 }'; }

# shellcheck disable=SC2034 # read by lyne update
SDDM_UPD_STATE="" SDDM_UPD_VERSION="" SDDM_UPD_HASH="" SDDM_UPD_REF="" SDDM_UPD_SHA=""
# shellcheck disable=SC2034
sddm_update_check() {
    SDDM_UPD_STATE=none SDDM_UPD_REF="" SDDM_UPD_SHA=""
    SDDM_UPD_VERSION=$(_sddm_installed_version)
    SDDM_UPD_HASH=$(sed -n 's/.*\.g\([0-9a-f]\{7,\}\)-[0-9]*$/\1/p' <<<"$SDDM_UPD_VERSION")
    [[ -n "$SDDM_UPD_HASH" ]] || return 0
    _sddm_script_install && return 0
    local target
    if ! target=$(sddm_target "$1"); then
        SDDM_UPD_STATE=unknown
        return 0
    fi
    SDDM_UPD_REF=${target%% *} SDDM_UPD_SHA=${target#* }
    # The installed hash is a prefix of the full sha (git lengthens it when
    # 7 characters are ambiguous)
    if [[ -n "$SDDM_UPD_SHA" && "$SDDM_UPD_SHA" == "$SDDM_UPD_HASH"* ]]; then
        SDDM_UPD_STATE=current
    elif [[ "$SDDM_UPD_REF" != main ]] &&
        (($(vercmp "${SDDM_UPD_REF#v}.r0" "${SDDM_UPD_VERSION%-*}") <= 0)); then
        # From latest, past the release: kept until a newer release, as
        # lyne-dots itself never goes back
        SDDM_UPD_STATE=ahead
    else
        SDDM_UPD_STATE=available
    fi
}

# makepkg from the clone, kept on main: its PKGBUILD builds the release
# through LYNE_SDDM_REF (a tag checked out in the clone would bring that
# tag's PKGBUILD, which may not know the variable)
sddm_build() {
    local ref="$1" replace="${2:-0}"
    echo ":: Build tools (git, base-devel)"
    sudo pacman -S --needed --noconfirm git base-devel || return 1
    if [[ -d "$SDDM_BUILD_DIR/.git" ]]; then
        echo ":: Updating $SDDM_BUILD_DIR"
        # -f: makepkg rewrote pkgver= in the clone's PKGBUILD, nothing to keep
        GIT_TERMINAL_PROMPT=0 timeout 300 git -C "$SDDM_BUILD_DIR" fetch -q --depth 1 origin main &&
            git -C "$SDDM_BUILD_DIR" checkout -q -f -B main FETCH_HEAD || return 1
    else
        echo ":: Cloning $SDDM_REPO"
        rm -rf "$SDDM_BUILD_DIR"
        mkdir -p "$(dirname "$SDDM_BUILD_DIR")" || return 1
        GIT_TERMINAL_PROMPT=0 timeout 300 git clone -q --depth 1 --branch main "$SDDM_REPO" "$SDDM_BUILD_DIR" || return 1
    fi
    echo ":: Building and installing lyne-sddm-git ${ref:-from main} (makepkg)"
    if ((replace)); then
        # Built first, so a failed build leaves the working login screen
        (cd "$SDDM_BUILD_DIR" && LYNE_SDDM_REF="$ref" makepkg -scf --noconfirm) || return 1
        local pkg
        pkg=$(compgen -G "$SDDM_BUILD_DIR/lyne-sddm-git-*.pkg.tar.*" | tail -n1)
        [[ -n "$pkg" ]] || { echo "lyne-sddm: makepkg left no package" >&2; return 1; }
        # Set aside, not deleted, until pacman installed the package: a failed
        # install puts the working theme back
        echo ":: Replacing the script install's theme files with the package"
        local backup
        backup="$(dirname "$SDDM_THEME")/.$(basename "$SDDM_THEME")-script-bak"
        sudo rm -rf -- "$backup" && sudo mv -- "$SDDM_THEME" "$backup" || return 1
        if ! sudo pacman -U --noconfirm "$pkg"; then
            sudo mv -- "$backup" "$SDDM_THEME"
            echo "lyne-sddm: the package didn't install, the script install is back" >&2
            return 1
        fi
        sudo rm -rf -- "$backup"
    else
        (cd "$SDDM_BUILD_DIR" && LYNE_SDDM_REF="$ref" makepkg -sicf --noconfirm --needed) || return 1
    fi
    # Installed: the package file would pile up, one per version (makepkg's
    # git mirror stays, for the next fetch)
    rm -f "$SDDM_BUILD_DIR"/*.pkg.tar.*
}

# Build lyne-sddm-git for the channel (stable when not given), then
# lyne-sddm creates the sync dir and selects the theme. Asks for sudo; never
# restarts SDDM. Once the AUR answers again this can become yay/paru
sddm_install() {
    local channel="${1:-stable}" tty="${2:-}" target ref="" replace=0
    [[ -n "$tty" ]] || { [[ -t 0 ]] && tty=1 || tty=0; }
    if _sddm_script_install; then
        # Its theme files would clash with the package's. /var/lib/lyne-sddm
        # and lyne.conf stay: the login screen keeps its look and choices
        echo "lyne-sddm was installed by its install.sh. The package replaces its theme"
        echo "files and keeps your login screen settings; lyne update then keeps it up to date."
        local answer=""
        ((tty)) && read -rp "Replace it with the package? [Y/n] " answer
        if ((!tty)) || [[ "$answer" =~ ^[Nn] ]]; then
            echo "lyne-sddm: left as it is (git pull and ./install.sh in its repo update it)" >&2
            return 1
        fi
        replace=1
    fi
    target=$(sddm_target "$channel") || { echo "lyne-sddm: $SDDM_REPO isn't reachable" >&2; return 1; }
    [[ "${target%% *}" == main ]] || ref=${target%% *}
    sddm_build "$ref" "$replace" || return 1
    echo ":: Setting it up (lyne-sddm)"
    lyne-sddm || return 1
}

# lyne update's part: says what's new and asks before rebuilding. Without a
# terminal (tty 0) only says how to: makepkg's sudo would fail there, and
# failed sudo attempts count towards the account lockout
sddm_offer_update() {
    local channel="$1" tty="${2:-}"
    [[ -n "$tty" ]] || { [[ -t 0 ]] && tty=1 || tty=0; }
    sddm_update_check "$channel"
    [[ "$SDDM_UPD_STATE" == available ]] || return 0
    echo -e "\e[1;34m:: Login screen (lyne-sddm)\e[0m"
    echo "   New version: $SDDM_UPD_HASH -> ${SDDM_UPD_SHA:0:7} ($SDDM_UPD_REF)"
    if ((!tty)); then
        echo "   Run lyne update in a terminal (or lyne sddm install) to rebuild it"
        return 0
    fi
    local answer="" ref=""
    read -rp "   Rebuild it now? [Y/n] " answer
    [[ "$answer" =~ ^[Nn] ]] && return 0
    [[ "$SDDM_UPD_REF" == main ]] || ref="$SDDM_UPD_REF"
    if sddm_build "$ref"; then
        echo "   lyne-sddm updated (shows on the next login)"
    else
        echo "lyne update: lyne-sddm wasn't rebuilt (see above); lyne sddm install tries again"
    fi
    return 0
}
