# 035-font-name.sh - The font is named as fontconfig lists it
#
# "Caskaydia Cove Nerd Font" only worked through fontconfig's loose matching;
# exact comparisons (kitty's font list, Qt without fontconfig) missed it. A
# state still on the old default gets the installed name; another font stays.

lyne_state_set 'if .typography.font == "Caskaydia Cove Nerd Font" then .typography.font = "CaskaydiaCove Nerd Font" else . end' || true
return 0
