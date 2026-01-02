#!/usr/bin/env bash

CURRENT_ZOOM=$(hyprctl getoption cursor:zoom_factor | grep 'float' | cut -d' ' -f2)
ZOOM_FORCE=0.3

# Processa argumentos
for arg in "$@"; do
  case "$arg" in
  in | In)
    TARGET_ZOOM=$(echo "scale=6; $CURRENT_ZOOM * (1 + $ZOOM_FORCE)" | bc)
    TARGET_ZOOM=$(echo "scale=6; if ($TARGET_ZOOM > 60) 60 else $TARGET_ZOOM" | bc)

    hyprctl keyword cursor:zoom_factor $TARGET_ZOOM
    ;;
  out | out)
    TARGET_ZOOM=$(echo "scale=6; $CURRENT_ZOOM * (1 - $ZOOM_FORCE)" | bc)
    TARGET_ZOOM=$(echo "scale=6; if ($TARGET_ZOOM < 1) 1 else $TARGET_ZOOM" | bc)

    hyprctl keyword cursor:zoom_factor $TARGET_ZOOM
    ;;
  esac
done

