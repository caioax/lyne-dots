pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

RowLayout {
    id: root
    spacing: 5

    // Drawer state
    property bool isOpen: false

    // We create the TrayMenu object here, but it starts invisible.
    TrayMenu {
        id: sharedMenu
        visible: false

        onVisibleChanged: {
            if (visible)
                TrayService.registerActiveMenu(sharedMenu);
        }
    }

    Item {
        id: drawer

        clip: true

        Layout.preferredHeight: 30
        Layout.preferredWidth: root.isOpen ? (iconsRow.implicitWidth + 5) : 0

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

        // Drawer content
        Row {
            id: iconsRow
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter

            anchors.right: parent.right
            anchors.rightMargin: root.isOpen ? 5 : -iconsRow.implicitWidth

            Behavior on anchors.rightMargin {
                NumberAnimation {
                    duration: Config.animDurationLong
                    easing.type: Easing.OutExpo
                }
            }

            Repeater {
                model: TrayService.items

                delegate: Rectangle {
                    id: trayDelegate
                    required property var modelData

                    implicitWidth: 24
                    implicitHeight: 24
                    radius: width / 2
                    color: mouseArea.containsMouse ? Config.surface1Color : "transparent"

                    // Primary icon (theme name, file path, or pixmap URL)
                    Image {
                        id: trayIcon
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: TrayService.getIconSource(trayDelegate.modelData.icon)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        sourceSize: Qt.size(32, 32)
                        smooth: true
                        visible: status === Image.Ready
                    }

                    // Fallback when primary icon fails (e.g. pixmap-based icons from nm-applet)
                    Image {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: "image://icon/application-default-icon"
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(32, 32)
                        smooth: true
                        visible: trayIcon.status === Image.Error
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                trayDelegate.modelData.activate();
                                sharedMenu.close();
                            } else if (mouse.button === Qt.RightButton) {
                                if (trayDelegate.modelData.hasMenu) {
                                    // 1. Gets the absolute position of the icon on screen
                                    var globalPos = trayDelegate.mapToGlobal(0, trayDelegate.height);

                                    // 2. Configures the shared menu
                                    sharedMenu.rootMenuHandle = trayDelegate.modelData.menu;
                                    sharedMenu.anchorX = globalPos.x;
                                    sharedMenu.anchorY = globalPos.y + 5;

                                    // 3. Opens the menu
                                    sharedMenu.open();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Toggle button
    Rectangle {
        id: toggleBtn

        visible: TrayService.hasItems
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        radius: width / 2

        color: (toggleMouse.containsMouse) ? Config.surface1Color : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }

        // Arrow Icon
        Text {
            anchors.centerIn: parent
            text: "󰅁"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconSmall
            color: Config.textColor

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
