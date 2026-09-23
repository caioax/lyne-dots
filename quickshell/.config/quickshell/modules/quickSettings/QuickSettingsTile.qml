pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import "../../components/"

// Toggle tile: click toggles, the ⋮ button (hasDetails, on hover) opens its page
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string subLabel: ""
    property bool active: false
    property bool hasDetails: false

    signal toggled
    signal openDetails

    readonly property int iconBoxSize: Config.fontSizeIconSmall * 2
    readonly property bool hovered: mainMouse.containsMouse || detailsButton.hovered

    Layout.fillWidth: true
    implicitHeight: iconBoxSize + Config.padding * 2
    radius: Config.radiusLarge
    color: {
        if (active)
            return Qt.alpha(Config.accentColor, hovered ? 0.24 : 0.16);
        return hovered ? Config.surface2Color : Config.surface1Color;
    }

    Behavior on color {
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    scale: mainMouse.pressed || detailsButton.pressed ? 0.98 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }

    MouseArea {
        id: mainMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Config.padding
        anchors.rightMargin: Config.padding
        spacing: Config.spacing

        Rectangle {
            implicitWidth: root.iconBoxSize
            implicitHeight: root.iconBoxSize
            radius: Config.radiusLarge
            color: root.active ? Config.accentColor : Config.surface2Color

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconSmall
                color: root.active ? Config.textReverseColor : Config.textColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.label
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                font.bold: true
                color: Config.textColor
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.subLabel !== ""
                text: root.subLabel
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
                elide: Text.ElideRight
            }
        }

        // Details button, shown while the tile is hovered
        ActionButton {
            id: detailsButton
            // Only takes room while hovered, so the label has the full width otherwise
            visible: root.hasDetails && root.hovered
            size: root.iconBoxSize
            icon: ""
            baseColor: Config.surface2Color
            hoverColor: Config.surface3Color
            onClicked: root.openDetails()
        }
    }
}
