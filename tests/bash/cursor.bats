#!/usr/bin/env bats
# lib/cursor.sh and `lyne cursor`: cursor themes in fake icon directories

load helpers

setup() {
    lyne_setup
    USER_ICONS="$HOME/.local/share/icons"
    SYSTEM_ICONS="$BATS_TEST_TMPDIR/usr/share/icons"
    export LYNE_ICON_DIRS="$USER_ICONS:$HOME/.icons:$SYSTEM_ICONS"
    theme "$SYSTEM_ICONS/Bibata-Modern-Classic" name=Bibata-Modern-Classic
    theme "$SYSTEM_ICONS/breeze_cursors" name="Breeze Dark"
    theme "$SYSTEM_ICONS/Adwaita" name=Adwaita file=default
    STATE="$HOME/.config/quickshell/state.json"
}

teardown() {
    repo_unchanged
}

# theme DIR [name=NAME] [file=left_ptr|default] [hypr=1] [cursors=0]: a
# theme folder; cursors=0 leaves out the xcursor files
theme() {
    local dir=$1 name="" file=left_ptr hypr=0 cursors=1 arg
    shift
    for arg in "$@"; do
        case "$arg" in
        name=*) name="${arg#name=}" ;;
        file=*) file="${arg#file=}" ;;
        hypr=*) hypr="${arg#hypr=}" ;;
        cursors=*) cursors="${arg#cursors=}" ;;
        esac
    done
    mkdir -p "$dir"
    [[ -n "$name" ]] && printf '[Icon Theme]\nName=%s\nName[pt_BR]=Outro\nComment=x\n' "$name" >"$dir/index.theme"
    if [[ $cursors == 1 ]]; then
        mkdir -p "$dir/cursors"
        printf 'xcur' >"$dir/cursors/$file"
    fi
    [[ $hypr == 1 ]] && printf 'name = x\n' >"$dir/manifest.hl"
    return 0
}

cursor() { in_lyne cursor -- "$1"; }
lyne() { "$REPO/local/.local/bin/lyne" "$@"; }

@test "themes: xcursor folders by name, the user's copy wins, the rest left out" {
    theme "$USER_ICONS/Bibata-Modern-Classic" name="Bibata Mine"
    theme "$HOME/.icons/zz-plain"
    theme "$USER_ICONS/hypr-only" name="Hypr Only" hypr=1 cursors=0
    theme "$USER_ICONS/Both" name="both" hypr=1
    theme "$USER_ICONS/default" name=Default
    theme "$USER_ICONS/Tela-blue" name="Tela" cursors=0
    mkdir -p "$USER_ICONS/empty/cursors"
    printf '[Icon Theme]\r\nName=Crlf\r\n' >"$SYSTEM_ICONS/Adwaita/index.theme"
    run cursor cursor_themes
    assert_success
    assert_output "$(printf '%s\n' \
        "Bibata-Modern-Classic	Bibata Mine	$USER_ICONS/Bibata-Modern-Classic	0" \
        "Both	both	$USER_ICONS/Both	1" \
        "breeze_cursors	Breeze Dark	$SYSTEM_ICONS/breeze_cursors	0" \
        "Adwaita	Crlf	$SYSTEM_ICONS/Adwaita	0" \
        "zz-plain	zz-plain	$HOME/.icons/zz-plain	0")"
}

@test "themes: missing icon directories and none at all" {
    export LYNE_ICON_DIRS="$BATS_TEST_TMPDIR/nope:$SYSTEM_ICONS"
    run cursor 'cursor_themes | cut -f1'
    assert_output "$(printf '%s\n' Adwaita Bibata-Modern-Classic breeze_cursors)"
    export LYNE_ICON_DIRS="$BATS_TEST_TMPDIR/nope"
    run cursor 'cursor_themes; cursor_json'
    assert_success
    assert_output "[]"
}

@test "json: id, name, folder and hyprcursor" {
    theme "$USER_ICONS/Both" name="Both \"quoted\"" hypr=1
    run cursor 'cursor_json | jq -c ".[]"'
    assert_line --index 1 "{\"id\":\"Bibata-Modern-Classic\",\"name\":\"Bibata-Modern-Classic\",\"path\":\"$SYSTEM_ICONS/Bibata-Modern-Classic\",\"hyprcursor\":false}"
    assert_line --index 2 "{\"id\":\"Both\",\"name\":\"Both \\\"quoted\\\"\",\"path\":\"$USER_ICONS/Both\",\"hyprcursor\":true}"
}

@test "dirs: the user's, ~/.icons, then XDG_DATA_DIRS, without repeats" {
    unset LYNE_ICON_DIRS XDG_DATA_DIRS
    run cursor cursor_dirs
    assert_output "$(printf '%s\n' "$HOME/.local/share/icons" "$HOME/.icons" /usr/local/share/icons /usr/share/icons)"
    run env XDG_DATA_HOME="$HOME/data" XDG_DATA_DIRS="/opt/share/:$HOME/data::/usr/share" bash -c "$(declare -f in_lyne); LIB='$LIB' REPO='$REPO' in_lyne cursor -- cursor_dirs"
    assert_output "$(printf '%s\n' "$HOME/data/icons" "$HOME/.icons" /opt/share/icons /usr/share/icons)"
}

@test "has: installed ids only" {
    run cursor 'cursor_has Adwaita && echo yes; cursor_has adwaita || echo no; cursor_has "" || echo empty; cursor_has default || echo default'
    assert_output "$(printf '%s\n' yes no empty default)"
}

@test "apply: GSettings and the default theme; Hyprland only when it runs" {
    run cursor 'cursor_apply breeze_cursors 32'
    assert_success
    run cat "$STUB_LOG"
    assert_output "$(printf '%s\n' \
        "gsettings set org.gnome.desktop.interface cursor-theme breeze_cursors" \
        "gsettings set org.gnome.desktop.interface cursor-size 32")"
    run cat "$HOME/.icons/default/index.theme"
    assert_line "[Icon Theme]"
    assert_line "Inherits=breeze_cursors"
    : >"$STUB_LOG"
    export HYPRLAND_INSTANCE_SIGNATURE=test
    run cursor 'cursor_apply Adwaita 24'
    assert_success
    run head -1 "$STUB_LOG"
    assert_output "hyprctl setcursor Adwaita 24"
    run grep -c Inherits=Adwaita "$HOME/.icons/default/index.theme"
    assert_output 1
}

@test "apply: the same theme again leaves the default theme file alone" {
    cursor 'cursor_apply Adwaita 24'
    touch -d '2001-01-01' "$HOME/.icons/default/index.theme"
    cursor 'cursor_apply Adwaita 48'
    run stat -c %Y "$HOME/.icons/default/index.theme"
    assert_output "$(date -d 2001-01-01 +%s)"
    run ls -A "$HOME/.icons/default"
    assert_output index.theme
}

@test "apply: an unknown theme or a bad size changes nothing" {
    run cursor 'cursor_apply Nope 24'
    assert_failure
    assert_output --partial "No cursor theme named 'Nope'"
    for size in 0 7 257 abc "24 x" ""; do
        run cursor "cursor_apply Adwaita '$size'"
        if [[ -z "$size" ]]; then
            assert_success # the default size
        else
            assert_failure
            assert_output --partial "Cursor size must be a number"
        fi
    done
    run grep -c "cursor-size" "$STUB_LOG"
    assert_output 1
    run grep -h Inherits "$HOME/.icons/default/index.theme"
    assert_output Inherits=Adwaita
}

@test "lyne cursor set/size: applied and saved; unknown themes saved nowhere" {
    fake_dots
    run lyne cursor set breeze_cursors 48
    assert_success
    assert_output "Cursor: breeze_cursors, size 48"
    run jq -c .cursor "$STATE"
    assert_output '{"theme":"breeze_cursors","size":48}'
    run lyne cursor size 32
    assert_success
    run jq -c .cursor "$STATE"
    assert_output '{"theme":"breeze_cursors","size":32}'
    run lyne cursor set Nope
    assert_failure
    run lyne cursor size 1000
    assert_failure
    run jq -c .cursor "$STATE"
    assert_output '{"theme":"breeze_cursors","size":32}'
    grep -q "Inherits=breeze_cursors" "$HOME/.icons/default/index.theme"
}

@test "lyne cursor status: the saved theme, else defaults.json; missing ones flagged" {
    fake_dots
    jq 'del(.cursor)' "$STATE" >"$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    run lyne cursor
    assert_success
    assert_line "Theme: Bibata-Modern-Classic, size 24"
    assert_line --regexp "^  ● Bibata-Modern-Classic +.*/usr/share/icons/Bibata-Modern-Classic$"
    assert_line --regexp "^  ○ Adwaita "
    refute_output --partial "not installed"
    jq '.cursor = {theme: "Gone", size: 32}' "$STATE" >"$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    run lyne cursor
    assert_line "Theme: Gone, size 32"
    assert_line --partial "not installed"
    run lyne cursor apply
    assert_failure
}

@test "uwsm env-hyprland: the saved cursor at login, the default without one" {
    local env="$REPO/hyprland/.config/uwsm/env-hyprland"
    mkdir -p "$HOME/.config/quickshell"
    printf '{"cursor":{"theme":"breeze_cursors","size":48}}' >"$STATE"
    run sh -c '. "$1"; echo "$XCURSOR_THEME $XCURSOR_SIZE $HYPRCURSOR_THEME $HYPRCURSOR_SIZE"' _ "$env"
    assert_output "breeze_cursors 48 breeze_cursors 48"
    printf '{"cursor":{"size":"big"}}' >"$STATE"
    run sh -c '. "$1"; echo "$XCURSOR_THEME $XCURSOR_SIZE"' _ "$env"
    assert_output "Bibata-Modern-Classic 24"
    rm "$STATE"
    run sh -c '. "$1"; echo "$XCURSOR_THEME $XCURSOR_SIZE ${_lyne_value-unset}"' _ "$env"
    assert_output "Bibata-Modern-Classic 24 unset"
}

# xcur FILE NOMINAL:SIDE[:FRAMES]...: an xcursor file whose images are filled
# with one premultiplied ARGB pixel (half-transparent red, 0x80800000)
xcur() {
    python3 - "$@" <<'PY'
import struct, sys
path, specs = sys.argv[1], [tuple(map(int, s.split(":"))) + (1,) for s in sys.argv[2:]]
images = [(n, side) for n, side, frames, *_ in specs for _ in range(frames)]
toc_at = 16
pos = toc_at + 12 * len(images)
toc, chunks = b"", b""
for nominal, side in images:
    toc += struct.pack("<III", 0xFFFD0002, nominal, pos)
    chunk = struct.pack("<9I", 36, 0xFFFD0002, nominal, 1, side, side, 1, 1, 50) + struct.pack("<I", 0x80800000) * side * side
    chunks += chunk
    pos += len(chunk)
open(path, "wb").write(b"Xcur" + struct.pack("<III", 16, 0x10000, len(images)) + toc + chunks)
PY
}

# png_info FILE: width height and the first pixel as r,g,b,a
png_info() {
    python3 - "$1" <<'PY'
import struct, sys, zlib
data = open(sys.argv[1], "rb").read()
assert data[:8] == b"\x89PNG\r\n\x1a\n"
w, h = struct.unpack(">II", data[16:24])
i, idat = 8, b""
while i < len(data):
    n, kind = struct.unpack(">I4s", data[i:i + 8])
    if kind == b"IDAT":
        idat += data[i + 8:i + 8 + n]
    i += 12 + n
raw = zlib.decompress(idat)
print(w, h, ",".join(map(str, raw[1:5])))
PY
}

# LYNE_TEST_SHELL: a copy of the shell (to sabotage the script)
preview() { python3 "${LYNE_TEST_SHELL:-$REPO/quickshell/.config/quickshell}/scripts/cursor-preview.py" "$@"; }

@test "previews: closest size, straight alpha, fallback names" {
    local t="$USER_ICONS/Mine"
    mkdir -p "$t/cursors"
    xcur "$t/cursors/left_ptr" 24:24 40:40:3 64:64
    xcur "$t/cursors/hand2" 32:30
    xcur "$t/cursors/xterm" 16:16
    printf 'not a cursor' >"$t/cursors/watch"
    run preview "$HOME/cache" Mine "$t"
    assert_success
    assert_output '{"Mine": ["default", "pointer", "text"]}'
    run png_info "$HOME/cache/Mine/default-24.png"
    assert_output "24 24 255,0,0,128"
    run png_info "$HOME/cache/Mine/default-32.png" # 24 and 40 tie: the larger
    assert_output --partial "40 40 "
    run png_info "$HOME/cache/Mine/default-48.png"
    assert_output --partial "40 40 "
    run png_info "$HOME/cache/Mine/default-64.png"
    assert_output --partial "64 64 "
    run png_info "$HOME/cache/Mine/pointer-64.png"
    assert_output --partial "30 30 "
    run ls "$HOME/cache/Mine"
    refute_output --partial wait
    refute_output --partial .tmp
}

@test "previews: made again only when the theme changes; gone themes removed" {
    local t="$USER_ICONS/Mine"
    mkdir -p "$t/cursors" "$HOME/cache/mine-by-hand"
    xcur "$t/cursors/left_ptr" 24:24
    preview "$HOME/cache" Mine "$t" Gone "$BATS_TEST_TMPDIR/nope"
    [[ -f "$HOME/cache/Gone/stamp" ]]
    touch -d 2001-01-01 "$HOME/cache/Mine/default-24.png"
    run preview "$HOME/cache" Mine "$t"
    assert_output '{"Mine": ["default"]}'
    run stat -c %Y "$HOME/cache/Mine/default-24.png"
    assert_output "$(date -d 2001-01-01 +%s)"
    [[ ! -e "$HOME/cache/Gone" && -d "$HOME/cache/mine-by-hand" ]]
    # A new cursor in the theme
    xcur "$t/cursors/xterm" 24:24
    touch -d '+1 minute' "$t/cursors"
    run preview "$HOME/cache" Mine "$t"
    assert_output '{"Mine": ["default", "text"]}'
}

@test "previews: odd ids and arguments" {
    run preview "$HOME/cache" "../x" "$SYSTEM_ICONS/Adwaita" "" "$SYSTEM_ICONS/Adwaita"
    assert_success
    assert_output "{}"
    [[ ! -e "$HOME/x" ]]
    run preview "$HOME/cache" Mine
    assert_failure
}
