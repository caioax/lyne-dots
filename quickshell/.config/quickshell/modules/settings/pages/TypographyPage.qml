pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

ColumnLayout {
    id: root

    readonly property var sizeKeys: ["sizeSmall", "sizeNormal", "sizeLarge", "iconSmall", "icon", "iconLarge"]
    readonly property var scales: [
        {
            label: "Small",
            value: 0.875
        },
        {
            label: "Default",
            value: 1
        },
        {
            label: "Large",
            value: 1.125
        },
        {
            label: "Larger",
            value: 1.25
        }
    ]
    // Scale closest to the current normal text size
    readonly property real currentScale: {
        const ratio = Config.fontSizeNormal / StateService.getDefault("typography.sizeNormal", 14);
        let best = scales[0];
        for (const s of scales) {
            if (Math.abs(s.value - ratio) < Math.abs(best.value - ratio))
                best = s;
        }
        return best.value;
    }

    spacing: Config.spacing * 3

    FontPicker {
        id: fontPicker

        current: Config.font
        onPicked: family => {
            StateService.set("typography.font", family);
            close();
        }
    }

    SettingsGroup {
        title: "Preview"

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: preview.implicitHeight + Config.padding * 4
            radius: Config.radiusLarge
            color: Config.surface0Color

            RowLayout {
                id: preview

                anchors.fill: parent
                anchors.margins: Config.padding * 2
                spacing: Config.spacing * 2

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(Config.padding / 3)

                    Text {
                        Layout.fillWidth: true
                        text: "The quick brown fox"
                        elide: Text.ElideRight
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeLarge
                        font.bold: true
                        color: Config.textColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "jumps over the lazy dog 0123456789"
                        elide: Text.ElideRight
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        color: Config.textColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Small text for captions and descriptions"
                        elide: Text.ElideRight
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                    }
                }

                // md-bell, md-palette, md-cog at the three icon sizes
                Repeater {
                    model: [
                        {
                            icon: "\u{f009a}",
                            size: Config.fontSizeIconSmall
                        },
                        {
                            icon: "\u{f03d8}",
                            size: Config.fontSizeIcon
                        },
                        {
                            icon: "\u{f0493}",
                            size: Config.fontSizeIconLarge
                        }
                    ]

                    Text {
                        required property var modelData
                        text: modelData.icon
                        font.family: Config.font
                        font.pixelSize: modelData.size
                        color: Config.accentColor
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: "Font"

        SettingRow {
            id: fontRow

            label: "Interface font"
            description: Config.font
            path: "typography.font"

            ActionButton {
                icon: "\u{f03eb}"
                text: "Change"
                baseColor: fontRow.controlColor
                onClicked: fontPicker.open()
            }
        }
    }

    SettingsGroup {
        title: "Size"

        SelectRow {
            label: "Scale"
            description: "Resize all text and icons together"
            segmentWidth: Config.fontSizeNormal * 5
            options: root.scales
            value: root.currentScale
            onSelected: value => {
                for (const key of root.sizeKeys) {
                    const path = "typography." + key;
                    StateService.set(path, Math.round(StateService.getDefault(path, 14) * value));
                }
            }
        }
    }

    SettingsGroup {
        title: "Text sizes"

        StepperRow {
            label: "Small"
            description: "Captions, descriptions and labels"
            path: "typography.sizeSmall"
            from: 8
            to: 24
            format: v => v + "px"
        }

        StepperRow {
            label: "Normal"
            description: "Most of the text"
            path: "typography.sizeNormal"
            from: 8
            to: 24
            format: v => v + "px"
        }

        StepperRow {
            label: "Large"
            description: "Titles and headers"
            path: "typography.sizeLarge"
            from: 8
            to: 32
            format: v => v + "px"
        }
    }

    SettingsGroup {
        title: "Icon sizes"

        StepperRow {
            label: "Small"
            path: "typography.iconSmall"
            from: 10
            to: 40
            format: v => v + "px"
        }

        StepperRow {
            label: "Normal"
            path: "typography.icon"
            from: 10
            to: 40
            format: v => v + "px"
        }

        StepperRow {
            label: "Large"
            path: "typography.iconLarge"
            from: 10
            to: 48
            format: v => v + "px"
        }
    }
}
