pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config

Item {
    id: root

    property int maxWidth: Config.fontSizeNormal * 18

    // Internal state to force clearing
    property bool windowExists: Hyprland.activeToplevel !== null

    readonly property string windowTitle: Hyprland.activeToplevel?.title ?? ""

    // Logic to verify focus changes
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // "activewindowv2" is sent even when clicking the desktop (returns empty)
            if (event.name === "activewindowv2") {
                // If the address is empty, no window is focused
                root.windowExists = event.data !== "," && event.data !== "";
            }

            // Clear title when changing workspaces to an empty one
            if (event.name === "workspace") {
                // Small delay to let Hyprland update its internal state
                Qt.callLater(() => {
                    if (root)
                        root.windowExists = Hyprland.activeToplevel !== null;
                });
            }
        }
    }

    readonly property string appId: Hyprland.activeToplevel?.wayland?.appId ?? ""
    readonly property string appIcon: appId !== "" ? Quickshell.iconPath(appId, true) : ""

    implicitWidth: windowExists && windowTitle !== "" ? content.implicitWidth : 0
    implicitHeight: content.implicitHeight

    visible: implicitWidth > 0
    opacity: windowExists ? 1 : 0
    clip: true

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animDuration
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    RowLayout {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: Config.padding

        IconImage {
            visible: root.appIcon !== ""
            implicitSize: Config.fontSizeNormal
            source: root.appIcon
        }

        Text {
            text: root.windowTitle
            color: Config.subtextColor
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            elide: Text.ElideRight
            Layout.maximumWidth: root.maxWidth
        }
    }
}
