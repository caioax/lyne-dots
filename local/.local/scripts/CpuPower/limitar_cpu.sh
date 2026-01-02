#!/usr/bin/env bash

# Detecta ambiente gráfico automaticamente
export DISPLAY=:0
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# Captura o DBUS da sessão atual (KDE, GNOME, etc.)
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
  DBUS_SESSION_BUS_ADDRESS=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u $USER -x plasmashell || pgrep -u $USER -x gnome-shell)/environ | cut -d= -f2-)
  export DBUS_SESSION_BUS_ADDRESS
fi

# Frequências pré-definidas (ajuste conforme seu processador)
FREQ_LOW="1.0GHz"
FREQ_BASE="2.3GHz"
FREQ_HIGH="3.0GHz"
FREQ_ULTRA="3.9GHz"
FREQ_MAX="4.6GHz" # valor especial usado pelo cpupower para "sem limite"

# Valores padrão
FREQ_ALVO="$FREQ_BASE"
PROFILE_NAME="Base"
NO_NOTIFY=false

show_help() {
  echo "Uso: limitarcpu [Perfil|Valor] [--no-notify]"
  echo
  echo "Perfis disponíveis:"
  echo "  Low     → $FREQ_LOW"
  echo "  Base  → $FREQ_BASE"
  echo "  High    → $FREQ_HIGH"
  echo "  Ultra   → $FREQ_ULTRA"
  echo "  Max     → Frequência máxima suportada (sem limite)"
  echo
  echo "Também é possível passar um valor manual, ex: 2.5GHz"
  echo
  echo "Opções:"
  echo "  --no-notify   Executa sem mostrar notificação"
  echo "  -h, --help    Mostra esta ajuda"
  exit 0
}

# Processa argumentos
for arg in "$@"; do
  case "$arg" in
  --no-notify)
    NO_NOTIFY=true
    ;;
  -h | --help)
    show_help
    ;;
  Low | low)
    FREQ_ALVO="$FREQ_LOW"
    PROFILE_NAME="Low"
    ;;
  Base | base)
    FREQ_ALVO="$FREQ_BASE"
    PROFILE_NAME="Base"
    ;;
  High | high)
    FREQ_ALVO="$FREQ_HIGH"
    PROFILE_NAME="High"
    ;;
  Ultra | ultra)
    FREQ_ALVO="$FREQ_ULTRA"
    PROFILE_NAME="Ultra"
    ;;
  Max | max)
    FREQ_ALVO="$FREQ_MAX"
    PROFILE_NAME="Max"
    ;;
  *)
    # Se não for palavra-chave, assume valor manual
    FREQ_ALVO="$arg"
    PROFILE_NAME="Custom"
    ;;
  esac
done

# Função para enviar notificação
function safe_notify {
  if [ "$NO_NOTIFY" = false ] && [ -n "$DISPLAY" ] && [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && command -v notify-send >/dev/null 2>&1; then
    notify-send "FreqCPU: $PROFILE_NAME" "Frequência máxima definida para $FREQ_ALVO"
  fi
}

# Tenta definir a nova frequência
if sudo -n /usr/bin/cpupower frequency-set -u "$FREQ_ALVO"; then

  safe_notify
else
  notify-send "FreqCPU: Erro" "Falha ao definir frequência para $FREQ_ALVO"
fi
