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

    // osd.style -> component
    readonly property var styles: ({
            pill: pillStyle
        })

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
            readonly property bool atTop: Config.osdPosition === "top"
            // Room for a bar on the same edge
            readonly property int barRoom: atTop !== Config.barOnBottom ? Config.barReservedHeight : 0

            screen: modelData

            anchors.top: atTop
            anchors.bottom: !atTop
            margins.top: atTop ? barRoom + Config.spacing * 2 : 0
            margins.bottom: atTop ? 0 : barRoom + Config.spacing * 8
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs_modules"

            implicitWidth: styleLoader.implicitWidth
            implicitHeight: styleLoader.implicitHeight
            color: "transparent"

            // Doesn't take the mouse
            mask: Region {}

            AnimatedPopup {
                anchors.fill: parent
                shown: OsdService.shown
                transformOrigin: osdWindow.atTop ? Item.Top : Item.Bottom

                Loader {
                    id: styleLoader

                    anchors.fill: parent
                    sourceComponent: root.styles[Config.osdStyle] ?? pillStyle
                }
            }
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
}
