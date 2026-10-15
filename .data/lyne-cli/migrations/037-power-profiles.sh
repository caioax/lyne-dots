# 037-power-profiles.sh - Power profiles daemon on laptops
#
# Quick Settings and Settings › System › Power profiles switch between power
# saver, balanced and performance through power-profiles-daemon. Laptops
# with no daemon and no TLP, TuneD or auto-cpufreq get it installed and
# enabled; everything else is left as it is (Settings offers tlp-pd or
# tuned-ppd to whoever runs TLP or TuneD, and an Install button on desktops).

if command -v pacman &>/dev/null; then
    source "$DOTS_DIR/.data/lyne-cli/lib/power-profiles.sh"
    pp_auto_install
else
    echo "   pacman not found: install power-profiles-daemon and enable its service for power profiles"
fi
