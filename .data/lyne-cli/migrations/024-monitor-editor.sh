# 024-monitor-editor.sh - Monitors move to Settings › Hyprland › Monitors
#
# The monitor rules are now edited in Settings, which keeps them in
# state.json (monitors.rules) and generates ~/.config/hypr/monitors.lua.
# The rules of the monitors.lua written by nwg-displays (or by hand) are
# imported, by monitor description where the monitor is connected now, so
# monitors not connected today keep their rules too. The file itself stays
# as it is until the first Apply in Settings.

local monitors_file="$HOME/.config/hypr/monitors.lua"
local state="$HOME/.config/quickshell/state.json"

if [[ -f "$monitors_file" && -f "$state" ]] && command -v jq &>/dev/null &&
    ! head -n 1 "$monitors_file" | grep -q "managed by lyne" &&
    [[ "$(jq '(.monitors.rules // []) | length' "$state" 2>/dev/null)" == "0" ]]; then

    # Connected monitors, to move port rules to their descriptions
    local connected
    connected="$(hyprctl monitors all -j 2>/dev/null)"
    jq -e 'type == "array"' <<<"$connected" &>/dev/null || connected="[]"

    local rules
    rules="$(jq -R -s --argjson mons "$connected" '
        def value:
            if startswith("\"") then .[1:-1] | gsub("\\\\(?<c>.)"; .c)
            elif . == "true" then true
            elif . == "false" then false
            else tonumber + 0 end;
        # hl.monitor({ key = value, ... }) lines, comments skipped
        [split("\n")[]
            | select(test("^\\s*hl\\.monitor\\("))
            | (capture("\\{(?<body>.*)\\}").body // "")
            | [scan("([a-z_]+)\\s*=\\s*(\"(?:[^\"\\\\]|\\\\.)*\"|true|false|-?[0-9.]+)")]
            | map({ key: .[0], value: (.[1] | value) }) | from_entries
            | select((.output | type) == "string" and .output != "")]
        # Like Hyprland, a later call for the same output merges into the
        # earlier one and moves it last
        | reduce .[] as $r ([];
            ((map(select(.output == $r.output)) | first) // {}) as $old
            | map(select(.output != $r.output)) + [$old + $r])
        | map(. as $f | {
                output: $f.output,
                name: (if ($f.output | startswith("desc:")) then "" else $f.output end),
                disabled: ($f.disabled == true),
                mode: (if ($f.mode | type) == "string" then $f.mode else "preferred" end),
                position: (if ($f.position | type) == "string" then $f.position else "auto" end),
                scale: (if $f.scale == null or $f.scale == "auto" then "auto" else ($f.scale | tonumber) end),
                transform: ($f.transform // 0),
                mirror: (if ($f.mirror | type) == "string" then $f.mirror else "" end)
            }
            + (if $f.vrr != null then { vrr: $f.vrr } else {} end)
            + (if $f.bitdepth != null then { bitdepth: $f.bitdepth } else {} end)
            + (if ($f.cm | type) == "string" then { cm: $f.cm } else {} end)
            + (if $f.sdrbrightness != null then { sdrbrightness: $f.sdrbrightness } else {} end)
            + (if $f.sdrsaturation != null then { sdrsaturation: $f.sdrsaturation } else {} end))
        # Port rules of connected monitors: by description when it tells the
        # monitor apart (two alike stay by port)
        | map(. as $r |
            if ($r.output | startswith("desc:")) then .
            else
                ($mons | map(select(.name == $r.output and .name != "FALLBACK" and (.name | test("^HEADLESS") | not))) | first) as $m
                | if $m == null then .
                  else
                    ($m.description // "") as $d
                    | ($mons | map(select(.name != $m.name and (.description // "") == $d)) | length) as $alike
                    | .output = (if $d != "" and $alike == 0 then "desc:" + $d else $m.name end)
                    | .name = $m.name
                    | .label = (if ($m.model // "") != "" then $m.model elif $d != "" then $d else $m.name end)
                  end
            end)
    ' "$monitors_file")" || rules=""

    if [[ -n "$rules" && "$(jq 'length' <<<"$rules")" != "0" ]]; then
        local tmp
        tmp="$(mktemp)"
        if jq --argjson rules "$rules" '.monitors = ((.monitors // {}) + { rules: $rules })' "$state" >"$tmp"; then
            cat "$tmp" >"$state"
            echo "   Monitors are now set up in Settings › Hyprland › Monitors; imported $(jq 'length' <<<"$rules") rule(s) from monitors.lua"
        fi
        rm -f "$tmp"
    fi
fi
