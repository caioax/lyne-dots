pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../settings/rows/"

// Last step: the main shortcuts (the user's keys, after the navigation
// preset) and shortcuts into Settings
ColumnLayout {
    id: root

    // { label, ids, range }: binds sharing modifiers show as one row
    readonly property var shortcuts: [
        {
            label: "Apps",
            ids: ["launcher"]
        },
        {
            label: "Terminal",
            ids: ["terminal"]
        },
        {
            label: "Browser",
            ids: ["browser"]
        },
        {
            label: "Files",
            ids: ["file-manager"]
        },
        {
            label: "Close window",
            ids: ["close-window"]
        },
        {
            label: "Fullscreen",
            ids: ["fullscreen"]
        },
        {
            label: "Focus",
            ids: ["focus-left", "focus-down", "focus-up", "focus-right"]
        },
        {
            label: "Move",
            ids: ["move-left", "move-down", "move-up", "move-right"]
        },
        {
            label: "Go to workspace",
            ids: ["workspace-1", "workspace-10"],
            range: true
        },
        {
            label: "Switch workspace",
            ids: ["workspace-prev", "workspace-next"]
        },
        {
            label: "Next layout",
            ids: ["cycle-layout"]
        },
        {
            label: "Clipboard history",
            ids: ["clipboard-history"]
        },
        {
            label: "Screenshot",
            ids: ["screenshot"]
        },
        {
            label: "Settings",
            ids: ["settings"]
        },
        {
            label: "Lock screen",
            ids: ["lock-screen"]
        },
        {
            label: "Power menu",
            ids: ["power-menu"]
        }
    ]

    function keysOf(id: string): string {
        return KeybindsService.binds.find(b => b.id === id)?.keys ?? "";
    }

    // Settings pages worth a look after the first steps
    readonly property var explore: ["wallpaper", "monitors", "keybinds", "notifications", "lock", "about"].map(id => SettingsService.pages.find(p => p.id === id)).filter(p => p !== undefined)

    spacing: Config.spacing * 3

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Config.spacing

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "You're all set"
            wrapMode: Text.WordWrap
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconLarge
            font.bold: true
            color: Config.textColor
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Some shortcuts to start with. Every one of them can be changed in Settings › Keybinds, and this screen opens again from Settings › About or with lyne welcome."
            wrapMode: Text.WordWrap
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.subtextColor
        }
    }

    // ================= SHORTCUTS =================
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: grid.implicitHeight + Config.padding * 4
        radius: Config.radiusLarge
        color: Config.cardColor

        GridLayout {
            id: grid

            anchors.fill: parent
            anchors.margins: Config.padding * 2
            columns: width > Config.fontSizeNormal * 44 ? 2 : 1
            columnSpacing: Config.spacing * 3
            rowSpacing: Config.spacing * 2

            Repeater {
                model: root.shortcuts.filter(s => s.ids.some(id => root.keysOf(id) !== ""))

                RowLayout {
                    id: shortcut

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: Config.spacing * 2

                    Text {
                        Layout.fillWidth: true
                        text: shortcut.modelData.label
                        elide: Text.ElideRight
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        color: Config.textColor
                    }

                    WelcomeKeys {
                        combos: shortcut.modelData.ids.map(id => root.keysOf(id))
                        range: shortcut.modelData.range === true
                    }
                }
            }
        }
    }

    // ================= EXPLORE =================
    SettingsGroup {
        Layout.fillWidth: true
        title: "Explore Settings"

        GridLayout {
            Layout.fillWidth: true
            columns: width > Config.fontSizeNormal * 34 ? 3 : 2
            columnSpacing: Config.spacing
            rowSpacing: Config.spacing

            Repeater {
                model: root.explore

                Rectangle {
                    id: card

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: cardRow.implicitHeight + Config.padding * 3
                    radius: Config.radiusLarge
                    color: cardMouse.containsMouse ? Config.surface2Color : Config.surface1Color

                    Behavior on color {
                        enabled: !Config.themeTransitioning
                        ColorAnimation {
                            duration: Config.animDurationShort
                        }
                    }

                    RowLayout {
                        id: cardRow

                        anchors.fill: parent
                        anchors.margins: Config.padding * 1.5
                        spacing: Config.spacing + Config.padding

                        Text {
                            text: card.modelData.icon
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeLarge
                            color: Config.accentColor
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.label
                            elide: Text.ElideRight
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            color: Config.textColor
                        }
                    }

                    MouseArea {
                        id: cardMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsService.open(card.modelData.id)
                    }
                }
            }
        }
    }
}
