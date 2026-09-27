# 016-install-lyne-icons.sh - Install the lyne-dots logo as a system icon
#
# `lyne update` notifications use the "lyne-dots" icon. From now on every
# update refreshes it; this covers the first one.

echo "   Installing the lyne-dots icon..."
source "$DOTS_DIR/.data/lyne-cli/lib/install-icons.sh"
