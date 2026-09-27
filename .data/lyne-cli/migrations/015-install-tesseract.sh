# 015-install-tesseract.sh - Install tesseract with English and Portuguese
#
# The QuickShell screenshot overlay copies the text in a selection (Text
# button, T) with tesseract. Other languages: tesseract-data-<code>, then
# pick them in Settings › Screenshot › Copy text.

if ! command -v tesseract &>/dev/null; then
    if command -v pacman &>/dev/null; then
        echo "   Installing tesseract..."
        sudo pacman -S --needed --noconfirm tesseract tesseract-data-eng tesseract-data-por
    else
        echo "   tesseract not found. Please install it manually."
    fi
else
    echo "   tesseract already installed, skipping"
fi
