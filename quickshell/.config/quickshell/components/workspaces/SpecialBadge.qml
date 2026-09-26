import QtQuick
import qs.config

// Badge for the open special workspace (icon + name in its color); clicking
// it hides the special workspace again. Fades/drops out when it closes.
Rectangle {
    id: root

    required property WorkspacesModel model
    readonly property bool shown: model.specialActive

    visible: opacity > 0
    opacity: shown ? (hover.hovered ? 0.8 : 1.0) : 0
    scale: shown ? 1.0 : 0.9

    implicitWidth: content.width + Config.padding * 3
    implicitHeight: Config.fontSizeSmall + Config.padding
    radius: Config.radius

    color: model.specialColor
    border.width: 1

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Config.animDuration
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Config.padding * 0.8

        Text {
            text: root.model.specialIcon
            font {
                family: Config.font
                pixelSize: Config.fontSizeLarge
            }
            color: Config.textReverseColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.model.specialLabel
            font {
                family: Config.font
                bold: true
                pixelSize: Config.fontSizeNormal
            }
            color: Config.textReverseColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    TapHandler {
        onTapped: root.model.toggleSpecial()
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
}
