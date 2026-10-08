# 027-keyboards-page.sh - Per-keyboard layouts move to Settings › Hyprland › Keyboard
#
# Keyboards with their own layouts are now kept in state.json
# (keyboard.devices) and written by Quickshell to hypr/local/settings.lua as
# hl.device() lines. The hl.device() calls of a hand-written
# hypr/local/extra_input.lua are imported: Hyprland reads the file with a
# stand-in `hl` (lyne_keyboard_import in conf/input.lua), so nothing runs,
# and checks each layout and variant against xkeyboard-config. Interfaces of
# one keyboard ("name", "name-1") become one entry. The file is renamed to
# extra_input.lua.imported once local/settings.lua has the rules, so the
# keyboards never lose their layout. Files that also set up other things
# stay; without Hyprland or Quickshell running, the Keyboard page offers the
# import instead.

local hypr_dir="$HOME/.config/hypr"
local file="$hypr_dir/local/extra_input.lua"
local settings="$hypr_dir/local/settings.lua"
local state="$HOME/.config/quickshell/state.json"

_027_import() {
    [[ -f "$file" && -f "$state" ]] || return 0
    command -v jq &>/dev/null || return 0

    if ! hyprctl version &>/dev/null || ! pgrep -x quickshell &>/dev/null; then
        echo "   Your hypr/local/extra_input.lua keeps working; import it from Settings › Hyprland › Keyboard"
        return 0
    fi

    # The new conf/input.lua may not be loaded yet (git pull just ran)
    local probe="${XDG_RUNTIME_DIR:-/tmp}/lyne-027-probe"
    rm -f "$probe"
    hyprctl eval "local f = io.open('$probe', 'w'); f:write(type(lyne_keyboard_import)); f:close()" &>/dev/null
    if [[ "$(cat "$probe" 2>/dev/null)" != "function" ]]; then
        hyprctl reload &>/dev/null
        sleep 1
    fi
    rm -f "$probe"

    local out="${XDG_RUNTIME_DIR:-/tmp}/lyne-027-import.json"
    rm -f "$out"
    hyprctl eval "if lyne_keyboard_import then lyne_keyboard_import('$file', '$out') end" &>/dev/null
    local result
    result="$(cat "$out" 2>/dev/null)"
    rm -f "$out"

    if ! jq -e '.ok == true' <<<"$result" &>/dev/null; then
        echo "   Couldn't read hypr/local/extra_input.lua; it keeps working as it is"
        return 0
    fi
    if [[ "$(jq '.other' <<<"$result")" != "0" ]]; then
        echo "   hypr/local/extra_input.lua also sets up other things, so it stays as it is"
        return 0
    fi
    jq -r '.notes[]' <<<"$result" | sed 's/^/   /'

    if [[ "$(jq '.devices | length' <<<"$result")" == "0" ]]; then
        mv -f "$file" "$file.imported"
        echo "   Keyboards with their own layouts are now set in Settings › Hyprland › Keyboard"
        return 0
    fi

    # One entry per keyboard ("name-1" joins "name"); keyboards already set
    # up in Settings stay as they are
    local devices
    devices="$(jq --argjson known "$(jq '[(.keyboard.devices // [])[].name]' "$state")" '
        reduce .devices[] as $d ([];
            ($d.name | sub("-[0-9]+$"; "")) as $base
            | if ($known | index($base)) then .
              else
                ((map(select(.name == $base)) | first) // { name: $base, names: [] }) as $old
                | ($old
                    | .names = ((.names + [$d.name]) | unique)
                    | if $d.kb_layout != null then .layout = $d.kb_layout | .variant = ($d.kb_variant // "") else . end
                    | if $d.kb_options != null then .options = $d.kb_options else . end
                    | if $d.kb_model != null then .model = $d.kb_model else . end) as $new
                | map(select(.name != $base)) + [$new]
              end)' <<<"$result")" || return 0

    local backup
    backup="$(mktemp)"
    cp "$state" "$backup"
    local tmp
    tmp="$(mktemp)"
    if jq --argjson devices "$devices" '.keyboard = ((.keyboard // {}) + { devices: ((.keyboard.devices // []) + $devices) })' "$state" >"$tmp"; then
        lyne_state_replace <"$tmp"
    fi
    rm -f "$tmp"

    # Quickshell writes them to local/settings.lua a moment later
    local first
    first="$(jq -r '.[0].names[0] // empty' <<<"$devices")"
    for _ in {1..20}; do
        if [[ -z "$first" ]] || grep -qF "hl.device({ name = \"$first\"" "$settings" 2>/dev/null; then
            mv -f "$file" "$file.imported"
            echo "   Imported $(jq 'length' <<<"$devices") keyboard(s) from hypr/local/extra_input.lua to Settings › Hyprland › Keyboard (the file is now extra_input.lua.imported)"
            rm -f "$backup"
            return 0
        fi
        sleep 0.5
    done

    # Quickshell didn't write them: back as it was, the file keeps working
    lyne_state_replace <"$backup"
    rm -f "$backup"
    echo "   hypr/local/extra_input.lua keeps working; import it from Settings › Hyprland › Keyboard"
}

_027_import
unset -f _027_import
