pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import "../../components/"

Rectangle {
    id: root

    // --- Properties ---
    property string icon: ""
    property string label: ""
    property string subLabel: ""

    property bool active: false
    property bool hasDetails: false

    // --- Signals ---
    signal toggled
    signal openDetails

    // --- Layout ---
    Layout.fillWidth: true
    implicitHeight: 50
    radius: Config.radiusLarge

    // Colors and Animation
    color: {
        if (mainMouse.containsMouse || (detailsButton.containsMouse && hasDetails))
            return Config.surface2Color;
        return Config.surface1Color;
    }

    Behavior on color {
        ColorAnimation {
            duration: Config.animDurationShort
        }
    }

    // Scale effect on click
    scale: mainMouse.pressed || detailsButton.pressed ? 0.98 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }

    // Main MouseArea (Toggle)
    MouseArea {
        id: mainMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 0

        // TOGGLE AREA (Icon + Text)
        // Takes up all remaining space
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.fill: parent
                spacing: 12

                // Icon
                Rectangle {
                    width: 37
                    height: 37
                    radius: Config.radiusLarge
                    color: root.active ? Config.accentColor : Config.surface3Color

                    Text {
                        anchors.centerIn: parent
                        text: root.icon
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIcon
                        color: root.active ? Config.textReverseColor : Config.textColor
                    }
                }

                // Text (Title and Subtitle)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: root.label
                        font.family: Config.font
                        font.bold: true
                        font.pixelSize: Config.fontSizeNormal
                        color: Config.textColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Only show sublabel if there is text
                    Text {
                        visible: root.subLabel !== ""
                        text: root.subLabel
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        // Slight transparency on subtext
                        color: Config.subtextColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // DETAILS BUTTON (Arrow/Gear)
        ActionButton {
            id: detailsButton
            visible: root.hasDetails && (mainMouse.containsMouse || hovered)
            icon: ""
            opacity: visible ? 1 : 0
            baseColor: Config.surface2Color

            onClicked: root.openDetails()

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.animDuration
                }
            }
        }
    }
}
