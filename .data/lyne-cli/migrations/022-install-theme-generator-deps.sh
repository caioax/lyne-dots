# 022-install-theme-generator-deps.sh - Install what theme creation needs
#
# Settings › Theme › New theme reads accent choices from a wallpaper
# (python-pillow) and can generate the lyne-dots wallpapers of a theme with
# .data/wallpapers/generator/generate.py (python-numpy, python-pillow and
# rsvg-convert from librsvg).

if command -v pacman &>/dev/null; then
    missing=()
    for pkg in python-numpy python-pillow librsvg; do
        pacman -Q "$pkg" &>/dev/null || missing+=("$pkg")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "   Installing ${missing[*]}..."
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    else
        echo "   python-numpy, python-pillow and librsvg already installed, skipping"
    fi
else
    for mod in numpy PIL; do
        python3 -c "import $mod" &>/dev/null || echo "   Python module $mod not found. Please install it manually."
    done
    command -v rsvg-convert &>/dev/null || echo "   rsvg-convert (librsvg) not found. Please install it manually."
fi
