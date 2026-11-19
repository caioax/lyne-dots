# 050-video-wallpaper-battery-auto.sh - "Pause on battery" follows the machine
#
# Settings › Wallpaper › Animated wallpapers › Pause on battery used to be
# off for everyone. Its default is now unset (null): on where there is a
# battery, so a video wallpaper stops draining a laptop away from the
# charger, off on desktops. lyne update kept the old default (false) in
# state.json, which reads as a choice: it goes back to unset here. Someone
# who turned it on keeps it on. The new frame rate cap (videoFps) arrives
# through the usual state sync.

source "$DOTS_DIR/.data/lyne-cli/lib/state.sh"

local state
state="$(lyne_state_file)"
if [[ -f "$state" ]] && command -v jq &>/dev/null \
    && jq -e '.wallpaper.pauseOnBattery == false' "$state" &>/dev/null; then
    lyne_state_set '.wallpaper.pauseOnBattery = null' &&
        echo "   Video wallpapers pause on battery on laptops now (Settings › Wallpaper)"
fi
return 0
