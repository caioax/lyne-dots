#!/bin/bash
# =============================================================================
# cursor.sh - The mouse cursor theme
# =============================================================================
# A cursor theme is a folder of an icon directory with xcursor files in
# cursors/ (what every toolkit and XWayland read); some also ship hyprcursor
# files (manifest.hl or manifest.toml), which Hyprland prefers. Themes with
# only hyprcursor files are left out: apps would fall back to another theme.
#
#   cursor_dirs                the icon directories, in lookup order (the
#                              user's first, like libXcursor and GTK)
#   cursor_themes              one line per theme, sorted by name:
#                              id<TAB>name<TAB>folder<TAB>hyprcursor (0|1)
#                              <TAB>user (0|1: in the user's own folders, so
#                              it can be removed); the first folder of an id
#                              wins
#   cursor_json                the same as a JSON array of
#                              { id, name, path, hyprcursor, removable }
#   cursor_has <id>            0 when the theme is installed
#   cursor_install_dir         where themes are installed:
#                              ~/.local/share/icons (Flatpak apps see it too)
#   cursor_install <archive|folder>
#                              install the cursor themes inside (an archive
#                              bsdtar opens: .tar.*, .zip, .7z), replacing
#                              the user's own copy of the same id; prints
#                              "installed <id>" or "updated <id>" per theme.
#                              Fails with 2 when it can't be read, 3 when
#                              there's no cursor theme in it, 4 when there
#                              are only hyprcursor ones
#   cursor_remove <id>         delete a theme from the user's folders; 2
#                              when it isn't installed, 3 for a system theme
#                              (a package's)
#   cursor_apply <id> <size>   switch to it now: the running Hyprland
#                              (hyprctl setcursor), GSettings (GTK) and the
#                              "default" theme apps without a setting
#                              inherit (~/.icons/default/index.theme). The
#                              XCURSOR_* variables new apps start with come
#                              from Hyprland's hl.env (hypr/local/settings.lua,
#                              written by the shell) and, at login, from
#                              ~/.config/uwsm/env-hyprland; both read the state
#
# LYNE_ICON_DIRS (colon separated) replaces the icon directories in tests.
# =============================================================================

# shellcheck disable=SC2034 # read by commands/cursor.sh
CURSOR_DEFAULT_THEME="Bibata-Modern-Classic"
CURSOR_DEFAULT_SIZE=24

cursor_dirs() {
    if [[ -n "${LYNE_ICON_DIRS+x}" ]]; then
        tr ':' '\n' <<<"$LYNE_ICON_DIRS" | grep -v '^$'
        return
    fi
    local data_dirs dir
    {
        echo "${XDG_DATA_HOME:-$HOME/.local/share}/icons"
        echo "$HOME/.icons"
        IFS=: read -ra data_dirs <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
        for dir in "${data_dirs[@]}"; do
            [[ -n "$dir" ]] && echo "${dir%/}/icons"
        done
    } | awk '!seen[$0]++'
}

cursor_install_dir() {
    echo "${XDG_DATA_HOME:-$HOME/.local/share}/icons"
}

# A theme folder in the user's own icon directories
_cursor_is_user() {
    local parent="${1%/*}"
    [[ "$parent" == "$(cursor_install_dir)" || "$parent" == "$HOME/.icons" ]]
}

# The theme's own name (index.theme's first Name=), else its folder name
_cursor_name() {
    local name=""
    [[ -f "$1/index.theme" ]] && name="$(sed -n 's/^Name[[:space:]]*=[[:space:]]*//p' "$1/index.theme" | head -1)"
    name="${name%$'\r'}"
    printf '%s\n' "${name:-${1##*/}}"
}

_cursor_scan() {
    local root theme id
    declare -A seen=()
    while IFS= read -r root; do
        [[ -d "$root" ]] || continue
        for theme in "$root"/*/; do
            theme="${theme%/}"
            id="${theme##*/}"
            # "default" only names the theme to inherit
            [[ "$id" == default || -n "${seen[$id]:-}" ]] && continue
            [[ -e "$theme/cursors/left_ptr" || -e "$theme/cursors/default" ]] || continue
            seen[$id]=1
            local hypr=0 user=0
            [[ -f "$theme/manifest.hl" || -f "$theme/manifest.toml" ]] && hypr=1
            _cursor_is_user "$theme" && user=1
            printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$(_cursor_name "$theme")" "$theme" "$hypr" "$user"
        done
    done < <(cursor_dirs)
}

# By name, then id; the same order whatever the locale
cursor_themes() {
    _cursor_scan 2>/dev/null | LC_ALL=C sort -t $'\t' -k2,2f -k1,1
}

cursor_json() {
    cursor_themes | jq -Rn '[inputs | split("\t") | { id: .[0], name: .[1], path: .[2], hyprcursor: (.[3] == "1"), removable: (.[4] == "1") }]'
}

cursor_has() {
    [[ -n "$1" ]] && cursor_themes | cut -f1 | grep -qxF -- "$1"
}

_cursor_valid_size() {
    [[ "$1" =~ ^[0-9]+$ ]] && (($1 >= 8 && $1 <= 256))
}

cursor_apply() {
    local id="$1" size="${2:-$CURSOR_DEFAULT_SIZE}"
    if ! cursor_has "$id"; then
        echo "No cursor theme named '$id' (see lyne cursor list)" >&2
        return 1
    fi
    if ! _cursor_valid_size "$size"; then
        echo "Cursor size must be a number from 8 to 256, not '$size'" >&2
        return 1
    fi

    # Hyprland draws the cursor itself and for every app that hands it the
    # shape (cursor-shape protocol): those change at once
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        hyprctl setcursor "$id" "$size" >/dev/null 2>&1 || true
    fi

    # GTK reads these on Wayland (Hyprland also syncs them on setcursor,
    # unless cursor:sync_gsettings_theme is off)
    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface cursor-theme "$id" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-size "$size" 2>/dev/null || true
    fi

    # The theme an app falls back to when nothing names one
    local dir="$HOME/.icons/default" content
    content="$(printf '[Icon Theme]\nName=Default\nComment=Default cursor theme (lyne-dots: Settings > Cursor)\nInherits=%s\n' "$id")"
    if [[ "$(cat "$dir/index.theme" 2>/dev/null)" != "$content" ]]; then
        mkdir -p "$dir" || return 1
        printf '%s\n' "$content" >"$dir/index.theme.lyne.$$" && mv -f "$dir/index.theme.lyne.$$" "$dir/index.theme"
    fi
}

# A folder with xcursor files, like the themes cursor_themes lists
_cursor_is_theme() {
    [[ -e "$1/cursors/left_ptr" || -e "$1/cursors/default" ]]
}

# An id that is a plain folder name and not the "default" alias
_cursor_valid_id() {
    [[ -n "$1" && "$1" != default && "$1" != .* && "$1" != */* ]]
}

cursor_install() {
    local source="$1" dest tmp
    dest="$(cursor_install_dir)"
    if [[ ! -e "$source" ]]; then
        echo "No file or folder at '$source'" >&2
        return 2
    fi
    mkdir -p "$dest" || return 2
    # In the same folder, so the themes move in with a rename
    tmp="$(mktemp -d "$dest/.lyne-install.XXXXXX")" || return 2

    local rc=0
    _cursor_install_into "$source" "$tmp" "$dest" || rc=$?
    rm -rf "$tmp"
    return "$rc"
}

_cursor_install_into() {
    local source="$1" tmp="$2" dest="$3" base
    base="$(basename -- "$source")"
    if [[ -d "$source" ]]; then
        cp -a -- "$source" "$tmp/$base" || return 2
    # bsdtar refuses absolute paths and ".." by itself
    elif ! bsdtar -xf "$source" -C "$tmp" 2>/dev/null; then
        echo "Couldn't open '$source': not an archive bsdtar reads (.tar.gz, .tar.xz, .zip...)" >&2
        return 2
    fi

    # Theme folders: those with xcursor files, the outermost ones
    local themes=() dir
    while IFS= read -r -d '' dir; do
        dir="${dir%/cursors}"
        _cursor_is_theme "$dir" && themes+=("$dir")
    done < <(find "$tmp" -maxdepth 5 -type d -name cursors -print0 | sort -z)

    if ((${#themes[@]} == 0)); then
        if find "$tmp" -maxdepth 5 \( -name manifest.hl -o -name manifest.toml \) | grep -q .; then
            echo "'$base' only has hyprcursor themes: apps need the xcursor files (cursors/)" >&2
            return 4
        fi
        echo "No cursor theme in '$base' (a folder with a cursors/ folder inside)" >&2
        return 3
    fi

    local theme id link target real
    for theme in "${themes[@]}"; do
        id="${theme##*/}"
        # The archive was the theme itself: its name, else the archive's
        if [[ "$theme" == "$tmp" ]]; then
            id="$(_cursor_name "$theme")"
            [[ "$id" == "${tmp##*/}" ]] && id="${base%%.*}"
            id="${id//\//-}"
        fi
        if ! _cursor_valid_id "$id"; then
            echo "Skipped a theme named '$id'" >&2
            continue
        fi
        # Links may only point inside the theme
        real="$(realpath -- "$theme")"
        while IFS= read -r -d '' link; do
            target="$(realpath -m -- "$link")"
            [[ "$target" == "$real"/* ]] || rm -f -- "$link"
        done < <(find "$theme" -type l -print0)
        if [[ -e "$dest/$id" ]]; then
            rm -rf -- "${dest:?}/$id" || return 2
            mv -- "$theme" "$dest/$id" || return 2
            echo "updated $id"
        else
            mv -- "$theme" "$dest/$id" || return 2
            echo "installed $id"
        fi
    done
}

cursor_remove() {
    local id="$1" line path user
    line="$(cursor_themes | awk -F'\t' -v id="$id" '$1 == id')"
    if [[ -z "$id" || -z "$line" ]]; then
        echo "No cursor theme named '$id' (see lyne cursor list)" >&2
        return 2
    fi
    path="$(cut -f3 <<<"$line")"
    user="$(cut -f5 <<<"$line")"
    if [[ "$user" != 1 ]]; then
        echo "$id is a system theme in ${path%/*}: remove the package that installed it" >&2
        return 3
    fi
    rm -rf -- "$path"
}
