#!/bin/bash
# =============================================================================
# icons.sh - The icon theme
# =============================================================================
# An icon theme is a folder of an icon directory whose index.theme lists
# icon folders ([Icon Theme] with Directories=); cursor-only themes have
# none. hicolor, locolor (the fallbacks every theme inherits), "default"
# and hidden themes are left out.
#
# Themes come in families: X with X-dark and/or X-light (or X-Dark,
# X-Light) is one family, X. The -dark variant is the one for dark themes
# (light icons), like Tela's, Papirus' and Breeze's; the shell picks the
# variant by the theme's mode, a family without one uses its base theme.
#
#   icons_themes               one line per family, sorted by name:
#                              id<TAB>name<TAB>folder<TAB>dark<TAB>light
#                              <TAB>user (0|1: every folder in the user's
#                              own icon directories, so it can be removed).
#                              dark/light: the variants' ids, or empty;
#                              folder: the base theme's, else a variant's
#   icons_json                 the same as a JSON array of
#                              { id, name, path, dark, light, removable }
#   icons_family <id>          the family of a theme (a family id or one of
#                              its variants); fails when there's none
#   icons_variant <id> <dark|light>
#                              the theme to use for that mode
#   icons_mode                 dark or light, from GSettings' color-scheme
#                              (the shell sets it with the theme)
#   icons_apply <theme>        use that theme (a variant, as is): GSettings
#                              (GTK on Wayland, Flatpak apps through the
#                              portal), qt6ct/qt5ct (Qt apps), kdeglobals
#                              (KDE apps) and the GTK settings.ini (X11 GTK
#                              apps); files only when their value changes.
#                              Prints "reload" when a Qt or KDE file
#                              changed (see icons_notify)
#   icons_install <archive|folder>
#                              install the icon themes inside (an archive
#                              bsdtar opens) into ~/.local/share/icons,
#                              replacing the user's own copy of the same id;
#                              prints "installed <id>" or "updated <id>" per
#                              theme. Links between its themes (Tela's
#                              variants link to the base theme) stay; others
#                              are dropped. Fails with 2 when it can't be
#                              read, 3 when there's no icon theme in it, 4
#                              when there are only cursor themes
#   icons_remove <id>          delete a family (or the family of a variant)
#                              from the user's folders; 2 when it isn't
#                              installed, 3 when any of it is a system theme
#   icons_notify               tell running KDE/Qt apps to load the icons
#                              again (KIconLoader's signal). Qt apps reload
#                              qt6ct's settings ~3 s after the file changes:
#                              send it after that, or they reload the old
#                              theme
#
# LYNE_ICON_DIRS (colon separated) replaces the icon directories in tests,
# as in cursor.sh.
# =============================================================================

# cursor_dirs, cursor_install_dir and _cursor_is_user: the same directories
source "${BASH_SOURCE[0]%/*}/cursor.sh"

# shellcheck disable=SC2034 # read by commands/icons.sh
ICONS_DEFAULT_THEME="Tela-blue"

# name<US>listed (0|1) from a folder's index.theme: listed when its
# [Icon Theme] section has Directories and isn't Hidden. Split on the unit
# separator: read joins empty fields between tabs
_icons_info() {
    [[ -f "$1/index.theme" ]] || return 1
    awk '
        { sub(/\r$/, "") }
        /^\[/ { section = $0; next }
        section != "[Icon Theme]" { next }
        /^Name[ \t]*=/ && name == "" { name = $0; sub(/^Name[ \t]*=[ \t]*/, "", name) }
        /^Directories[ \t]*=/ { dirs = $0; sub(/^Directories[ \t]*=[ \t]*/, "", dirs) }
        /^Hidden[ \t]*=/ { hidden = tolower($0) ~ /=[ \t]*true/ }
        END { printf "%s\037%d\n", name, (dirs != "" && !hidden) }
    ' "$1/index.theme"
}

# id<TAB>name<TAB>folder<TAB>user, one per installed theme; the first folder
# of an id wins
_icons_scan() {
    local root theme id info name listed
    declare -A seen=()
    while IFS= read -r root; do
        [[ -d "$root" ]] || continue
        for theme in "$root"/*/; do
            theme="${theme%/}"
            id="${theme##*/}"
            case "$id" in default | hicolor | locolor) continue ;; esac
            [[ -n "${seen[$id]:-}" ]] && continue
            info="$(_icons_info "$theme")" || continue
            seen[$id]=1
            IFS=$'\x1f' read -r name listed <<<"$info"
            [[ $listed == 1 ]] || continue
            local user=0
            _cursor_is_user "$theme" && user=1
            printf '%s\t%s\t%s\t%s\n' "$id" "${name:-$id}" "$theme" "$user"
        done
    done < <(cursor_dirs)
}

_icons_families() {
    local id name folder user
    declare -A names=() folders=() users=()
    local ids=()
    while IFS=$'\t' read -r id name folder user; do
        ids+=("$id")
        names[$id]="$name"
        folders[$id]="$folder"
        users[$id]="$user"
    done < <(_icons_scan 2>/dev/null)

    # Variants: X-dark/X-light whose base or other variant is installed
    declare -A base_of=() dark=() light=()
    local base kind other
    for id in "${ids[@]}"; do
        [[ "$id" =~ ^(.+)-([Dd]ark|[Ll]ight)$ ]] || continue
        base="${BASH_REMATCH[1]}"
        kind="${BASH_REMATCH[2]}"
        case "$kind" in
        dark) other=light ;;
        Dark) other=Light ;;
        light) other=dark ;;
        Light) other=Dark ;;
        esac
        [[ -n "${names[$base]+x}" || -n "${names[$base-$other]+x}" ]] || continue
        base_of[$id]="$base"
        if [[ "${kind,,}" == dark ]]; then dark[$base]="$id"; else light[$base]="$id"; fi
    done

    # One line per family: the base theme, or a family of variants only
    declare -A done_=()
    local family member members fname ffolder fuser
    for id in "${ids[@]}"; do
        family="${base_of[$id]:-$id}"
        [[ -n "${done_[$family]:-}" ]] && continue
        done_[$family]=1
        members=()
        [[ -n "${names[$family]+x}" ]] && members+=("$family")
        [[ -n "${dark[$family]:-}" ]] && members+=("${dark[$family]}")
        [[ -n "${light[$family]:-}" ]] && members+=("${light[$family]}")
        if [[ -n "${names[$family]+x}" ]]; then
            fname="${names[$family]}"
        else
            # "Qogir dark" → "Qogir"
            fname="$(sed -E 's/[ _-]+(dark|light)$//I' <<<"${names[${members[0]}]}")"
        fi
        ffolder="${folders[${members[0]}]}"
        fuser=1
        for member in "${members[@]}"; do
            [[ "${users[$member]}" == 1 ]] || fuser=0
        done
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$family" "${fname:-$family}" "$ffolder" \
            "${dark[$family]:-}" "${light[$family]:-}" "$fuser"
    done
}

# By name, then id; the same order whatever the locale
icons_themes() {
    _icons_families | LC_ALL=C sort -t $'\t' -k2,2f -k1,1
}

# icons_themes split on the unit separator, for read (see _icons_info)
_icons_split() {
    icons_themes | tr '\t' '\037'
}

icons_json() {
    icons_themes | jq -Rn '[inputs | split("\t") | { id: .[0], name: .[1], path: .[2], dark: .[3], light: .[4], removable: (.[5] == "1") }]'
}

icons_family() {
    [[ -n "$1" ]] || return 1
    local id _name _folder dark light _user
    while IFS=$'\x1f' read -r id _name _folder dark light _user; do
        if [[ "$1" == "$id" || "$1" == "$dark" || "$1" == "$light" ]]; then
            printf '%s\n' "$id"
            return 0
        fi
    done < <(_icons_split)
    return 1
}

icons_variant() {
    local want="$1" mode="${2:-dark}" id _name folder dark light _user
    while IFS=$'\x1f' read -r id _name folder dark light _user; do
        [[ "$want" == "$id" || "$want" == "$dark" || "$want" == "$light" ]] || continue
        if [[ "$mode" == light && -n "$light" ]]; then
            printf '%s\n' "$light"
        elif [[ "$mode" != light && -n "$dark" ]]; then
            printf '%s\n' "$dark"
        else
            # The base theme; a family of variants only has both
            printf '%s\n' "${folder##*/}"
        fi
        return 0
    done < <(_icons_split)
    return 1
}

icons_mode() {
    local scheme=""
    command -v gsettings &>/dev/null &&
        scheme="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)"
    [[ "$scheme" == *light* ]] && echo light || echo dark
}

# _icons_ini_set FILE SECTION KEY VALUE: sets KEY in [SECTION] (added when
# missing), through links (stowed files); 0 when the file changed
_icons_ini_set() {
    local file="$1" real tmp
    [[ -f "$file" ]] || return 1
    real="$(realpath -- "$file")" || return 1
    tmp="$(mktemp "${real%/*}/.${real##*/}.lyne.XXXXXX")" || return 1
    awk -v section="[$2]" -v key="$3" -v value="$4" '
        function put() { print key "=" value; done = 1 }
        {
            line = $0; sub(/\r$/, "", line)
            if (line ~ /^\[/) {
                if (inside && !done) put()
                inside = (line == section)
                if (inside) seen = 1
            } else if (inside && !done && index(line, key) == 1 && substr(line, length(key) + 1) ~ /^[ \t]*=/) {
                put()
                next
            }
            print
        }
        END {
            if (inside && !done) put()
            if (!seen) { print ""; print section; put() }
        }
    ' "$real" >"$tmp" || { rm -f "$tmp"; return 1; }
    if cmp -s "$tmp" "$real"; then
        rm -f "$tmp"
        return 1
    fi
    chmod --reference="$real" "$tmp" 2>/dev/null
    mv -f "$tmp" "$real"
}

icons_has() {
    [[ -n "$1" ]] && _icons_scan 2>/dev/null | cut -f1 | grep -qxF -- "$1"
}

icons_apply() {
    local id="$1" config="${XDG_CONFIG_HOME:-$HOME/.config}"
    if ! icons_has "$id"; then
        echo "No icon theme named '$id' (see lyne icons list)" >&2
        return 1
    fi

    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface icon-theme "$id" 2>/dev/null || true
    fi
    local qt=0
    _icons_ini_set "$config/qt6ct/qt6ct.conf" Appearance icon_theme "$id" && qt=1
    _icons_ini_set "$config/qt5ct/qt5ct.conf" Appearance icon_theme "$id" && qt=1
    _icons_ini_set "$config/kdeglobals" Icons Theme "$id" && qt=1
    _icons_ini_set "$config/gtk-3.0/settings.ini" Settings gtk-icon-theme-name "$id"
    _icons_ini_set "$config/gtk-4.0/settings.ini" Settings gtk-icon-theme-name "$id"
    ((qt)) && echo reload
    return 0
}

icons_notify() {
    command -v dbus-send &>/dev/null || return 0
    dbus-send --session --type=signal /KIconLoader org.kde.KIconLoader.iconChanged int32:0 2>/dev/null || true
}

icons_install() {
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
    _icons_install_into "$source" "$tmp" "$dest" || rc=$?
    rm -rf "$tmp"
    return "$rc"
}

_icons_install_into() {
    local source="$1" tmp="$2" dest="$3" base
    base="$(basename -- "$source")"
    if [[ -d "$source" ]]; then
        cp -a -- "$source" "$tmp/$base" || return 2
    # bsdtar refuses absolute paths and ".." by itself
    elif ! bsdtar -xf "$source" -C "$tmp" 2>/dev/null; then
        echo "Couldn't open '$source': not an archive bsdtar reads (.tar.gz, .tar.xz, .zip...)" >&2
        return 2
    fi

    # Theme folders: an index.theme listing icons; cursor themes noted
    local themes=() cursors=0 index dir info
    while IFS= read -r -d '' index; do
        dir="${index%/index.theme}"
        info="$(_icons_info "$dir")" || continue
        if [[ "${info##*$'\x1f'}" == 1 ]]; then
            themes+=("$dir")
        elif [[ -d "$dir/cursors" ]]; then
            cursors=1
        fi
    done < <(find "$tmp" -maxdepth 5 -name index.theme -type f -print0 | LC_ALL=C sort -z)

    if ((${#themes[@]} == 0)); then
        if ((cursors)); then
            echo "'$base' only has cursor themes: install them with lyne cursor install" >&2
            return 4
        fi
        echo "No icon theme in '$base' (a folder whose index.theme lists icon folders)" >&2
        return 3
    fi

    # Links may only point into one of these themes (absolute ones never
    # do: they point outside the folder the archive went to). In one Python
    # process: Tela has some 27 000 links
    python3 -I -c '
import os, sys
roots = [os.path.realpath(t) for t in sys.argv[1:]]
for theme in sys.argv[1:]:
    for folder, dirs, files in os.walk(theme):
        for name in dirs + files:
            path = os.path.join(folder, name)
            if not os.path.islink(path):
                continue
            real = os.path.realpath(path)
            if not any(real == r or real.startswith(r + "/") for r in roots):
                os.remove(path)
' "${themes[@]}" || return 2

    local theme id
    for theme in "${themes[@]}"; do
        id="${theme##*/}"
        # The archive was the theme itself: the archive's name
        if [[ "$theme" == "$tmp" ]]; then
            id="${base%%.*}"
        fi
        # Not the fallback themes every theme inherits
        if ! _cursor_valid_id "$id" || [[ "$id" == hicolor || "$id" == locolor ]]; then
            echo "Skipped a theme named '$id'" >&2
            continue
        fi
        if [[ -e "$dest/$id" ]]; then
            rm -rf -- "${dest:?}/$id" || return 2
            echo "updated $id"
        else
            echo "installed $id"
        fi
        mv -- "$theme" "$dest/$id" || return 2
        # GTK reads a theme much faster with its cache
        if command -v gtk-update-icon-cache &>/dev/null; then
            gtk-update-icon-cache -q -f -t "$dest/$id" 2>/dev/null || true
        fi
    done
}

icons_remove() {
    local id="$1" family line dark light user path
    family="$(icons_family "$id")" || {
        echo "No icon theme named '$id' (see lyne icons list)" >&2
        return 2
    }
    line="$(_icons_split | awk -F'\037' -v id="$family" '$1 == id')"
    IFS=$'\x1f' read -r _ _ path dark light user <<<"$line"
    if [[ "$user" != 1 ]]; then
        echo "$family is a system theme in ${path%/*}: remove the package that installed it" >&2
        return 3
    fi
    local member folder
    for member in "$family" "$dark" "$light"; do
        [[ -n "$member" ]] || continue
        folder="$(_icons_scan 2>/dev/null | awk -F'\t' -v id="$member" '$1 == id { print $3 }')"
        [[ -n "$folder" ]] && rm -rf -- "$folder"
    done
    return 0
}
