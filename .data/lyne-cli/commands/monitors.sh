# lyne monitors - Monitor rules set up in Settings › Hyprland › Monitors

local MONITORS_FILE="$HOME/.config/hypr/local/monitors.lua"
# Where nwg-displays writes; hyprland.lua only reads it without the one above
local LEGACY_FILE="$HOME/.config/hypr/monitors.lua"
local STATE_FILE="$DOTS_DIR/quickshell/.config/quickshell/state.json"
local SCRIPT="$DOTS_DIR/quickshell/.config/quickshell/scripts/monitors.sh"
local TRIAL_MARK="${XDG_RUNTIME_DIR:-/tmp}/lyne-monitors-trial"
local subcmd="${1:-status}"

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne monitors [status|revert|reset]"
        echo ""
        echo "Resolution, refresh rate, scale, position, rotation and mirroring of"
        echo "each monitor are set in Settings › Hyprland › Monitors, which writes"
        echo "~/.config/hypr/local/monitors.lua. Applying there is a trial: it reverts on"
        echo "its own unless you keep it."
        echo ""
        echo "Subcommands:"
        echo "  status    Monitors, their saved rules and the state of monitors.lua (default)"
        echo "  revert    Drop a trial in progress now (reloads the saved monitors.lua)"
        echo "  reset     Emergency: replace monitors.lua with automatic settings for"
        echo "            every monitor (the old file is kept as monitors.lua.bak)"
        ;;
    status)
        if ! command -v jq &>/dev/null; then
            echo "lyne monitors: jq is required"
            return 1
        fi
        local monitors
        if ! monitors="$(hyprctl monitors all -j 2>/dev/null)" || ! jq -e 'type == "array"' <<<"$monitors" &>/dev/null; then
            echo "lyne monitors: Hyprland isn't running here (use 'lyne monitors reset' to go back to automatic settings)"
            return 1
        fi
        local rules
        rules="$(jq -c '.monitors.rules // []' "$STATE_FILE" 2>/dev/null || echo '[]')"

        echo "Monitors"
        echo ""
        # One block per output: what it shows now and the rule saved for it
        # (by description, else by port)
        local file_text=""
        if [[ -f "$MONITORS_FILE" ]]; then
            file_text="$(cat "$MONITORS_FILE")"
        elif [[ -f "$LEGACY_FILE" ]]; then
            file_text="$(cat "$LEGACY_FILE")"
        fi
        jq -r --argjson rules "$rules" --arg file "$file_text" '
            .[] | select(.name != "FALLBACK" and (.name | test("^HEADLESS") | not)) | . as $m |
            ($rules | map(select(.output == "desc:" + ($m.description // "") or .output == $m.name)) | first) as $r |
            # Not saved in Settings yet: a rule for it in the file itself
            ($file | contains("output = \"\($m.name)\"")
                or (($m.description // "") != "" and contains("output = \"desc:\($m.description)"))) as $in_file |
            "  \(if ($m.model // "") != "" then $m.model else $m.name end) · \($m.name)",
            "    " + (if $m.disabled then "off"
                else "\($m.width)x\($m.height) @ \($m.refreshRate * 100 | round / 100) Hz · at \($m.x),\($m.y) · scale \($m.scale)"
                    + (if $m.transform != 0 then " · rotated (\($m.transform))" else "" end)
                    + (if $m.mirrorOf != "none" then " · mirroring" else "" end)
                    + (if $m.vrr then " · VRR" else "" end) end),
            "    " + (if $r != null then "saved as \($r.output)"
                elif $in_file then "rule in monitors.lua, not saved in Settings yet"
                else "no rule (automatic)" end),
            ""
        ' <<<"$monitors"

        # Rules of monitors not connected now, kept for when they return
        local away
        away="$(jq -r --argjson mons "$monitors" '
            map(select(. as $r | $mons | map(select($r.output == "desc:" + (.description // "") or $r.output == .name)) | length == 0))
            | .[] | "  \(.label // .output)" + (if .name != "" and .name != null then " (last on \(.name))" else "" end)
        ' <<<"$rules")"
        if [[ -n "$away" ]]; then
            echo "Saved for monitors not connected now"
            echo "$away"
            echo ""
        fi

        if [[ ! -f "$MONITORS_FILE" && -f "$LEGACY_FILE" ]] && head -n 1 "$LEGACY_FILE" | grep -q "managed by lyne"; then
            echo "monitors.lua: still in ~/.config/hypr (loaded from there) — 'lyne migrate' moves it to hypr/local/, and so does the next Apply in Settings"
        elif [[ ! -f "$MONITORS_FILE" && -f "$LEGACY_FILE" ]]; then
            echo "monitors.lua: ~/.config/hypr/monitors.lua from nwg-displays (loaded from there) — Settings moves it to hypr/local/ on the first Apply"
        elif [[ ! -f "$MONITORS_FILE" ]]; then
            echo "monitors.lua: missing (Hyprland uses automatic settings)"
        elif head -n 1 "$MONITORS_FILE" | grep -q "managed by lyne"; then
            local want loaded
            want="$(sed -nE 's/^lyne_monitors_file = "([^"]*)".*/\1/p' "$MONITORS_FILE" | tail -n 1)"
            loaded="$(bash "$SCRIPT" loaded)"
            if [[ "$loaded" == "$want" ]]; then
                echo "monitors.lua: written by Settings, loaded by Hyprland"
            else
                echo "monitors.lua: written by Settings, but Hyprland didn't run it (check: hyprctl configerrors)"
            fi
        else
            echo "local/monitors.lua: written by hand — Settings rewrites it on the first Apply"
        fi
        if [[ -f "$MONITORS_FILE" && -f "$LEGACY_FILE" ]]; then
            echo "Old ~/.config/hypr/monitors.lua (nwg-displays?) isn't read: load or remove it in Settings"
        fi
        if [[ -f "$TRIAL_MARK" ]]; then
            echo "Trial in progress: reverts on its own unless kept in Settings (or now: lyne monitors revert)"
        fi
        ;;
    revert)
        bash "$SCRIPT" revert >/dev/null
        echo "Reloaded the saved monitors.lua"
        ;;
    reset)
        if [[ -f "$MONITORS_FILE" ]]; then
            cp -f "$MONITORS_FILE" "$MONITORS_FILE.bak"
        fi
        mkdir -p "$(dirname "$MONITORS_FILE")"
        local tmp="$HOME/.config/hypr/.monitors.lua.new"
        cat >"$tmp" <<'EOF'
-- Monitors: managed by lyne (Settings › Hyprland › Monitors)
-- Reset by `lyne monitors reset`: automatic settings for every monitor

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

lyne_monitors_file = "automatic"
EOF
        mv -f "$tmp" "$MONITORS_FILE"
        rm -f "$TRIAL_MARK"
        hyprctl reload &>/dev/null || true
        echo "monitors.lua reset to automatic settings (old one: monitors.lua.bak)."
        echo "Set them up again in Settings › Hyprland › Monitors."
        ;;
    *)
        echo "lyne monitors: unknown subcommand '$subcmd'"
        echo "Run 'lyne monitors --help' for usage."
        return 1
        ;;
esac
