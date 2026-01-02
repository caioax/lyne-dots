#!/usr/bin/env bash

export WAYLAND_DISPLAY="wayland-1"
export XDG_RUNTIME_DIR="/run/user/1000"
export HYPRLAND_INSTANCE_SIGNATURE="967c3c7404d4fa00234e29c70df3e263386d2597_1764711838_178427695"

# Arquivo do estado
STATE_FILE="$HOME/Scripts/HyprSun/state.txt"

# Temperatura padrão
TEMP=4400

# Modo On/Off
STATE="empty"

toggle_mode() {
  if [[ "$(cat "$STATE_FILE")" = "on" ]]; then
    STATE="off"
  else
    STATE="on"
  fi
}

# Processa argumentos
for arg in "$@"; do
  case "$arg" in
  On | on)
    STATE="on"
    ;;
  Off | off)
    STATE="off"
    ;;
  Toggle | toggle)
    toggle_mode
    ;;
  esac
done

if [[ $MODE = "empty" ]]; then
  echo "Sem arqumentos, use on|off|toggle"
  exit 1
fi

# Salvando o estado da luz noturna
echo $STATE >$STATE_FILE

# Aplica a mudança
if [[ $STATE = "on" ]]; then
  killall hyprsunset
  hyprsunset --temperature $TEMP
else
  killall hyprsunset
fi

exit 0
