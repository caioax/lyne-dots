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

# Deep merge: defaults defines structure, old state provides values
local MERGED
MERGED=$(jq -s '
    .[0] as $defaults | .[1] as $old |
    $defaults | reduce (paths(scalars)) as $p (
        .; if ($old | getpath($p)) != null
           then setpath($p; $old | getpath($p))
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
