pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Header of a Quick Settings subpage: back, icon, title/subtitle and
// trailing controls (children are appended at the end)
RowLayout {
    id: root

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property color iconColor: Config.accentColor

    readonly property int boxSize: Config.fontSizeIconSmall * 2

    signal backClicked

    Layout.fillWidth: true
    spacing: Config.spacing

    BackButton {
        size: root.boxSize
        onClicked: root.backClicked()
    }

    Rectangle {
        visible: root.icon !== ""
        implicitWidth: root.boxSize
        implicitHeight: root.boxSize
        radius: Config.radiusLarge
        color: Qt.alpha(root.iconColor, 0.15)

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.icon
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            color: root.iconColor
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Config.padding
        spacing: 0

        Text {
            Layout.fillWidth: true
            text: root.title
            font.family: Config.font
            font.pixelSize: Config.fontSizeLarge
            font.bold: true
            color: Config.textColor
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: root.subtitle !== ""
            text: root.subtitle
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            color: Config.subtextColor
            elide: Text.ElideRight
        }
    }
}
