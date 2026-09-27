# 015-install-tesseract.sh - Install tesseract with English and Portuguese
#
# The QuickShell screenshot overlay copies the text in a selection (Text
# button, T) with tesseract. Other languages: tesseract-data-<code>, then
# pick them in Settings › Screenshot › Copy text.

if command -v pacman &>/dev/null; then
    # Also covers tesseract installed without these languages
    missing=()
    for pkg in tesseract tesseract-data-eng tesseract-data-por; do
        pacman -Q "$pkg" &>/dev/null || missing+=("$pkg")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "   Installing ${missing[*]}..."
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    else
        echo "   tesseract and its languages already installed, skipping"
    fi
elif ! command -v tesseract &>/dev/null; then
    echo "   tesseract not found. Please install it manually."
fi
