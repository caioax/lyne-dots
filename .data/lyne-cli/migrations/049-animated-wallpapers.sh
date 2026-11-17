# 049-animated-wallpapers.sh - mpvpaper and ffmpeg for video wallpapers
#
# Wallpapers can be videos now (mp4, webm, mkv): mpvpaper plays them, ffmpeg
# makes their poster (the still for colors, thumbnails, the lock and login
# screens) and scales large ones down when added. Where the shell's packages
# are (quickshell): ffmpeg from the repos when missing (new installs only had
# it with the editor category) and mpvpaper from the AUR. A failed mpvpaper
# build only warns: images keep working, and a video shows its poster until
# mpvpaper is there.

if command -v pacman &>/dev/null && { pacman -Q quickshell-git &>/dev/null || pacman -Q quickshell &>/dev/null; }; then
    if pacman -Q ffmpeg &>/dev/null; then
        echo "   ffmpeg already installed, skipping"
    else
        echo "   Installing ffmpeg..."
        sudo pacman -S --needed --noconfirm ffmpeg ||
            echo "   ffmpeg didn't install: run sudo pacman -S ffmpeg to add video wallpapers"
    fi

    if pacman -Q mpvpaper &>/dev/null; then
        echo "   mpvpaper already installed, skipping"
    elif command -v yay &>/dev/null; then
        echo "   Installing mpvpaper (AUR)..."
        yay -S --needed --noconfirm mpvpaper ||
            echo "   mpvpaper didn't build: try yay -S mpvpaper later; until then a video wallpaper shows its first frame"
    elif command -v paru &>/dev/null; then
        echo "   Installing mpvpaper (AUR)..."
        paru -S --needed --noconfirm mpvpaper ||
            echo "   mpvpaper didn't build: try paru -S mpvpaper later; until then a video wallpaper shows its first frame"
    else
        echo "   No AUR helper (yay/paru) found. Install mpvpaper manually to play video wallpapers."
    fi
fi
true
