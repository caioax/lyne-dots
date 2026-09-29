# lyne workspaces - Show the workspace blocks of each monitor

local EXPORT_FILE="${XDG_RUNTIME_DIR:-/tmp}/lyne-workspaces.json"
local MONITORS_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/lyne/workspace-monitors.lua"
local STATE_FILE="$DOTS_DIR/quickshell/.config/quickshell/state.json"
local subcmd="${1:-status}"

case "$subcmd" in
    -h|--help)
        echo "Usage: lyne workspaces [status]"
        echo ""
        echo "Each monitor has its own block of workspaces (hypr/conf/workspaces.lua),"
        echo "remembered by monitor also while disconnected. Change the order and the"
        echo "options in Settings › Hyprland › Workspaces."
        echo ""
        echo "Subcommands:"
        echo "  status    Monitors, their blocks, open workspaces and options (default)"
        ;;
    status)
        if ! command -v jq &>/dev/null; then
            echo "lyne workspaces: jq is required"
            return 1
        fi
        if [[ ! -f "$EXPORT_FILE" ]] || ! hyprctl version &>/dev/null; then
            echo "lyne workspaces: Hyprland isn't running here, or conf/workspaces.lua didn't load"
            echo "  (check with: hyprctl configerrors). Remembered monitors: $MONITORS_FILE"
            return 1
        fi

        local workspaces monitors
        workspaces="$(hyprctl workspaces -j)"
        monitors="$(hyprctl monitors -j)"

        echo "Workspaces per monitor"
        echo ""
        # One line per known monitor, then its open workspaces (windows in
        # parentheses) and the guests it holds from other blocks
        jq -r --argjson ws "$workspaces" --argjson mons "$monitors" '
            .block as $block | .max as $max | .monitors as $all |
            # N in the monitor own block, else N of <owner> (a guest)
            def shown($m; $id):
                if $id > $m.base and $id <= $m.base + $max then "\($id - $m.base)"
                else ($all | map(select($id > .base and $id <= .base + $max)) | first) as $o |
                    if $o then "\($id - $o.base) of \(if $o.desc != "" then $o.desc else $o.name end)" else "\($id)" end
                end;
            .monitors | sort_by(.slot)[] |
            . as $m |
            ($mons | map(select(.name == $m.connected)) | first) as $live |
            ($ws | map(select(.id > $m.base and .id <= $m.base + $max)) | sort_by(.id)) as $own |
            "  \($m.base + 1)–\($m.base + $max)  \(if $m.desc != "" then $m.desc else $m.name end)",
            "    " + (if $m.connected != ""
                then "\($m.connected)\(if $live.focused then " (focused)" else "" end) · showing \(shown($m; $live.activeWorkspace.id))"
                else "disconnected (last on \($m.name))" end),
            (if ($own | length) > 0 then
                "    open: " + ($own | map("\(.id - $m.base) (\(if .windows == 0 then "empty" elif .windows == 1 then "1 window" else "\(.windows) windows" end)\(if .monitor != $m.connected then ", on \(.monitor)" else "" end))") | join(" · "))
             else empty end),
            ""
        ' "$EXPORT_FILE"

        # Workspaces outside every known block (none normally)
        local stray
        stray="$(jq -r --argjson ws "$workspaces" '
            [.monitors[].base] as $bases | .max as $max |
            [$ws[] | select(.id > 0) | . as $w | select(all($bases[]; $w.id <= . or $w.id > . + $max))] |
            map("\(.id)@\(.monitor)") | join("  ")' "$EXPORT_FILE")"
        [[ -n "$stray" ]] && echo "  Outside every block: $stray" && echo ""

        local skip wrap lid lid_state="unknown"
        skip="$(jq -r 'if .workspaces.skipEmpty == true then "on" else "off" end' "$STATE_FILE" 2>/dev/null)"
        wrap="$(jq -r 'if .workspaces.wrap == true then "on" else "off" end' "$STATE_FILE" 2>/dev/null)"
        lid="$(jq -r 'if .workspaces.lidOff == false then "off" else "on" end' "$STATE_FILE" 2>/dev/null)"
        local lid_file
        for lid_file in /proc/acpi/button/lid/*/state; do
            [[ -f "$lid_file" ]] && lid_state="$(awk '{ print $2 }' "$lid_file")"
        done

        echo "Next/previous: skip empty ${skip:-off} · go around ${wrap:-off}"
        echo "Lid turns the laptop screen off: ${lid:-on} (lid $lid_state)"
        echo "Remembered monitors: $MONITORS_FILE"
        ;;
    *)
        echo "lyne workspaces: unknown subcommand '$subcmd'"
        echo "Run 'lyne workspaces --help' for usage."
        return 1
        ;;
esac
