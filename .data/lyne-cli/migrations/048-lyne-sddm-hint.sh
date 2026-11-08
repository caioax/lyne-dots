# 048-lyne-sddm-hint.sh - Point SDDM users to the lyne-sddm login screen
#
# New installs ask whether to build lyne-sddm (a login screen in the lock
# screen's style that follows the theme). Existing installs only get a hint,
# once: changing someone's login screen during lyne update without asking
# would be a surprise, and the build needs sudo. Nothing is installed here.
# Where SDDM isn't the display manager, or lyne-sddm is already installed,
# it says nothing.

source "$DOTS_DIR/.data/lyne-cli/lib/sddm.sh"

if [[ "$(sddm_dm)" == sddm ]] && ! pacman -Q lyne-sddm-git &>/dev/null && ! pacman -Q lyne-sddm &>/dev/null; then
    echo "   New: lyne-sddm, a login screen in the lock screen's style that follows"
    echo "   the theme. Install it with: lyne sddm install"
fi
true
