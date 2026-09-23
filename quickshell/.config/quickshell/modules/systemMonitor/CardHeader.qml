pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

RowLayout {
    id: root

    required property string icon
    required property string title
    property string subtitle: ""
    property color iconColor: Config.accentColor
    default property alias trailing: trailingSlot.data

    Layout.fillWidth: true
    spacing: Config.spacing

    Text {
        text: root.icon
        font.family: Config.font
        font.pixelSize: Config.fontSizeLarge
        color: root.iconColor

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }
    }

    Text {
        text: root.title
        font.family: Config.font
        font.pixelSize: Config.fontSizeNormal
        font.bold: true
        color: Config.textColor
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

    Item {
        visible: root.subtitle === ""
        Layout.fillWidth: true
    }

    RowLayout {
        id: trailingSlot
        spacing: Config.padding
    }
}
