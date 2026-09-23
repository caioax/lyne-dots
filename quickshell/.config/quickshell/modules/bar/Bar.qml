pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"
import "../quickSettings/"
import "../systemMonitor/"
import "../calendar/"

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            property bool enableAutoHide: Config.barAutoHide

            WlrLayershell.namespace: "qs_modules"

            implicitHeight: Config.barHeight
            color: "transparent"
            screen: modelData

            exclusionMode: enableAutoHide ? ExclusionMode.Ignore : ExclusionMode.Normal
            exclusiveZone: enableAutoHide ? 0 : height

            anchors {
                top: true
                left: true
                right: true
            }

            // --- AUTOHIDE ---
            // Slides up leaving 1px at the top edge to catch the mouse
            margins.top: {
                if (WindowManagerService.anyModuleOpen || !enableAutoHide || mouseSensor.hovered)
                    return 0;
                return -(height - 1);
            }

            Behavior on margins.top {
                NumberAnimation {
                    duration: Config.animDurationLong
                    easing.type: Easing.OutExpo
                }
            }

            // Covers the whole window, so the remaining 1px still detects the mouse
            HoverHandler {
                id: mouseSensor
            }

            // Transparent strip; each group of items is a floating island
            Item {
                anchors.fill: parent
                anchors.leftMargin: Config.spacing
                anchors.rightMargin: Config.spacing

                // --- LEFT: launcher, workspaces, active window ---
                BarIsland {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    BarButton {
                        contentItem: launcherIcon
                        implicitWidth: implicitHeight
                        active: LauncherService.visible
                        onClicked: LauncherService.toggle()

                        Text {
                            id: launcherIcon
                            anchors.centerIn: parent
                            text: "󰣇"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeLarge
                            color: Config.accentColor
                        }
                    }

                    Workspaces {
                        Layout.leftMargin: Math.round(Config.padding / 2)
                        Layout.rightMargin: Math.round(Config.padding / 2)
                    }

                    BarDivider {
                        visible: activeWindow.visible
                    }

                    ActiveWindow {
                        id: activeWindow
                        Layout.rightMargin: Config.padding
                    }
                }

                // --- CENTER: clock, date, weather ---
                BarIsland {
                    anchors.centerIn: parent

                    CalendarButton {}
                }

                // --- RIGHT: media, tray, CPU, quick settings ---
                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Config.spacing

                    MediaIsland {}

                    BarIsland {
                        TrayWidget {}

                        SystemMonitorButton {}

                        BarDivider {}

                        QuickSettingsButton {
                            id: quickSettings
                        }
                    }
                }
            }
        }
    }
}
