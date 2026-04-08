#!/usr/bin/env bash

# Special workspace name
SPECIAL="whatsapp"

# Save the current workspace
# CURRENT_WS=$(hyprctl activewindow -j | jq -r '.workspace.id')

# Open the special workspace (triggers on-created-empty, which opens the app)
hyprctl dispatch togglespecialworkspace $SPECIAL

# Small delay to ensure the app has started launching
sleep 0.5

# Return to the original workspace
hyprctl dispatch togglespecialworkspace $SPECIAL
