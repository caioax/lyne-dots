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

    // tesseract --list-langs, without "osd" (script detection); null while
    // unknown, [] when tesseract isn't installed
    property var ocrInstalled: null
    readonly property var ocrChoices: {
        const installed = root.ocrInstalled ?? [];
        return [...installed, ...Config.screenshotOcrLanguages.filter(l => !installed.includes(l))];
    }
    readonly property var languageNames: ({
            eng: "English",
            por: "Português",
            spa: "Español",
            fra: "Français",
            deu: "Deutsch",
            ita: "Italiano",
            jpn: "日本語",
            chi_sim: "简体中文",
            chi_tra: "繁體中文",
            kor: "한국어",
            rus: "Русский"
        })

    function toggleLanguage(lang: string) {
        const current = Config.screenshotOcrLanguages;
        const next = current.includes(lang) ? current.filter(l => l !== lang) : [...current, lang];
        // Keep at least one
        if (next.length > 0)
            StateService.set("screenshot.ocrLanguages", next);
    }

    function expandHome(path: string): string {
        return path.startsWith("~") ? Quickshell.env("HOME") + path.slice(1) : path;
    }

    spacing: Config.spacing * 3

    SettingsGroup {
        title: I18n.tr("Capture")

        SelectRow {
            label: I18n.tr("Opens in")
            description: {
                switch (Config.screenshotMode) {
                case "window":
                    return I18n.tr("Picks the window under the cursor; R, W and S switch modes");
                case "screen":
                    return I18n.tr("Takes the whole monitor under the cursor; R, W, S and C switch modes");
                case "color":
                    return I18n.tr("Magnifies the pixels under the cursor, a click copies the color; R, W, S and C switch modes");
                default:
                    return I18n.tr("Drag to draw a region; R, W, S and C switch modes");
                }
            }
            path: "screenshot.mode"
            options: [
                {
                    label: I18n.tr("Region"),
                    value: "region",
                    icon: "\u{f0a6d}"
                },
                {
                    label: I18n.tr("Window"),
                    value: "window",
                    icon: "\u{f05af}"
                },
                {
                    label: I18n.tr("Screen"),
                    value: "screen",
                    icon: "\u{f0379}"
                },
                {
                    label: I18n.tr("Color"),
                    value: "color",
                    icon: "\u{f020a}"
                }
            ]
        }

        SelectRow {
            label: I18n.tr("Color format")
            description: I18n.tr("How color mode copies it, like %1", {
                    hex: "#7aa2f7",
                    rgb: "rgb(122, 162, 247)",
                    hsl: "hsl(221, 89%, 72%)"
                }[Config.screenshotColorFormat])
            path: "screenshot.colorFormat"
            segmentWidth: Config.fontSizeNormal * 5
            options: [
                {
                    label: "HEX",
                    value: "hex"
                },
                {
                    label: "RGB",
                    value: "rgb"
                },
                {
                    label: "HSL",
                    value: "hsl"
                }
            ]
        }

        SettingRow {
            id: tryRow

            label: I18n.tr("Take a screenshot")
            description: I18n.tr("Closes Settings and opens the capture overlay · Print")

            ActionButton {
                icon: "\u{f0e51}"
                text: I18n.tr("Capture")
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
        title: I18n.tr("After capture")

        SelectRow {
            label: I18n.tr("Capture")
            description: {
                switch (Config.screenshotAction) {
                case "copy":
                    return I18n.tr("Copies it only; the notification can still save it");
                case "edit":
                    return I18n.tr("Opens it in Satty first; saved and copied once you save there");
                default:
                    return I18n.tr("Saves the file and copies it; the notification opens, edits or deletes it");
                }
            }
            path: "screenshot.action"
            segmentWidth: Config.fontSizeNormal * 8
            options: [
                {
                    label: I18n.tr("Save & copy"),
                    value: "save",
                    icon: "\u{f0193}"
                },
                {
                    label: I18n.tr("Copy only"),
                    value: "copy",
                    icon: "\u{f018f}"
                },
                {
                    label: I18n.tr("Edit first"),
                    value: "edit",
                    icon: "\u{f03eb}"
                }
            ]
        }

        TextFieldRow {
            id: folderRow

            label: I18n.tr("Folder")
            description: I18n.tr("Empty uses your Pictures folder; ~ means your home")
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
            label: I18n.tr("File name")
            description: I18n.tr("%1 · %Y %m %d %H %M %S = date and time", root.formatName(Config.screenshotFilename))
            path: "screenshot.filename"
            fieldWidth: Config.fontSizeNormal * 20
            placeholder: StateService.getDefault("screenshot.filename", "")
        }
    }

    SettingsGroup {
        title: I18n.tr("Copy text")

        SettingRow {
            label: I18n.tr("Languages")
            description: {
                if (root.ocrInstalled === null)
                    return I18n.tr("Looking for tesseract…");
                if (root.ocrInstalled.length === 0)
                    return I18n.tr("Install tesseract and a tesseract-data-<language> package to copy the text in a selection");
                return I18n.tr("Text (T in the overlay) reads the selection in these; more at once is slower");
            }
            path: "screenshot.ocrLanguages"
            // No chips until tesseract has languages to pick
            belowVisible: (root.ocrInstalled ?? []).length > 0

            below: Flow {
                width: parent.width
                spacing: Config.padding

                Repeater {
                    model: root.ocrChoices

                    Rectangle {
                        id: chip

                        required property string modelData
                        readonly property bool active: Config.screenshotOcrLanguages.includes(modelData)
                        readonly property bool missing: !(root.ocrInstalled ?? []).includes(modelData)

                        width: chipText.implicitWidth + Config.padding * 4
                        height: chipText.implicitHeight + Config.padding * 2
                        radius: height / 2
                        color: {
                            if (missing)
                                return Qt.alpha(Config.errorColor, 0.2);
                            if (active)
                                return Config.accentColor;
                            return chipMouse.containsMouse ? Config.surface2Color : Config.surface1Color;
                        }

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.missing ? I18n.tr("%1 · not installed", root.languageNames[chip.modelData] ?? chip.modelData) : (root.languageNames[chip.modelData] ?? chip.modelData)
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            font.bold: chip.active
                            color: chip.missing ? Config.errorColor : chip.active ? Config.textReverseColor : Config.textColor
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleLanguage(chip.modelData)
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("Overlay")

        SliderRow {
            label: I18n.tr("Dimming")
            description: I18n.tr("How dark the screen gets outside the selection")
            path: "screenshot.dim"
            from: 0
            to: 90
            stepSize: 5
            format: v => v + "%"
        }

        ToggleRow {
            label: I18n.tr("Guides")
            description: I18n.tr("Dashed lines from the cursor, and then from the region, to the screen edges")
            path: "screenshot.guides"
        }

        ToggleRow {
            label: I18n.tr("Key hints")
            description: I18n.tr("The keys for what you are doing, under the control bar")
            path: "screenshot.hints"
        }

        ToggleRow {
            label: I18n.tr("Animations")
            description: I18n.tr("Animate the window and screen selections (a region follows the mouse as it is drawn)")
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
        running: true
        command: ["sh", "-c", "command -v tesseract >/dev/null && tesseract --list-langs 2>/dev/null | tail -n +2"]
        stdout: StdioCollector {
            onStreamFinished: root.ocrInstalled = text.split("\n").map(l => l.trim()).filter(l => l !== "" && l !== "osd")
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
