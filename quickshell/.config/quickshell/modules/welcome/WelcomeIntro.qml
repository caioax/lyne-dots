pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// First step: the logo, what comes next, and the two keys worth knowing
// before anything else
ColumnLayout {
    id: root

    function keysOf(id: string): string {
        return KeybindsService.binds.find(b => b.id === id)?.keys ?? "";
    }

    spacing: Config.spacing * 3

    // Sized by height (a Layout overrides `height` with the implicit one)
    LyneLogo {
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: Config.spacing
        Layout.preferredHeight: Config.fontSizeIconLarge * 3
        Layout.preferredWidth: implicitWidth
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Config.spacing

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Welcome to lyne-dots"
            wrapMode: Text.WordWrap
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconLarge
            font.bold: true
            color: Config.textColor
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "A few choices to make it yours. Each one applies right away, and all of them can be changed later in Settings."
            wrapMode: Text.WordWrap
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.subtextColor
        }
    }

    // Keys worth knowing from the start (with the user's keys)
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: tips.implicitHeight + Config.padding * 4
        radius: Config.radiusLarge
        color: Config.cardColor

        ColumnLayout {
            id: tips

            anchors.fill: parent
            anchors.margins: Config.padding * 2
            spacing: Config.spacing * 2

            Repeater {
                model: [
                    {
                        id: "launcher",
                        label: "Open apps and search"
                    },
                    {
                        id: "settings",
                        label: "Open Settings"
                    }
                ].filter(t => root.keysOf(t.id) !== "")

                RowLayout {
                    id: tip

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Config.spacing * 2

                    Text {
                        Layout.fillWidth: true
                        text: tip.modelData.label
                        elide: Text.ElideRight
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        color: Config.textColor
                    }

                    WelcomeKeys {
                        combos: [root.keysOf(tip.modelData.id)]
                    }
                }
            }
        }
    }
}
