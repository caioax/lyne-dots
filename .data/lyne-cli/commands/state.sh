# lyne state - Open state.json in the configured editor

local config_path="$DOTS_DIR/quickshell/.config/quickshell/state.json"
local default_editor="nvim"

local custom_editor
custom_editor=$(jq -r '.system.editor // empty' "$config_path" 2>/dev/null)

if [[ -n "$custom_editor" && "$custom_editor" != "null" ]] && command -v "${custom_editor%% *}" >/dev/null 2>&1; then
    eval "$custom_editor $config_path"
else
    [[ -n "$custom_editor" && "$custom_editor" != "null" ]] && \
        echo "lyne state: editor '$custom_editor' not found, falling back to $default_editor"
    $default_editor "$config_path"
fi
