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
import "../dashboard/"

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar

            required property var modelData

            property bool enableAutoHide: Config.barAutoHide

            // Blurs only the wallpaper (xray, see hypr appearance.lua), the
            // same as the panels attached to it, so they share one tint
            WlrLayershell.namespace: "qs_attached"

            // Room for the bar's shadow, cast away from the screen edge
            readonly property real shadowRoom: Config.shadowPad

            // The concave corners hang below the reserved area
            implicitHeight: Config.barReservedHeight + Config.barCornerSize + shadowRoom
            color: "transparent"
            screen: modelData

            // Auto hide reserves nothing: -1 (what ExclusionMode.Ignore sends).
            // Not 0: the bar starts before state.json is read, reserving its
            // height, and Quickshell never sends a change back to 0 (it
            // compares with a committed state that starts at 0), so the space
            // stayed reserved after login. A single binding: setting
            // exclusiveZone also switches exclusionMode to Normal
            exclusiveZone: enableAutoHide ? -1 : Config.barReservedHeight

            anchors {
                top: !Config.barOnBottom
                bottom: Config.barOnBottom
                left: true
                right: true
            }

            // Top edge of the bar inside the window: at the bottom of the
            // screen the corners hang above it and the margin goes below
            readonly property int barY: Config.barOnBottom ? Config.barCornerSize + shadowRoom : Config.barMargin
            // Corners touch the side of the bar facing the screen
            readonly property int cornerY: Config.barOnBottom ? 0 : Config.barHeight

            // --- AUTOHIDE ---
            // The content slides out of the window; only a 1px strip at the
            // screen edge keeps taking input to bring it back
            readonly property bool shown: WindowManagerService.anyModuleOpen || !enableAutoHide || mouseSensor.hovered
            // The OSD hangs from the screen edge while the bar is away
            onShownChanged: BarService.setAutoHidden(modelData.name, !shown)
            Component.onCompleted: BarService.setAutoHidden(modelData.name, !shown)
            Component.onDestruction: BarService.setAutoHidden(modelData.name, false)

            HoverHandler {
                id: mouseSensor
            }

            // Only the bar takes input, so the corners hanging under it click
            // through to the windows below
            mask: Region {
                y: {
                    if (!Config.barOnBottom)
                        return 0;
                    return bar.shown ? Config.barCornerSize + bar.shadowRoom : bar.height - 1;
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

                // A docked bar's shadow follows the bar and its corners; the
                // bar is pushed past the screen edges, so only the side
                // facing the windows shows
                ShapeShadow {
                    id: dockedShadow

                    readonly property real past: Config.shadowPad

                    anchors.fill: parent
                    visible: !Config.barFloating && !Config.barIslands && Config.shadowEnabled

                    Rectangle {
                        x: -dockedShadow.past
                        y: Config.barOnBottom ? bar.barY : -dockedShadow.past
                        width: parent.width + dockedShadow.past * 2
                        height: Config.barHeight + dockedShadow.past
                        color: dockedShadow.shapeColor
                    }

                    ConcaveCorner {
                        x: 0
                        y: bar.cornerY
                        size: Config.barCornerSize
                        flipped: Config.barOnBottom
                        color: dockedShadow.shapeColor
                    }

                    ConcaveCorner {
                        x: parent.width - width
                        y: bar.cornerY
                        size: Config.barCornerSize
                        flipped: Config.barOnBottom
                        color: dockedShadow.shapeColor
                        mirrored: true
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

                        PanelShadow {
                            visible: Config.barFloating && Config.shadowEnabled
                            radius: parent.radius
                        }
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

                        LauncherButton {}

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

                    // --- CENTER: the clock and the optional buttons that
                    // open the dashboard, in the order of its tabs ---
                    BarIsland {
                        id: center
                        anchors.centerIn: parent

                        CalendarButton {}

                        MediaButton {}

                        SystemMonitorButton {}

                        WeatherButton {}
                    }

                    DashboardWindow {
                        screen: bar.modelData
                        anchorItem: center
                    }

                    // --- RIGHT: tray, quick settings ---
                    BarIsland {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        KeyboardLayoutButton {
                            id: layoutButton
                        }

                        BarDivider {
                            visible: layoutButton.visible
                        }

                        TrayWidget {}

                        BarDivider {
                            visible: TrayService.hasItems
                        }

                        QuickSettingsButton {}
                    }
                }
            }
        }
    }
}
