# 026-autostart-page.sh - Autostart moves to Settings › System › Autostart
#
# Apps started at login are now kept in state.json (autostart.apps) and
# written by Quickshell to hypr/local/settings.lua. The commands of a
# hand-written hypr/local/autostart.lua are imported: Hyprland reads the
# file with a stand-in `hl` (lyne_autostart_import in conf/autostart.lua),
# so nothing runs and paths like vars.scriptPath come out resolved. The
# file is renamed to autostart.lua.imported once local/settings.lua starts
# them, so nothing starts twice. Files that also set up other things
# (binds, options) stay; without Hyprland or Quickshell running, the
# Autostart page offers the import instead.

local hypr_dir="$HOME/.config/hypr"
local file="$hypr_dir/local/autostart.lua"
local settings="$hypr_dir/local/settings.lua"
local state="$HOME/.config/quickshell/state.json"

_026_import() {
    [[ -f "$file" && -f "$state" ]] || return 0
    command -v jq &>/dev/null || return 0

    if ! hyprctl version &>/dev/null || ! pgrep -x quickshell &>/dev/null; then
        echo "   Your hypr/local/autostart.lua keeps working; import it from Settings › System › Autostart"
        return 0
    fi

    # The new conf/autostart.lua may not be loaded yet (git pull just ran)
    local probe="${XDG_RUNTIME_DIR:-/tmp}/lyne-026-probe"
    rm -f "$probe"
    hyprctl eval "local f = io.open('$probe', 'w'); f:write(type(lyne_autostart_import)); f:close()" &>/dev/null
    if [[ "$(cat "$probe" 2>/dev/null)" != "function" ]]; then
        hyprctl reload &>/dev/null
        sleep 1
    fi
    rm -f "$probe"

    local out="${XDG_RUNTIME_DIR:-/tmp}/lyne-026-import.json"
    rm -f "$out"
    hyprctl eval "if lyne_autostart_import then lyne_autostart_import('$file', '$out') end" &>/dev/null
    local result
    result="$(cat "$out" 2>/dev/null)"
    rm -f "$out"

    if ! jq -e '.ok == true' <<<"$result" &>/dev/null; then
        echo "   Couldn't read hypr/local/autostart.lua; it keeps working as it is"
        return 0
    fi
    if [[ "$(jq '.other' <<<"$result")" != "0" ]]; then
        echo "   hypr/local/autostart.lua also sets up other things, so it stays as it is"
        return 0
    fi

    # Only comments (the old template): nothing to import
    if [[ "$(jq '.apps | length' <<<"$result")" == "0" ]]; then
        mv -f "$file" "$file.imported"
        echo "   Autostart apps are now added in Settings › System › Autostart"
        return 0
    fi

    # Name from the command: ".../limitar_cpu.sh Base" -> "Limitar cpu"
    local apps
    apps="$(jq --argjson known "$(jq '[(.autostart.apps // [])[].command]' "$state")" '
        [.apps[] | select(.command as $c | $known | index($c) | not)
            | (.command | split(" ")[0] | split("/")[-1] | sub("\\.[A-Za-z0-9]+$"; "") | gsub("[-_]+"; " ")) as $base
            | {
                name: (if $base == "" then .command else ($base[0:1] | ascii_upcase) + $base[1:] end),
                command, desktop: "", delay, workspace, enabled: true
            }]' <<<"$result")" || return 0

    local backup
    backup="$(mktemp)"
    cp "$state" "$backup"
    local tmp
    tmp="$(mktemp)"
    if jq --argjson apps "$apps" '.autostart = ((.autostart // {}) + { apps: ((.autostart.apps // []) + $apps) })' "$state" >"$tmp"; then
        cat "$tmp" >"$state"
    fi
    rm -f "$tmp"

    # Quickshell writes them to local/settings.lua a moment later
    local first
    first="$(jq -r '.[0].command // empty' <<<"$apps")"
    for _ in {1..20}; do
        if [[ -z "$first" ]] || grep -qF "$first" "$settings" 2>/dev/null && grep -q "lyne_autostart({" "$settings"; then
            mv -f "$file" "$file.imported"
            echo "   Imported $(jq 'length' <<<"$apps") app(s) from hypr/local/autostart.lua to Settings › System › Autostart (the file is now autostart.lua.imported)"
            rm -f "$backup"
            return 0
        fi
        sleep 0.5
    done

    # Quickshell didn't write them: back as it was, the file keeps working
    cat "$backup" >"$state"
    rm -f "$backup"
    echo "   hypr/local/autostart.lua keeps working; import it from Settings › System › Autostart"
}

_026_import
unset -f _026_import
