#!/usr/bin/env bash

sudo mkdir -p /etc/libinput
sudo tee /etc/libinput/local-overrides.quirks >/dev/null <<ENDHERE
[Never Debounce]
MatchUdevType=mouse
ModelBouncingKeys=1
ENDHERE
