pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

// Tray style "drawer": the icons slide out of a chevron button, inline in
// the bar
RowLayout {
    id: root

    required property var model

    property bool isOpen: false

    signal itemActivated

    spacing: Math.round(Config.padding / 2)

    Item {
        id: drawer

        clip: true

        Layout.preferredHeight: Config.barButtonHeight
        Layout.preferredWidth: root.isOpen ? iconsRow.implicitWidth + Config.padding : 0

        Behavior on Layout.preferredWidth {
            NumberAnimation {
                duration: Config.animDurationLong
                easing.type: Easing.OutExpo
            }
        }

        opacity: root.isOpen ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
            }
        }

        Row {
            id: iconsRow
            spacing: Math.round(Config.padding / 2)
            anchors.verticalCenter: parent.verticalCenter

            anchors.right: parent.right
            anchors.rightMargin: root.isOpen ? Config.padding : -iconsRow.implicitWidth

            Behavior on anchors.rightMargin {
                NumberAnimation {
                    duration: Config.animDurationLong
                    easing.type: Easing.OutExpo
                }
            }

            Repeater {
                model: root.model.items

                delegate: TrayItem {
                    required property var modelData
                    model: root.model
                    item: modelData
                    onActivated: root.itemActivated()
                }
            }
        }
    }

    // Toggle button
    Rectangle {
        id: toggleBtn

        visible: root.model.hasItems
        Layout.preferredWidth: Config.barButtonHeight
        Layout.preferredHeight: Config.barButtonHeight
        radius: width / 2

        color: toggleMouse.containsMouse ? Config.surface1Color : Qt.alpha(Config.surface1Color, 0)

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }

        // md-chevron_left
        Text {
            anchors.centerIn: parent
            text: "\u{f0141}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: Config.subtextColor

            scale: root.isOpen ? -1 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutBack
                }
            }
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.isOpen = !root.isOpen
        }
    }
}
