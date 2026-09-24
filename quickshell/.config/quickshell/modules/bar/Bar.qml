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
            id: bar

            required property var modelData

            property bool enableAutoHide: Config.barAutoHide

            WlrLayershell.namespace: "qs_modules"

            // The concave corners hang below the reserved area
            implicitHeight: Config.barReservedHeight + Config.barCornerSize
            color: "transparent"
            screen: modelData

            exclusionMode: enableAutoHide ? ExclusionMode.Ignore : ExclusionMode.Normal
            exclusiveZone: enableAutoHide ? 0 : Config.barReservedHeight

            anchors {
                top: !Config.barOnBottom
                bottom: Config.barOnBottom
                left: true
                right: true
            }

            // Top edge of the bar inside the window: at the bottom of the
            // screen the corners hang above it and the margin goes below
            readonly property int barY: Config.barOnBottom ? Config.barCornerSize : Config.barMargin
            // Corners touch the side of the bar facing the screen
            readonly property int cornerY: Config.barOnBottom ? 0 : Config.barHeight

            // --- AUTOHIDE ---
            // The content slides out of the window; only a 1px strip at the
            // screen edge keeps taking input to bring it back
            readonly property bool shown: WindowManagerService.anyModuleOpen || !enableAutoHide || mouseSensor.hovered

            HoverHandler {
                id: mouseSensor
            }

            // Only the bar takes input, so the corners hanging under it click
            // through to the windows below
            mask: Region {
                y: {
                    if (!Config.barOnBottom)
                        return 0;
                    return bar.shown ? Config.barCornerSize : bar.height - 1;
                }
                width: bar.width
                height: bar.shown ? Config.barReservedHeight : 1
            }

            Item {
                id: slide

                width: parent.width
                height: parent.height
                y: bar.shown ? 0 : Config.barOnBottom ? height : -height

                Behavior on y {
                    NumberAnimation {
                        duration: Config.animDurationLong
                        easing.type: Easing.OutExpo
                    }
                }

                ConcaveCorner {
                    x: 0
                    y: bar.cornerY
                    size: Config.barCornerSize
                    flipped: Config.barOnBottom
                    color: Config.backgroundTransparentColor
                }

                ConcaveCorner {
                    x: parent.width - width
                    y: bar.cornerY
                    size: Config.barCornerSize
                    flipped: Config.barOnBottom
                    color: Config.backgroundTransparentColor
                    mirrored: true
                }

                Item {
                    id: barArea

                    x: Config.barMargin
                    y: bar.barY
                    width: parent.width - Config.barMargin * 2
                    height: Config.barHeight

                    // One background for the whole bar; the "islands" style draws
                    // one per group instead
                    Rectangle {
                        anchors.fill: parent
                        visible: !Config.barIslands
                        radius: Config.barFloating ? Config.radiusLarge : 0
                        color: Config.backgroundTransparentColor
                        border.width: Config.barFloating ? 1 : 0
                        border.color: Config.surface1Color
                    }
                }

                Item {
                    anchors.fill: barArea
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

                        MediaIsland {
                            id: media
                        }

                        BarDivider {
                            visible: !Config.barIslands && media.visible
                        }

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
}
