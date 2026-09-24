# sync-state.sh - Merge state.json with defaults.json
#
# Preserves user values for keys that still exist in defaults.
# New keys from defaults get their default values.
# Old keys not present in defaults are discarded.
#
# Usage: source this file (expects $DOTS_DIR to be set)

local STATE_FILE="$DOTS_DIR/quickshell/.config/quickshell/state.json"
local DEFAULTS_FILE="$DOTS_DIR/.data/quickshell/defaults.json"

if [[ ! -f "$DEFAULTS_FILE" ]]; then
    echo "lyne sync: defaults.json not found at $DEFAULTS_FILE"
    return 1
fi

# If state.json doesn't exist, just copy defaults
if [[ ! -f "$STATE_FILE" ]]; then
    cp "$DEFAULTS_FILE" "$STATE_FILE"
    echo "lyne sync: created state.json from defaults"
    return 0
fi

# Deep merge: defaults defines structure, old state provides values.
# Every non-object value in defaults is a leaf, including false, null and
# whole arrays (paths(scalars) skipped false/null leaves, so user values like
# `true` over a `false` default and lists such as favorites were lost).
# Paths inside arrays are skipped: the user's array replaces the default one.
# A user value is only kept when its type matches the default (or the default
# is null), so keys whose type changed between versions get the new default;
# getpath is wrapped in try for the same reason.
local MERGED
MERGED=$(jq -s '
    .[0] as $defaults | .[1] as $old |
    $defaults | reduce (
        paths(type != "object") | select(all(.[]; type == "string"))
    ) as $p (
        .; ($old | try getpath($p) catch null) as $value
           | ($defaults | getpath($p)) as $default
           | if $value != null and ($default == null or ($value | type) == ($default | type))
             then setpath($p; $value)
             else .
             end
    )
' "$DEFAULTS_FILE" "$STATE_FILE")

if [[ $? -ne 0 ]]; then
    echo "lyne sync: failed to merge state.json (jq error)"
    return 1
fi

echo "$MERGED" > "$STATE_FILE"
echo "lyne sync: state.json synced with defaults"
