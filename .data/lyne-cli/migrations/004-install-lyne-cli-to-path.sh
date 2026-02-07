# Install lyne CLI script to ~/.local/bin and add it to the session PATH
# This replaces the old zsh function with a standalone bash script

cd "$DOTS_DIR" && stow -R local
echo "   Installed lyne CLI to PATH"
