pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.config
import "../../components/"
import "../../components/osd/"

// On-screen display for volume and brightness. Lives while
// OsdService.mapped (see shell.qml), so the exit animation plays
Scope {
    id: root

    // Focused monitor when it opened, or every monitor (osd.monitor)
    readonly property var screens: {
        if (Config.osdMonitor === "all")
            return Quickshell.screens;
        const focused = Quickshell.screens.filter(s => s.name === OsdService.screenName);
        return focused.length > 0 ? focused : [Quickshell.screens[0]];
    }

    Variants {
        model: root.screens

        PanelWindow {
            id: osdWindow

            required property ShellScreen modelData

            readonly property bool attached: OsdService.style === "attached"
            readonly property string barEdge: Config.barOnBottom ? "bottom" : "top"
            // Screen side the OSD sits on, "" when centered
            readonly property string edge: {
                const position = OsdService.position;
                if (attached)
                    return position === "bar" ? barEdge : (barEdge === "top" ? "bottom" : "top");
                return position === "center" ? "" : position;
            }
            // Distance from that side: attached panels touch a docked bar (or
            // the screen edge), the others keep clear of the bar
            readonly property real edgeMargin: {
                const onBar = edge === barEdge;
                if (attached)
                    return onBar && !Config.barIslands && !Config.barFloating ? Config.barHeight : 0;
                if (edge === "left" || edge === "right")
                    return Config.spacing * 2;
                return (onBar ? Config.barReservedHeight : 0) + (edge === "top" ? Config.spacing * 2 : Config.spacing * 8);
            }

            // osd.style -> component
            readonly property var styles: ({
                    pill: pillStyle,
                    vertical: verticalStyle,
                    card: cardStyle,
                    attached: attachedStyle
                })

            screen: modelData

            anchors.top: edge === "top"
            anchors.bottom: edge === "bottom"
            anchors.left: edge === "left"
            anchors.right: edge === "right"
            margins.top: edge === "top" ? edgeMargin : 0
            margins.bottom: edge === "bottom" ? edgeMargin : 0
            margins.left: edge === "left" ? edgeMargin : 0
            margins.right: edge === "right" ? edgeMargin : 0
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            // Attached panels share the bar's tint (see AttachedPanel)
            WlrLayershell.namespace: attached ? "qs_attached" : "qs_modules"

            implicitWidth: styleLoader.implicitWidth
            implicitHeight: styleLoader.implicitHeight
            color: "transparent"

            // Doesn't take the mouse
            mask: Region {}

            // The attached style slides out by itself
            AnimatedPopup {
                anchors.fill: parent
                shown: OsdService.shown || osdWindow.attached
                fromScale: osdWindow.attached ? 1 : Config.animPopupFromScale
                transformOrigin: ({
                        top: Item.Top,
                        bottom: Item.Bottom,
                        left: Item.Left,
                        right: Item.Right
                    })[osdWindow.edge] ?? Item.Center

                Loader {
                    id: styleLoader

                    anchors.fill: parent
                    sourceComponent: osdWindow.styles[OsdService.style]
                }
            }

            Component {
                id: pillStyle

                PillStyle {
                    value: OsdService.value
                    muted: OsdService.muted
                    icon: OsdService.icon
                }
            }

            Component {
                id: verticalStyle

                VerticalStyle {
                    value: OsdService.value
                    muted: OsdService.muted
                    icon: OsdService.icon
                }
            }

            Component {
                id: cardStyle

                CardStyle {
                    value: OsdService.value
                    muted: OsdService.muted
                    icon: OsdService.icon
                    label: OsdService.label
                }
            }

            Component {
                id: attachedStyle

                AttachedStyle {
                    value: OsdService.value
                    muted: OsdService.muted
                    icon: OsdService.icon
                    edge: osdWindow.edge
                    shown: OsdService.shown
                }
            }
        }
    }
}
