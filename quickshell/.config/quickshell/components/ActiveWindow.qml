pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.config

Item {
    id: root

    property int maxWidth: 400

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
                    if (root) root.windowExists = Hyprland.activeToplevel !== null;
                });
            }
        }
    }

    implicitWidth: windowExists ? content.implicitWidth : 0
    implicitHeight: content.implicitHeight

    visible: opacity > 0
    opacity: windowExists ? 1.0 : 0.0

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
        spacing: 6
        anchors.fill: parent

        Text {
            id: titleText
            text: root.windowTitle !== "" ? "   " + root.windowTitle : ""
            color: Config.surface3Color
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            elide: Text.ElideRight

            Layout.fillWidth: true
            Layout.maximumWidth: root.maxWidth
        }
    }
}
