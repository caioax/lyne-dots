#!/usr/bin/env bash

# Nome da workspace especial
SPECIAL="whatsapp"

# Salva a workspace atual
CURRENT_WS=$(hyprctl activewindow -j | jq -r '.workspace.id')

# Abre a workspace especial (dispara on-created-empty, que abre o app)
hyprctl dispatch togglespecialworkspace $SPECIAL

# Pequeno delay para garantir que o app começou a iniciar
sleep 0.5

# Volta para a workspace original
hyprctl dispatch togglespecialworkspace $SPECIAL
