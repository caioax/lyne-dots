# 001-example.sh - Example migration
#
# This is a template showing how migrations work.
# Each migration runs once during "lyne update" and never again.
#
# You have access to $DOTS_DIR and can do anything here:
#   - mkdir -p "$HOME/.config/something"
#   - cp "$DOTS_DIR/.data/some-template" "$HOME/.config/something/"
#   - sudo pacman -S --needed --noconfirm some-package
#   - rm -rf "$HOME/.config/old-thing"
#
# If the script returns non-zero (fails), the migration chain stops
# and it will retry next time you run "lyne update".

echo "     Example migration executed successfully"
