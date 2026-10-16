pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// User profile shown in the Quick Settings header (custom avatar)
Singleton {
    id: root

    // Copy of the chosen picture; empty = placeholder silhouette
    readonly property string avatar: StateService.get("profile.avatar", "")
    readonly property string avatarDir: Quickshell.env("HOME") + "/.local/share/quickshell"

    function setAvatar(path: string) {
        StateService.set("profile.avatar", path);
    }

    function pickAvatar() {
        if (!pickProc.running)
            pickProc.running = true;
    }

    function resetAvatar() {
        setAvatar("");
    }

    // The picture is copied (with a unique name, so the Image cache doesn't
    // keep the old one) and survives the original being moved or deleted
    // The dialog's texts come translated as $1 and $2
    Process {
        id: pickProc
        command: ["bash", "-c", `
            file=$(zenity --file-selection --title="$1" --file-filter="$2 | *.png *.jpg *.jpeg *.webp" 2>/dev/null) || exit 0
            [ -f "$file" ] || exit 0
            dir="${root.avatarDir}"
            mkdir -p "$dir" && rm -f "$dir"/avatar-*
            dest="$dir/avatar-$(date +%s).\${file##*.}"
            cp "$file" "$dest" && echo "$dest"
        `, "bash", I18n.tr("Choose a profile picture"), I18n.tr("Images")]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path !== "")
                    root.setAvatar(path);
            }
        }
    }
}
