pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Top of a welcome step: icon, title and what the step is about (as the
// Settings page header)
RowLayout {
    id: root

    property string icon
    property string title
    property string description

    Layout.fillWidth: true
    spacing: Config.spacing + Config.padding

    Rectangle {
        Layout.alignment: Qt.AlignTop
        implicitWidth: Config.fontSizeIconLarge * 2
        implicitHeight: implicitWidth
        radius: Config.radiusLarge
        color: Qt.alpha(Config.accentColor, 0.15)

        Text {
            anchors.centerIn: parent
            text: root.icon
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconLarge
            color: Config.accentColor
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Math.round(Config.padding / 3)

        Text {
            Layout.fillWidth: true
            text: root.title
            elide: Text.ElideRight
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconLarge
            font.bold: true
            color: Config.textColor
        }

        Text {
            Layout.fillWidth: true
            text: root.description
            wrapMode: Text.WordWrap
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.subtextColor
        }
    }
}
