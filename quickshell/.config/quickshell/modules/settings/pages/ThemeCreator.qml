pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"
import "../../../services/ThemeGenerator.js" as ThemeGenerator

// New theme view inside the Theme page: a few picks (accent, mode, mood)
// generate the whole theme (ThemeGenerator.js), previewed on a mock desktop.
// Nothing is applied to the shell while editing
ColumnLayout {
    id: root

    readonly property var swatches: ["#7aa2f7", "#89b4fa", "#b4befe", "#c678dd", "#f5a3c7", "#f7768e", "#962a1f", "#e0a153", "#e5c07b", "#9ece6a", "#50c8a0", "#7dcfff", "#888888"]

    property var seed: ({
            name: "",
            scheme: ThemeService.colorScheme,
            accent: Config.accentColor.toString(),
            exactAccent: false,
            tint: 0.5,
            vibrance: 0.5,
            harmony: 0.15
        })
    readonly property var generated: ThemeGenerator.generate(seed)

    signal back

    function setSeed(key: string, value) {
        const next = Object.assign({}, seed);
        next[key] = value;
        seed = next;
    }

    spacing: Config.spacing * 3

    PageHeader {
        title: "New theme"
        subtitle: "A few picks: the rest of the colors follow from them"
        icon: "\u{f03d8}"
        onBackClicked: root.back()
    }

    ThemeMock {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(width * 9 / 16, Config.fontSizeNormal * 24)
        theme: root.generated
    }

    // ================= COLORS =================
    SettingsGroup {
        title: "Colors"

        SettingRow {
            id: accentRow

            label: "Accent"
            description: "Buttons, highlights and the active window border"

            // Hex field
            Rectangle {
                Layout.preferredWidth: Config.fontSizeNormal * 7
                implicitHeight: Config.fontSizeIconSmall + Config.padding * 3
                radius: Config.radius
                color: accentRow.controlColor
                border.width: hexInput.activeFocus ? 1 : 0
                border.color: Qt.alpha(Config.accentColor, 0.6)

                TextInput {
                    id: hexInput

                    readonly property bool valid: /^#?[0-9a-fA-F]{6}$/.test(text.trim())

                    anchors.fill: parent
                    anchors.leftMargin: Config.padding * 2
                    anchors.rightMargin: Config.padding * 2
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    text: root.seed.accent
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: valid ? Config.textColor : Config.errorColor
                    selectionColor: Qt.alpha(Config.accentColor, 0.4)
                    onTextEdited: {
                        if (valid) {
                            const t = text.trim().toLowerCase();
                            root.setSeed("accent", t.startsWith("#") ? t : "#" + t);
                        }
                    }
                    // Back to the saved value when leaving an invalid one
                    onActiveFocusChanged: {
                        if (!activeFocus)
                            text = Qt.binding(() => root.seed.accent);
                    }
                }
            }

            below: Flow {
                width: parent.width
                spacing: Config.padding

                Repeater {
                    model: root.swatches

                    Rectangle {
                        id: swatch

                        required property string modelData
                        readonly property bool active: modelData === root.seed.accent.toLowerCase()

                        width: Config.fontSizeIconSmall + Config.padding
                        height: width
                        radius: width / 2
                        color: modelData
                        border.width: active ? 2 : swatchMouse.containsMouse ? 1 : 0
                        border.color: Config.textColor

                        Text {
                            visible: swatch.active
                            anchors.centerIn: parent
                            text: "\u{f012c}"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            font.bold: true
                            color: ThemeGenerator.contrast(swatch.modelData, "#000000") > 7 ? "#000000" : "#ffffff"
                        }

                        MouseArea {
                            id: swatchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setSeed("accent", swatch.modelData)
                        }
                    }
                }
            }
        }

        SelectRow {
            label: "Mode"
            description: "Dark or light backgrounds"
            options: [
                {
                    label: "Dark",
                    icon: "\u{f0594}",
                    value: "dark"
                },
                {
                    label: "Light",
                    icon: "\u{f05a8}",
                    value: "light"
                }
            ]
            value: root.seed.scheme
            onSelected: value => root.setSeed("scheme", value)
        }

        ToggleRow {
            label: "Keep the exact accent"
            description: "Off: its brightness is adjusted so text on it and in it stays readable"
            checked: root.seed.exactAccent
            onToggled: value => root.setSeed("exactAccent", value)
        }
    }

    // ================= MOOD =================
    SettingsGroup {
        title: "Mood"

        SliderRow {
            label: "Background tint"
            description: "How much the backgrounds and text take the accent's hue"
            value: root.seed.tint
            from: 0
            to: 1
            stepSize: 0.05
            format: v => Math.round(v * 100) + "%"
            onMoved: value => root.setSeed("tint", value)
        }

        SliderRow {
            label: "Vibrance"
            description: "Saturation of the status and terminal colors"
            value: root.seed.vibrance
            from: 0
            to: 1
            stepSize: 0.05
            format: v => Math.round(v * 100) + "%"
            onMoved: value => root.setSeed("vibrance", value)
        }

        SliderRow {
            label: "Harmony"
            description: "How far the status and terminal colors lean towards the accent"
            value: root.seed.harmony
            from: 0
            to: 1
            stepSize: 0.05
            format: v => Math.round(v * 100) + "%"
            onMoved: value => root.setSeed("harmony", value)
        }
    }
}
