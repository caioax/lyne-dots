pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config

// Miniature desktop painted with a theme's colors (not the shell's): the bar,
// an app window and a Kitty terminal with the ANSI colors, over the theme's
// wallpaper (or a gradient of its own background)
ClippingRectangle {
    id: root

    // A theme object: { palette, terminal } as in the theme JSONs
    property var theme: ({})
    // Absolute path of a wallpaper, "" for a plain gradient
    property string wallpaper: ""

    readonly property var p: theme.palette ?? {}
    readonly property var t: theme.terminal ?? {}

    // Everything is sized from the thumbnail height
    readonly property real unit: height / 12
    readonly property real textSize: Math.max(7, unit * 0.62)
    readonly property real barHeight: unit * 1.5
    readonly property real gap: unit * 0.6
    readonly property real windowY: barHeight + gap
    readonly property real windowHeight: height - windowY - gap
    readonly property real appWidth: (width - gap * 3) * 0.44

    function c(key: string, fallback: color): color {
        return p[key] ?? fallback;
    }

    function tc(key: string): color {
        return t[key] ?? p.text ?? "transparent";
    }

    radius: Config.radius
    color: c("blueDark", Config.surface2Color)

    Rectangle {
        anchors.fill: parent
        visible: root.wallpaper === ""
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.c("background", Config.surface1Color)
            }
            GradientStop {
                position: 1
                color: root.c("blueDark", Config.surface2Color)
            }
        }
    }

    Image {
        anchors.fill: parent
        visible: root.wallpaper !== ""
        source: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true
    }

    component Label: Text {
        font.family: Config.font
        font.pixelSize: root.textSize
        color: root.c("text", Config.textColor)
        elide: Text.ElideRight
    }

    component Line: Row {
        property var spans: []

        Repeater {
            model: parent.spans

            Label {
                required property var modelData

                text: modelData[0]
                color: root.tc(modelData[1])
                font.bold: modelData[2] ?? false
                elide: Text.ElideNone
            }
        }
    }

    component Pill: Rectangle {
        height: root.unit * 0.45
        radius: height / 2
    }

    // ================= BAR =================
    Rectangle {
        width: parent.width
        height: root.barHeight
        color: Qt.alpha(root.c("background", Config.backgroundColor), 0.92)

        Row {
            anchors.left: parent.left
            anchors.leftMargin: root.gap
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.unit * 0.3

            Repeater {
                model: 5

                Pill {
                    required property int index

                    anchors.verticalCenter: parent.verticalCenter
                    width: index === 1 ? root.unit * 1.4 : height
                    color: index === 1 ? root.c("accent", Config.accentColor) : index === 3 ? root.c("subtext", Config.subtextColor) : root.c("surface2", Config.surface2Color)
                }
            }
        }

        Label {
            anchors.centerIn: parent
            text: "Mon 12:30"
            font.bold: true
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: root.gap
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.unit * 0.35

            Repeater {
                model: ["subtext", "subtext", "success"]

                Rectangle {
                    required property string modelData

                    anchors.verticalCenter: parent.verticalCenter
                    width: root.unit * 0.5
                    height: width
                    radius: width / 2
                    color: root.c(modelData, Config.subtextColor)
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: root.unit * 1.1
                height: root.unit * 0.55
                radius: root.unit * 0.12
                color: "transparent"
                border.width: 1
                border.color: root.c("subtext", Config.subtextColor)

                Rectangle {
                    x: 2
                    y: 2
                    width: (parent.width - 4) * 0.7
                    height: parent.height - 4
                    radius: 1
                    color: root.c("text", Config.textColor)
                }
            }
        }
    }

    // ================= APP WINDOW (inactive) =================
    Rectangle {
        id: app

        x: root.gap
        y: root.windowY
        width: root.appWidth
        height: root.windowHeight
        radius: Config.radiusSmall
        color: root.c("surface0", Config.surface0Color)
        border.width: 1
        border.color: root.c("surface3", Config.surface3Color)
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: root.unit * 0.5
            spacing: root.unit * 0.35

            Label {
                text: "Settings"
                font.bold: true
                font.pixelSize: root.textSize * 1.15
            }

            Repeater {
                model: [
                    {
                        title: "Appearance",
                        sub: "Colors and wallpaper",
                        selected: true
                    },
                    {
                        title: "Network",
                        sub: "Connected",
                        selected: false
                    },
                    {
                        title: "Sound",
                        sub: "Speakers · 65%",
                        selected: false
                    }
                ]

                Rectangle {
                    id: listRow

                    required property var modelData

                    width: parent.width
                    height: root.unit * 1.45
                    radius: Config.radiusSmall
                    color: modelData.selected ? root.c("greyBlue", Config.surface2Color) : root.c("surface1", Config.surface1Color)

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.unit * 0.4
                        width: parent.width - x * 2

                        Label {
                            width: parent.width
                            text: listRow.modelData.title
                            font.bold: true
                            color: listRow.modelData.selected ? root.c("accent", Config.accentColor) : root.c("text", Config.textColor)
                        }

                        Label {
                            width: parent.width
                            text: listRow.modelData.sub
                            font.pixelSize: root.textSize * 0.85
                            color: root.c("subtext", Config.subtextColor)
                        }
                    }
                }
            }

            Label {
                width: parent.width
                text: "Last synced 2 min ago"
                font.pixelSize: root.textSize * 0.85
                color: root.c("muted", Config.subtextColor)
            }

            // Status chips
            Row {
                spacing: root.unit * 0.25

                Repeater {
                    model: [["success", "ok"], ["warning", "low"], ["error", "fail"]]

                    Rectangle {
                        id: chip

                        required property var modelData

                        width: chipText.implicitWidth + root.unit * 0.5
                        height: root.unit * 0.8
                        radius: height / 2
                        color: Qt.alpha(root.c(modelData[0], Config.accentColor), 0.18)

                        Label {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData[1]
                            font.pixelSize: root.textSize * 0.85
                            color: root.c(chip.modelData[0], Config.accentColor)
                        }
                    }
                }
            }
        }

        // Accent switch, top-right
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.unit * 0.55
            width: root.unit * 1.3
            height: root.unit * 0.7
            radius: height / 2
            color: root.c("accent", Config.accentColor)

            Rectangle {
                x: parent.width - width - 2
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height - 4
                height: width
                radius: width / 2
                color: root.c("textReverse", Config.textReverseColor)
            }
        }

        // Accent button, bottom-right
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.unit * 0.5
            spacing: root.unit * 0.35

            Rectangle {
                width: applyText.implicitWidth + root.unit * 0.8
                height: root.unit * 1.0
                radius: Config.radiusSmall
                color: root.c("accent", Config.accentColor)

                Label {
                    id: applyText
                    anchors.centerIn: parent
                    text: "Apply"
                    font.bold: true
                    color: root.c("textReverse", Config.textReverseColor)
                }
            }
        }
    }

    // ================= TERMINAL (active) =================
    Rectangle {
        x: app.x + app.width + root.gap
        y: root.windowY
        width: parent.width - x - root.gap
        height: root.windowHeight
        radius: Config.radiusSmall
        color: root.tc("background")
        border.width: 2
        border.color: root.tc("activeBorderColor")
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: root.unit * 0.5
            spacing: root.unit * 0.12

            Line {
                spans: [["~/lyne-dots", "color4", true], [" main", "color5"], [" ❯ ", "color2", true], ["ls", "foreground"]]
            }

            Line {
                spans: [["config  ", "color4", true], ["scripts  ", "color2", true], ["logo.svg  ", "color5"], ["notes.md", "foreground"]]
            }

            Line {
                spans: [["~/lyne-dots", "color4", true], [" main", "color5"], [" ❯ ", "color2", true], ["git status -s", "foreground"]]
            }

            Line {
                spans: [[" M ", "color1", true], ["bar.qml", "foreground"]]
            }

            Line {
                spans: [["A  ", "color2", true], ["theme.json", "foreground"]]
            }

            Line {
                spans: [["?? ", "color8", true], ["draft.txt", "color8"]]
            }

            Line {
                spans: [["warn ", "color3", true], ["info ", "color6", true], ["hint ", "color16", true], ["done", "color10", true]]
            }

            Line {
                spans: [["~/lyne-dots", "color4", true], [" main", "color5"], [" ❯ ", "color2", true]]

                // Block cursor
                Rectangle {
                    width: root.textSize * 0.6
                    height: root.textSize * 1.2
                    color: root.tc("cursor")
                }
            }
        }

        // Selection highlight over the second line
        Rectangle {
            x: root.unit * 0.5
            y: root.unit * 0.5 + root.textSize * 1.4
            width: root.unit * 3.2
            height: root.textSize * 1.3
            color: root.tc("selectionBackground")
            opacity: 0.5
        }

        // ANSI 0-15 strip at the bottom
        Grid {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.unit * 0.5
            columns: 8
            spacing: root.unit * 0.12

            Repeater {
                model: 16

                Rectangle {
                    required property int index

                    width: (parent.width - parent.spacing * 7) / 8
                    height: root.unit * 0.45
                    radius: 1
                    color: root.tc("color" + index)
                }
            }
        }
    }
}
