pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// User profile shown in the Quick Settings header (custom avatar)
Singleton {
    id: root

    // Copy of the chosen picture; empty = distro logo
    property string avatar: StateService.get("profile.avatar", "")
    readonly property string avatarDir: Quickshell.env("HOME") + "/.local/share/quickshell"

    Connections {
        target: StateService

        function onStateLoaded() {
            root.avatar = StateService.get("profile.avatar", "");
        }
    }

    function setAvatar(path: string) {
        avatar = path;
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
    Process {
        id: pickProc
        command: ["bash", "-c", `
            file=$(zenity --file-selection --title="Choose a profile picture" --file-filter="Images | *.png *.jpg *.jpeg *.webp" 2>/dev/null) || exit 0
            [ -f "$file" ] || exit 0
            dir="${root.avatarDir}"
            mkdir -p "$dir" && rm -f "$dir"/avatar-*
            dest="$dir/avatar-$(date +%s).\${file##*.}"
            cp "$file" "$dest" && echo "$dest"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path !== "")
                    root.setAvatar(path);
            }
        }
    }
}
