#!/usr/bin/env bash

# Configura variáveis de ambiente para o ambiente gráfico
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

Mode="Auto"
NO_NOTIFY=false

# Função para enviar notificação
safe_notify() {
  if [ "$NO_NOTIFY" = false ] && [ -n "$DISPLAY" ] && [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && command -v notify-send >/dev/null 2>&1; then
    notify-send "FanMode: $Mode" "O modo das fans foi atualizado com sucesso!"
  fi
}

# Processa argumentos
for arg in "$@"; do
  case "$arg" in
  --no-notify)
    NO_NOTIFY=true
    ;;
  auto | Auto)
    Mode="Auto"
    ;;
  max | Max)
    Mode="Max"
    ;;
  *)
    Mode="Error"
    ;;
  esac
done

# Atualiza o modo das fans
if [ "$Mode" == "Auto" ]; then
  nbfc set -a
  safe_notify
elif [ "$Mode" == "Max" ]; then
  nbfc set -s 100
  safe_notify
else
  notify-send "Error" "Falha em atualizar o modo dos fans"
fi
