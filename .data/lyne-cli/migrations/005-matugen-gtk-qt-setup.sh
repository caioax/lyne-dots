# Setup matugen, switch GTK to adw-gtk3-dark, configure Qt color scheme path

fail() {
    echo -e "\e[1;31m   Error: $1\e[0m"
}
# Install packages if missing
if ! command -v matugen &>/dev/null; then
    echo "   Installing matugen..."
    sudo pacman -S --noconfirm matugen || fail "failed to install matugen"
fi

if [[ ! -d /usr/share/themes/adw-gtk3-dark ]]; then
    echo "   Installing adw-gtk3..."
    sudo pacman -S --noconfirm adw-gtk-theme ||
        yay -S --noconfirm adw-gtk3 ||
        fail "failed to install adw-gtk3"
fi

# Create required directories
mkdir -p "$HOME/.cache/matugen"
mkdir -p "$HOME/.local/share/color-schemes"
mkdir -p "$HOME/.config/matugen"

# Symlink matugen config
ln -sf "$DOTS_DIR/.data/matugen/config.toml" "$HOME/.config/matugen/config.toml"

# Update Qt color scheme paths to point to local Lyne.colors
local qt_color_path="$HOME/.local/share/color-schemes/Lyne.colors"
for conf in "$DOTS_DIR/theming/.config/qt5ct/qt5ct.conf" "$DOTS_DIR/theming/.config/qt6ct/qt6ct.conf"; do
    if [[ -f "$conf" ]]; then
        sed -i "s|color_scheme_path=.*|color_scheme_path=$qt_color_path|g" "$conf"
    fi
done

# Update GTK theme via gsettings
gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" 2>/dev/null || true

# Re-stow theming to pick up new files (gtk.css, updated settings.ini)
cd "$DOTS_DIR" && stow -R theming

# Sync state.json to pick up new theme.mode default
source "$DOTS_DIR/.data/lyne-cli/lib/sync-state.sh"

echo "   Matugen + GTK/Qt dynamic theming configured"
