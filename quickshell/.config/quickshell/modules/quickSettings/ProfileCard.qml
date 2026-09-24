pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import "../../components/"

// Avatar, user, uptime, battery and power, plus a row of shortcuts
Card {
    id: root

    signal closeWindow
    signal openTheme

    readonly property int avatarSize: Config.fontSizeLarge * 3
    readonly property int controlSize: Config.fontSizeIconSmall * 2

    function runShortcut(action: string) {
        if (action === "theme") {
            root.openTheme();
            return;
        }
        root.closeWindow();
        switch (action) {
        case "screenshot":
            // Wait for the popup to close so it isn't captured
            screenshotDelay.restart();
            break;
        case "clipboard":
            ClipboardService.toggle();
            break;
        case "wallpaper":
            WallpaperService.toggle();
            break;
        case "keybinds":
            ShortcutService.keybindsRequested();
            break;
        case "lock":
            IdleService.lock();
            break;
        case "settings":
            SettingsService.open("");
            break;
        }
    }

    Timer {
        id: screenshotDelay
        interval: Config.animDurationLong
        onTriggered: ShortcutService.screenshotRequested()
    }

    spacing: Config.padding * 2

    // ========== PROFILE ==========
    RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing + Config.padding

        // Click picks a picture, right click goes back to the distro logo
        Item {
            implicitWidth: root.avatarSize
            implicitHeight: root.avatarSize

            ClippingRectangle {
                anchors.fill: parent
                radius: width / 2
                color: Config.surface1Color

                Image {
                    id: avatarImage
                    anchors.fill: parent
                    visible: status === Image.Ready
                    source: ProfileService.avatar !== "" ? "file://" + ProfileService.avatar : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(root.avatarSize * 2, root.avatarSize * 2)
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !avatarImage.visible
                    text: "󰣇"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconLarge
                    color: Config.accentColor
                }

                // Hover hint
                Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha(Config.backgroundColor, 0.6)
                    opacity: avatarMouse.containsMouse ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animDurationShort
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "󰄀"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconSmall
                        color: Config.textColor
                    }
                }
            }

            MouseArea {
                id: avatarMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        ProfileService.resetAvatar();
                    } else {
                        root.closeWindow();
                        ProfileService.pickAvatar();
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(Config.padding / 3)

            Text {
                Layout.fillWidth: true
                text: Quickshell.env("USER")
                font.family: Config.font
                font.pixelSize: Config.fontSizeLarge
                font.bold: true
                color: Config.textColor
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: "󰅐 " + SystemMonitorService.uptime
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
                elide: Text.ElideRight
            }
        }

        // Battery: percentage and time left / to full
        Rectangle {
            visible: BatteryService.hasBattery
            implicitWidth: batteryRow.implicitWidth + Config.spacing * 2
            implicitHeight: root.controlSize
            radius: Config.radius
            color: Config.surface1Color

            RowLayout {
                id: batteryRow
                anchors.centerIn: parent
                spacing: Config.padding

                Text {
                    text: BatteryService.getBatteryIcon()
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    color: {
                        if (BatteryService.isCharging)
                            return Config.successColor;
                        if (BatteryService.percentage < 20)
                            return Config.errorColor;
                        if (BatteryService.percentage < 40)
                            return Config.warningColor;
                        return Config.textColor;
                    }
                }

                ColumnLayout {
                    spacing: 0

                    Text {
                        text: BatteryService.percentage + "%"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: true
                        color: Config.textColor
                    }

                    Text {
                        visible: BatteryService.timeText !== ""
                        text: BatteryService.timeText
                        font.family: Config.font
                        font.pixelSize: Math.round(Config.fontSizeSmall * 0.85)
                        color: Config.subtextColor
                    }
                }
            }
        }

        ClearButton {
            icon: "⏻"
            Layout.preferredWidth: root.controlSize
            Layout.preferredHeight: root.controlSize
            onClicked: {
                root.closeWindow();
                PowerService.showOverlay();
            }
        }
    }

    // ========== SHORTCUTS ==========
    RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing

        Repeater {
            model: [
                {
                    "icon": "󰹑",
                    "action": "screenshot"
                },
                {
                    "icon": "󰅌",
                    "action": "clipboard"
                },
                {
                    "icon": "󰸉",
                    "action": "wallpaper"
                },
                {
                    "icon": "󰏘",
                    "action": "theme"
                },
                {
                    "icon": "󰌌",
                    "action": "keybinds"
                },
                {
                    "icon": "󰌾",
                    "action": "lock"
                },
                {
                    "icon": "󰒓",
                    "action": "settings"
                }
            ]

            Rectangle {
                id: shortcut

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: root.controlSize
                radius: Config.radius
                color: shortcutMouse.containsMouse ? Config.surface2Color : Config.surface1Color
                scale: shortcutMouse.pressed ? 0.95 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animDurationShort
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Config.animDurationShort
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: shortcut.modelData.icon
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeLarge
                    color: shortcutMouse.containsMouse ? Config.accentColor : Config.textColor
                }

                MouseArea {
                    id: shortcutMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runShortcut(shortcut.modelData.action)
                }
            }
        }
    }
}
