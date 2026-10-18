#!/usr/bin/env bats
# lib/icons.sh and `lyne icons`: icon themes in fake icon directories

load helpers

setup() {
    lyne_setup
    USER_ICONS="$HOME/.local/share/icons"
    SYSTEM_ICONS="$BATS_TEST_TMPDIR/usr/share/icons"
    export LYNE_ICON_DIRS="$USER_ICONS:$HOME/.icons:$SYSTEM_ICONS"
    export LYNE_ICONS_NOTIFY_DELAY=0
    icons "$USER_ICONS/Tela-blue" name="Tela blue"
    icons "$USER_ICONS/Tela-blue-dark" name="Tela blue dark"
    icons "$USER_ICONS/Tela-blue-light" name="Tela blue light"
    icons "$SYSTEM_ICONS/breeze" name=Breeze
    icons "$SYSTEM_ICONS/breeze-dark" name="Breeze Dark"
    STATE="$HOME/.config/quickshell/state.json"
}

teardown() {
    repo_unchanged
}

# icons DIR [name=NAME] [dirs=LIST] [hidden=1]: an icon theme folder;
# dirs= (empty) makes a theme without icons (a cursor theme)
icons() {
    local dir=$1 name="" dirs="48/apps" hidden=0 arg
    shift
    for arg in "$@"; do
        case "$arg" in
        name=*) name="${arg#name=}" ;;
        dirs=*) dirs="${arg#dirs=}" ;;
        hidden=*) hidden="${arg#hidden=}" ;;
        esac
    done
    mkdir -p "$dir"
    {
        echo "[Icon Theme]"
        [[ -n "$name" ]] && echo "Name=$name"
        echo "Name[pt_BR]=Outro"
        echo "Inherits=hicolor"
        [[ -n "$dirs" ]] && echo "Directories=$dirs"
        [[ $hidden == 1 ]] && echo "Hidden=true"
        echo ""
        echo "[48/apps]"
        echo "Directories=not-this-one"
    } >"$dir/index.theme"
}

lib() { in_lyne icons -- "$1"; }
lyne() { "$REPO/local/.local/bin/lyne" "$@"; }

@test "themes: families of icon themes by name; cursor-only, hidden and fallback themes left out" {
    icons "$SYSTEM_ICONS/Papirus" name=Papirus
    icons "$SYSTEM_ICONS/Papirus-Dark" name="Papirus Dark"
    icons "$SYSTEM_ICONS/Papirus-Light" name="Papirus Light"
    # Variants only: the family is named after them
    icons "$HOME/.icons/Qogir-dark" name="Qogir dark"
    icons "$HOME/.icons/Qogir-light" name="Qogir-Light"
    # A -dark theme alone is a theme of its own
    icons "$USER_ICONS/Lone-dark" name="Lone dark"
    icons "$SYSTEM_ICONS/Bibata" name=Bibata dirs=
    icons "$SYSTEM_ICONS/Adwaita" name=Adwaita hidden=1
    icons "$SYSTEM_ICONS/hicolor" name=Hicolor
    icons "$USER_ICONS/default" name=Default
    mkdir -p "$USER_ICONS/no-index"
    mkdir -p "$SYSTEM_ICONS/crlf"
    printf '[Icon Theme]\r\nName=Crlf\r\nDirectories=16/apps\r\n' >"$SYSTEM_ICONS/crlf/index.theme"
    run lib icons_themes
    assert_success
    assert_output "$(printf '%s\n' \
        "breeze	Breeze	$SYSTEM_ICONS/breeze	breeze-dark		0" \
        "crlf	Crlf	$SYSTEM_ICONS/crlf			0" \
        "Lone-dark	Lone dark	$USER_ICONS/Lone-dark			1" \
        "Papirus	Papirus	$SYSTEM_ICONS/Papirus	Papirus-Dark	Papirus-Light	0" \
        "Qogir	Qogir	$HOME/.icons/Qogir-dark	Qogir-dark	Qogir-light	1" \
        "Tela-blue	Tela blue	$USER_ICONS/Tela-blue	Tela-blue-dark	Tela-blue-light	1")"
}

@test "themes: the user's copy of an id wins; a family is removable only when all of it is the user's" {
    icons "$USER_ICONS/breeze" name="My Breeze"
    icons "$SYSTEM_ICONS/Tela-blue-dark" name="System Tela"
    run lib 'icons_themes | cut -f1,2,3,6'
    assert_output "$(printf '%s\n' \
        "breeze	My Breeze	$USER_ICONS/breeze	0" \
        "Tela-blue	Tela blue	$USER_ICONS/Tela-blue	1")"
    icons "$USER_ICONS/breeze-dark" name=x
    run lib 'icons_themes | head -1 | cut -f6'
    assert_output 1
}

@test "themes: missing icon directories and none at all" {
    LYNE_ICON_DIRS="$BATS_TEST_TMPDIR/nope:$SYSTEM_ICONS" run lib 'icons_themes | cut -f1'
    assert_output breeze
    LYNE_ICON_DIRS="$BATS_TEST_TMPDIR/nope" run lib 'icons_themes; icons_json'
    assert_success
    assert_output "[]"
}

@test "json: id, name, folder, variants and removable" {
    icons "$USER_ICONS/Quote" name='Quote "me"'
    run lib 'icons_json | jq -c ".[]"'
    assert_line --index 0 "{\"id\":\"breeze\",\"name\":\"Breeze\",\"path\":\"$SYSTEM_ICONS/breeze\",\"dark\":\"breeze-dark\",\"light\":\"\",\"removable\":false}"
    assert_line --index 1 "{\"id\":\"Quote\",\"name\":\"Quote \\\"me\\\"\",\"path\":\"$USER_ICONS/Quote\",\"dark\":\"\",\"light\":\"\",\"removable\":true}"
}

@test "family and variant: by family or variant id, per mode, the base theme when a variant is missing" {
    run lib 'for id in Tela-blue Tela-blue-light breeze-dark; do icons_family $id; done'
    assert_output "$(printf '%s\n' Tela-blue Tela-blue breeze)"
    run lib 'for m in dark light; do icons_variant Tela-blue $m; icons_variant Tela-blue-dark $m; icons_variant breeze $m; done'
    assert_output "$(printf '%s\n' Tela-blue-dark Tela-blue-dark breeze-dark Tela-blue-light Tela-blue-light breeze)"
    run lib 'icons_family Nope || echo none; icons_variant Nope dark || echo none; icons_family "" || echo none'
    assert_output "$(printf '%s\n' none none none)"
}

@test "mode: light only when GSettings prefers light" {
    run lib 'gsettings() { echo "'"'"'prefer-light'"'"'"; }; icons_mode'
    assert_output light
    run lib 'gsettings() { echo "'"'"'default'"'"'"; }; icons_mode'
    assert_output dark
    run lib icons_mode
    assert_output dark
}

@test "apply: GSettings, qt6ct, qt5ct, kdeglobals and the GTK settings.ini; reload when Qt or KDE changed" {
    local cfg="$HOME/.config"
    mkdir -p "$cfg/qt6ct" "$cfg/qt5ct" "$cfg/gtk-3.0" "$cfg/gtk-4.0"
    printf '[Appearance]\ncolor_scheme_path=x\nicon_theme=Tela-blue-dark\nstyle=Breeze\n\n[Fonts]\nicon_theme=not-this\n' >"$cfg/qt6ct/qt6ct.conf"
    # Without the key, and without the section
    printf '[Appearance]\nstyle=Fusion\n[Fonts]\nfixed=x\n' >"$cfg/qt5ct/qt5ct.conf"
    printf '[General]\nColorScheme=Lyne\n' >"$cfg/kdeglobals"
    printf '[Settings]\ngtk-theme-name=adw-gtk3\ngtk-icon-theme-name=Tela-blue-dark\n' >"$cfg/gtk-3.0/settings.ini"
    run lib 'icons_apply breeze-dark'
    assert_success
    assert_output reload
    run cat "$STUB_LOG"
    assert_output "gsettings set org.gnome.desktop.interface icon-theme breeze-dark"
    run cat "$cfg/qt6ct/qt6ct.conf"
    assert_output "$(printf '[Appearance]\ncolor_scheme_path=x\nicon_theme=breeze-dark\nstyle=Breeze\n\n[Fonts]\nicon_theme=not-this')"
    run cat "$cfg/qt5ct/qt5ct.conf"
    assert_output "$(printf '[Appearance]\nstyle=Fusion\nicon_theme=breeze-dark\n[Fonts]\nfixed=x')"
    run cat "$cfg/kdeglobals"
    assert_output "$(printf '[General]\nColorScheme=Lyne\n\n[Icons]\nTheme=breeze-dark')"
    run cat "$cfg/gtk-3.0/settings.ini"
    assert_output "$(printf '[Settings]\ngtk-theme-name=adw-gtk3\ngtk-icon-theme-name=breeze-dark')"
    # No settings.ini for GTK 4: none made
    run ls -A "$cfg/gtk-4.0"
    assert_output ""
}

@test "apply: the same theme again rewrites nothing and asks for no reload" {
    local cfg="$HOME/.config"
    mkdir -p "$cfg/qt6ct"
    printf '[Appearance]\nicon_theme=breeze\n' >"$cfg/qt6ct/qt6ct.conf"
    printf '[Icons]\nTheme=breeze\n' >"$cfg/kdeglobals"
    touch -d 2001-01-01 "$cfg/qt6ct/qt6ct.conf" "$cfg/kdeglobals"
    run lib 'icons_apply breeze'
    assert_success
    assert_output ""
    run stat -c %Y "$cfg/qt6ct/qt6ct.conf" "$cfg/kdeglobals"
    assert_output "$(printf '%s\n' "$(date -d 2001-01-01 +%s)" "$(date -d 2001-01-01 +%s)")"
    run ls -A "$cfg/qt6ct"
    assert_output qt6ct.conf
}

@test "apply: stowed files are written through their links, which stay" {
    local dots="$BATS_TEST_TMPDIR/dots" cfg="$HOME/.config"
    mkdir -p "$dots/qt6ct" "$dots/kde" "$cfg"
    printf '[Appearance]\nicon_theme=Tela-blue-dark\n' >"$dots/qt6ct/qt6ct.conf"
    chmod 600 "$dots/qt6ct/qt6ct.conf"
    printf '[Icons]\nTheme=Tela-blue-dark\n' >"$dots/kde/kdeglobals"
    # A linked folder (like stow's) and a linked file
    ln -s "$dots/qt6ct" "$cfg/qt6ct"
    ln -s "$dots/kde/kdeglobals" "$cfg/kdeglobals"
    run lib 'icons_apply Tela-blue-light'
    assert_success
    [[ -L "$cfg/qt6ct" && -L "$cfg/kdeglobals" ]]
    run cat "$dots/qt6ct/qt6ct.conf" "$dots/kde/kdeglobals"
    assert_output "$(printf '[Appearance]\nicon_theme=Tela-blue-light\n[Icons]\nTheme=Tela-blue-light')"
    run stat -c %a "$dots/qt6ct/qt6ct.conf"
    assert_output 600
    run ls -A "$dots/qt6ct" "$dots/kde"
    refute_output --partial ".lyne"
}

@test "apply: an unknown theme changes nothing" {
    mkdir -p "$HOME/.config/qt6ct"
    printf '[Appearance]\nicon_theme=breeze\n' >"$HOME/.config/qt6ct/qt6ct.conf"
    run lib 'icons_apply Nope'
    assert_failure
    assert_output --partial "No icon theme named 'Nope'"
    run lib 'icons_apply ""'
    assert_failure
    run cat "$STUB_LOG"
    assert_output ""
    run cat "$HOME/.config/qt6ct/qt6ct.conf"
    assert_output "$(printf '[Appearance]\nicon_theme=breeze')"
}

@test "notify: KIconLoader's signal on the session bus" {
    run lib icons_notify
    assert_success
    run cat "$STUB_LOG"
    assert_output "dbus-send --session --type=signal /KIconLoader org.kde.KIconLoader.iconChanged int32:0"
}

@test "lyne icons set: the family saved (also from a variant id), its variant applied; unknown themes saved nowhere" {
    fake_dots
    mkdir -p "$HOME/.config/qt6ct"
    printf '[Appearance]\nicon_theme=x\n' >"$HOME/.config/qt6ct/qt6ct.conf"
    run lyne icons set breeze-dark
    assert_success
    assert_output "Icons: breeze (breeze-dark)"
    run jq -c .icons "$STATE"
    assert_output '{"theme":"breeze"}'
    grep -qx "icon_theme=breeze-dark" "$HOME/.config/qt6ct/qt6ct.conf"
    # Qt apps told (after the delay, 0 here)
    local _
    for _ in {1..20}; do grep -q dbus-send "$STUB_LOG" && break; sleep 0.1; done
    grep -q "dbus-send .*KIconLoader" "$STUB_LOG"
    run lyne icons set Nope
    assert_failure
    assert_output --partial "No icon theme named 'Nope'"
    run jq -c .icons "$STATE"
    assert_output '{"theme":"breeze"}'
}

@test "lyne icons apply: the saved family's variant for a mode; bad modes refused" {
    fake_dots
    mkdir -p "$HOME/.config/qt6ct"
    printf '[Appearance]\nicon_theme=x\n' >"$HOME/.config/qt6ct/qt6ct.conf"
    run lyne icons apply light
    assert_success
    grep -qx "icon_theme=Tela-blue-light" "$HOME/.config/qt6ct/qt6ct.conf"
    run lyne icons apply dark
    grep -qx "icon_theme=Tela-blue-dark" "$HOME/.config/qt6ct/qt6ct.conf"
    run lyne icons apply sepia
    assert_failure
}

@test "lyne icons status: the saved theme, else defaults.json; missing ones flagged" {
    fake_dots
    jq 'del(.icons)' "$STATE" >"$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    run lyne icons
    assert_success
    assert_line "Theme: Tela-blue (dark mode: Tela-blue-dark)"
    assert_line --regexp "^  ● Tela-blue +~/.local/share/icons/Tela-blue \(dark and light\)$"
    assert_line --regexp "^  ○ breeze +.*/usr/share/icons/breeze \(dark and light\)$"
    refute_output --partial "not installed"
    jq '.icons = {theme: "Gone"}' "$STATE" >"$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    run lyne icons
    assert_line "Theme: Gone"
    assert_line --partial "not installed"
    run lyne icons apply
    assert_failure
    run lyne icons list
    assert_line "Tela-blue	Tela blue	~/.local/share/icons/Tela-blue	Tela-blue-dark	Tela-blue-light"
}

# LYNE_TEST_SHELL: a copy of the shell (to sabotage the script)
PREVIEW_SHELL="${LYNE_TEST_SHELL:-$REPO/quickshell/.config/quickshell}"
preview() { timeout 5 python3 "$PREVIEW_SHELL/scripts/icon-preview.py" "$LYNE_ICON_DIRS" "$@"; }

# sized DIR INHERITS SUBDIR:TYPE:SIZE[:MIN:MAX[:SCALE]]...: a theme with
# sized folders
sized() {
    local dir=$1 inherits=$2 spec name type size names=""
    shift 2
    mkdir -p "$dir"
    for spec in "$@"; do names+="${names:+,}${spec%%:*}"; done
    {
        printf '[Icon Theme]\nName=%s\nInherits=%s\nDirectories=%s\n' "${dir##*/}" "$inherits" "$names"
        for spec in "$@"; do
            IFS=: read -r name type size min max scale <<<"$spec"
            printf '\n[%s]\nSize=%s\nType=%s\n' "$name" "$size" "$type"
            [[ -n "$min" ]] && printf 'MinSize=%s\nMaxSize=%s\n' "$min" "$max"
            [[ -n "$scale" ]] && printf 'Scale=%s\n' "$scale"
            mkdir -p "$dir/$name"
        done
    } >"$dir/index.theme"
}

@test "preview: the exact size first (at scale 1), else the closest; scalable folders match a range" {
    local t="$USER_ICONS/Sizes"
    sized "$t" "" 24@2:Fixed:24:::2 16:Fixed:16 48:Fixed:48 64:Fixed:64 scalable:Scalable:64:8:512
    touch "$t/24@2/folder.svg" "$t/16/folder.svg" "$t/48/folder.png" "$t/16/utilities-terminal.svg" \
        "$t/64/utilities-terminal.png" "$t/scalable/web-browser.svg" "$t/48/web-browser.xpm" "$t/scalable/preferences-system.svg"
    run preview Sizes
    assert_success
    run jq -r '.Sizes | to_entries[] | "\(.key) \(.value)"' <<<"$output"
    assert_output "$(printf '%s\n' "folder $t/48/folder.png" "terminal $t/64/utilities-terminal.png" "browser $t/48/web-browser.xpm" "settings $t/scalable/preferences-system.svg")"
}

@test "preview: fallback names across the inherited themes, then hicolor; missing icons left out" {
    sized "$USER_ICONS/Child" "Parent" 48:Fixed:48
    sized "$SYSTEM_ICONS/Parent" "" 32:Threshold:32
    sized "$SYSTEM_ICONS/hicolor" "" 48x48/apps:Threshold:48
    touch "$USER_ICONS/Child/48/folder-home.svg" "$SYSTEM_ICONS/Parent/32/user-home.svg" \
        "$SYSTEM_ICONS/Parent/32/folder.svg" "$USER_ICONS/Child/48/folder.svg" \
        "$SYSTEM_ICONS/hicolor/48x48/apps/internet-web-browser.png"
    run preview Child
    assert_success
    run jq -c .Child <<<"$output"
    assert_output "{\"folder\":\"$USER_ICONS/Child/48/folder.svg\",\"browser\":\"$SYSTEM_ICONS/hicolor/48x48/apps/internet-web-browser.png\",\"home\":\"$SYSTEM_ICONS/Parent/32/user-home.svg\"}"
}

@test "preview: inheritance loops, unknown themes and ids with a slash" {
    sized "$USER_ICONS/Loop-a" "Loop-b" 48:Fixed:48
    sized "$USER_ICONS/Loop-b" "Loop-a,Nope" 48:Fixed:48
    touch "$USER_ICONS/Loop-b/48/folder.svg"
    run preview Loop-a Nope "../Loop-b" ""
    assert_success
    assert_output "{\"Loop-a\": {\"folder\": \"$USER_ICONS/Loop-b/48/folder.svg\"}, \"Nope\": {}}"
}

@test "preview: icons.sh looks in the lib's icon directories" {
    sized "$HOME/.icons/Home-theme" "" 48:Fixed:48
    touch "$HOME/.icons/Home-theme/48/folder.svg"
    run "$REPO/quickshell/.config/quickshell/scripts/icons.sh" preview Home-theme
    assert_success
    assert_output "{\"Home-theme\": {\"folder\": \"$HOME/.icons/Home-theme/48/folder.svg\"}}"
}

# --- install and remove ---

pack() {
    local archive=$1 dir=$2
    shift 2
    bsdtar -a -cf "$archive" -C "$dir" "$@"
}

@test "install: a family with links between its themes; the user's copy replaced; GTK's cache made" {
    local src="$BATS_TEST_TMPDIR/src"
    icons "$src/Fam" name=Fam
    icons "$src/Fam-dark" name="Fam dark"
    mkdir -p "$src/Fam/48" && touch "$src/Fam/48/folder.svg"
    ln -s ../Fam/48 "$src/Fam-dark/48"
    ln -s folder.svg "$src/Fam/48/folder-open.svg"
    ln -s /etc/passwd "$src/Fam/48/bad.svg"
    ln -s ../../outside "$src/Fam-dark/away"
    mkdir -p "$src/outside"
    pack "$BATS_TEST_TMPDIR/fam.tar.xz" "$src" Fam Fam-dark outside
    run lib "icons_install '$BATS_TEST_TMPDIR/fam.tar.xz'"
    assert_success
    assert_output "$(printf '%s\n' "installed Fam-dark" "installed Fam")"
    [[ -L "$USER_ICONS/Fam-dark/48" && -f "$USER_ICONS/Fam-dark/48/folder.svg" ]]
    [[ -L "$USER_ICONS/Fam/48/folder-open.svg" ]]
    [[ ! -L "$USER_ICONS/Fam/48/bad.svg" && ! -L "$USER_ICONS/Fam-dark/away" && ! -e "$USER_ICONS/outside" ]]
    run grep -c "gtk-update-icon-cache -q -f -t $USER_ICONS/Fam" "$STUB_LOG"
    assert_output 2
    run lib 'icons_themes | cut -f1,4,6'
    assert_line "Fam	Fam-dark	1"
    printf 'old' >"$USER_ICONS/Fam/old-file"
    run lib "icons_install '$BATS_TEST_TMPDIR/fam.tar.xz'"
    assert_line "updated Fam"
    [[ ! -e "$USER_ICONS/Fam/old-file" ]]
    run ls -A "$USER_ICONS"
    refute_output --partial .lyne-install
}

@test "install: a theme at the archive's top takes the archive's name; a folder" {
    local src="$BATS_TEST_TMPDIR/src"
    icons "$src/flat" name="Flat Theme"
    pack "$BATS_TEST_TMPDIR/Flat-icons.tar.gz" "$src/flat" index.theme
    run lib "icons_install '$BATS_TEST_TMPDIR/Flat-icons.tar.gz'"
    assert_output "installed Flat-icons"
    icons "$src/Folder-theme" name=Folder
    run lib "icons_install '$src/Folder-theme'"
    assert_output "installed Folder-theme"
    [[ -d "$src/Folder-theme" ]]
}

@test "install: not an archive, no theme, only cursor themes, fallback names, nothing outside" {
    local src="$BATS_TEST_TMPDIR/src"
    printf 'hello' >"$BATS_TEST_TMPDIR/notes.txt"
    run lib "icons_install '$BATS_TEST_TMPDIR/notes.txt'"
    assert_failure 2
    run lib "icons_install '$BATS_TEST_TMPDIR/missing.zip'"
    assert_failure 2
    mkdir -p "$src/plain/apps"
    pack "$BATS_TEST_TMPDIR/plain.zip" "$src" plain
    run lib "icons_install '$BATS_TEST_TMPDIR/plain.zip'"
    assert_failure 3
    icons "$src/cur/Pointer" name=Pointer dirs=
    mkdir -p "$src/cur/Pointer/cursors"
    pack "$BATS_TEST_TMPDIR/cur.zip" "$src" cur
    run lib "icons_install '$BATS_TEST_TMPDIR/cur.zip'"
    assert_failure 4
    assert_output --partial "only has cursor themes"
    icons "$src/odd/hicolor"
    icons "$src/odd/default"
    icons "$src/odd/Fine"
    icons "$src/odd/Hidden" hidden=1
    pack "$BATS_TEST_TMPDIR/odd.zip" "$src" odd
    run lib "icons_install '$BATS_TEST_TMPDIR/odd.zip'"
    assert_success
    assert_line "installed Fine"
    assert_line "Skipped a theme named 'hicolor'"
    assert_line "Skipped a theme named 'default'"
    refute_output --partial Hidden
    [[ ! -e "$USER_ICONS/hicolor" && ! -e "$USER_ICONS/default" && ! -e "$USER_ICONS/Hidden" ]]
    icons "$src/evil"
    (cd "$src/evil" && bsdtar -cf "$BATS_TEST_TMPDIR/evil.tar" -s '|^|../../|' index.theme 2>/dev/null) || true
    run lib "icons_install '$BATS_TEST_TMPDIR/evil.tar'"
    assert_failure 2
    [[ ! -e "$HOME/.local/index.theme" && ! -e "$HOME/index.theme" ]]
    run ls -A "$USER_ICONS"
    refute_output --partial .lyne-install
}

@test "install: links kept when the icons folder is itself a link" {
    mkdir -p "$BATS_TEST_TMPDIR/elsewhere" "$HOME/.local/share"
    rm -rf "$USER_ICONS"
    ln -s "$BATS_TEST_TMPDIR/elsewhere" "$USER_ICONS"
    local src="$BATS_TEST_TMPDIR/src"
    icons "$src/Linked"
    icons "$src/Linked-light"
    ln -s ../Linked/index.theme "$src/Linked-light/base.theme"
    pack "$BATS_TEST_TMPDIR/linked.tar.gz" "$src" Linked Linked-light
    run lib "icons_install '$BATS_TEST_TMPDIR/linked.tar.gz'"
    assert_success
    [[ -L "$BATS_TEST_TMPDIR/elsewhere/Linked-light/base.theme" ]]
}

@test "remove: a whole family of the user's; system themes and unknown ones refused" {
    icons "$HOME/.icons/Old" name=Old
    run lib 'icons_remove Tela-blue-light && icons_remove Old'
    assert_success
    [[ ! -e "$USER_ICONS/Tela-blue" && ! -e "$USER_ICONS/Tela-blue-dark" && ! -e "$USER_ICONS/Tela-blue-light" && ! -e "$HOME/.icons/Old" ]]
    run lib 'icons_remove breeze'
    assert_failure 3
    assert_output --partial "system theme"
    [[ -d "$SYSTEM_ICONS/breeze" && -d "$SYSTEM_ICONS/breeze-dark" ]]
    run lib 'icons_remove Nope'
    assert_failure 2
    run lib 'icons_remove ""'
    assert_failure 2
}

@test "lyne icons install/remove: never the theme in use" {
    fake_dots
    local src="$BATS_TEST_TMPDIR/src"
    icons "$src/Mine"
    pack "$BATS_TEST_TMPDIR/mine.tar.gz" "$src" Mine
    run lyne icons install "$BATS_TEST_TMPDIR/mine.tar.gz" "$BATS_TEST_TMPDIR/nope.zip"
    assert_failure
    assert_line "installed Mine"
    lyne icons set Mine
    run lyne icons remove Mine
    assert_failure
    assert_output --partial "in use"
    [[ -d "$USER_ICONS/Mine" ]]
    run lyne icons remove Tela-blue-dark
    assert_success
    assert_output "Removed Tela-blue"
    [[ ! -e "$USER_ICONS/Tela-blue-dark" ]]
}
