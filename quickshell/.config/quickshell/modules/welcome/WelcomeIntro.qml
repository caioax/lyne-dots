pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../settings/rows/"
import "../../components/"

// First step: the logo, the language, what comes next, and the two keys
// worth knowing before anything else
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
            text: I18n.tr("Welcome to lyne-dots")
            wrapMode: Text.WordWrap
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconLarge
            font.bold: true
            color: Config.textColor
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: I18n.tr("A few choices to make it yours. Each one applies right away, and all of them can be changed later in Settings.")
            wrapMode: Text.WordWrap
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.subtextColor
        }
    }

    SettingsGroup {
        title: I18n.tr("Language")

        LanguageRow {
            label: I18n.tr("Shell language")
            description: I18n.setting === "auto" ? I18n.tr("Following your system. Can be changed later in Settings › %1", I18n.translate("Profile & Region")) : I18n.tr("Can be changed later in Settings › %1", I18n.translate("Profile & Region"))
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
                        label: I18n.tr("Open apps and search")
                    },
                    {
                        id: "settings",
                        label: I18n.tr("Open Settings")
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
