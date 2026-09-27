pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

ColumnLayout {
    id: root

    readonly property int buttonSize: Config.fontSizeIconSmall + Config.padding * 2
    // Where captures go when no folder is set, from xdg-user-dir
    property string defaultFolder: "~/Pictures/Screenshots"
    readonly property string folder: Config.screenshotFolder !== "" ? Config.screenshotFolder : root.defaultFolder

    // date(1) format → an example name, for the common fields
    function formatName(pattern: string): string {
        const now = new Date();
        const pad = n => String(n).padStart(2, "0");
        const fields = {
            Y: now.getFullYear(),
            y: pad(now.getFullYear() % 100),
            m: pad(now.getMonth() + 1),
            d: pad(now.getDate()),
            H: pad(now.getHours()),
            M: pad(now.getMinutes()),
            S: pad(now.getSeconds()),
            s: Math.floor(now.getTime() / 1000),
            F: `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`,
            T: `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`,
            "%": "%"
        };
        return pattern.replace(/%(.)/g, (match, field) => fields[field] ?? match).replace(/\//g, "-") + ".png";
    }

    function expandHome(path: string): string {
        return path.startsWith("~") ? Quickshell.env("HOME") + path.slice(1) : path;
    }

    spacing: Config.spacing * 3

    SettingsGroup {
        title: "Capture"

        SelectRow {
            label: "Opens in"
            description: {
                switch (Config.screenshotMode) {
                case "window":
                    return "Picks the window under the cursor; R, W and S switch modes";
                case "screen":
                    return "Takes the whole monitor under the cursor; R, W and S switch modes";
                default:
                    return "Drag to draw a region; R, W and S switch modes";
                }
            }
            path: "screenshot.mode"
            options: [
                {
                    label: "Region",
                    value: "region",
                    icon: "\u{f0a6d}"
                },
                {
                    label: "Window",
                    value: "window",
                    icon: "\u{f05af}"
                },
                {
                    label: "Screen",
                    value: "screen",
                    icon: "\u{f0379}"
                }
            ]
        }

        SettingRow {
            id: tryRow

            label: "Take a screenshot"
            description: "Closes Settings and opens the capture overlay · Print"

            ActionButton {
                icon: "\u{f0e51}"
                text: "Capture"
                size: root.buttonSize
                baseColor: tryRow.controlColor
                onClicked: {
                    SettingsService.close();
                    // Wait for the window to close so it isn't captured
                    ShortcutService.requestScreenshotAfter(Config.animDurationLong);
                }
            }
        }
    }

    SettingsGroup {
        title: "After capture"

        SelectRow {
            label: "Capture"
            description: {
                switch (Config.screenshotAction) {
                case "copy":
                    return "Copies it only; the notification can still save it";
                case "edit":
                    return "Opens it in Satty first; saved and copied once you save there";
                default:
                    return "Saves the file and copies it; the notification opens, edits or deletes it";
                }
            }
            path: "screenshot.action"
            segmentWidth: Config.fontSizeNormal * 8
            options: [
                {
                    label: "Save & copy",
                    value: "save",
                    icon: "\u{f0193}"
                },
                {
                    label: "Copy only",
                    value: "copy",
                    icon: "\u{f018f}"
                },
                {
                    label: "Edit first",
                    value: "edit",
                    icon: "\u{f03eb}"
                }
            ]
        }

        TextFieldRow {
            id: folderRow

            label: "Folder"
            description: "Empty uses your Pictures folder; ~ means your home"
            path: "screenshot.folder"
            placeholder: root.defaultFolder

            ActionButton {
                icon: "\u{f0968}"
                size: root.buttonSize
                baseColor: folderRow.controlColor
                onClicked: folderPicker.running = true
            }

            ActionButton {
                icon: "\u{f03cc}"
                size: root.buttonSize
                baseColor: folderRow.controlColor
                onClicked: Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "sh", root.expandHome(root.folder)])
            }
        }

        TextFieldRow {
            label: "File name"
            description: root.formatName(Config.screenshotFilename) + " · %Y %m %d %H %M %S = date and time"
            path: "screenshot.filename"
            fieldWidth: Config.fontSizeNormal * 20
            placeholder: StateService.getDefault("screenshot.filename", "")
        }
    }

    SettingsGroup {
        title: "Overlay"

        SliderRow {
            label: "Dimming"
            description: "How dark the screen gets outside the selection"
            path: "screenshot.dim"
            from: 0
            to: 90
            stepSize: 5
            format: v => v + "%"
        }

        ToggleRow {
            label: "Guides"
            description: "Dashed lines from the cursor, and then from the region, to the screen edges"
            path: "screenshot.guides"
        }

        ToggleRow {
            label: "Key hints"
            description: "The keys for what you are doing, under the control bar"
            path: "screenshot.hints"
        }

        ToggleRow {
            label: "Animations"
            description: "Animate the window and screen selections (a region follows the mouse as it is drawn)"
            path: "screenshot.animations"
        }
    }

    Process {
        running: true
        command: ["sh", "-c", 'dir="$(xdg-user-dir PICTURES 2>/dev/null)"; { [ -n "$dir" ] && [ "$dir" != "$HOME" ]; } || dir="$HOME/Pictures"; printf "%s/Screenshots" "$dir" | sed "s|^$HOME|~|"']
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    root.defaultFolder = text.trim();
            }
        }
    }

    Process {
        id: folderPicker
        command: ["sh", "-c", 'zenity --file-selection --directory --title="Screenshots folder" --filename="$1/" 2>/dev/null', "sh", root.expandHome(root.folder)]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path !== "")
                    StateService.set("screenshot.folder", path.replace(new RegExp("^" + Quickshell.env("HOME")), "~"));
            }
        }
    }
}
