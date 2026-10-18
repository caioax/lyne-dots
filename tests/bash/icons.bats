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
    export LYNE_ICON_DIRS="$BATS_TEST_TMPDIR/nope:$SYSTEM_ICONS"
    run lib 'icons_themes | cut -f1'
    assert_output breeze
    export LYNE_ICON_DIRS="$BATS_TEST_TMPDIR/nope"
    run lib 'icons_themes; icons_json'
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
