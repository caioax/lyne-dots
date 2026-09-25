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

    // Each bar shows the window of its own monitor: the focused window on the
    // focused monitor, else the last one focused on the workspace it shows
    readonly property var parentScreen: QsWindow.window?.screen ?? null
    readonly property var monitor: (parentScreen ? Hyprland.monitorFor(parentScreen) : null) ?? Hyprland.focusedMonitor
    readonly property var workspace: monitor?.activeWorkspace ?? null

    readonly property var toplevel: {
        const active = Hyprland.activeToplevel;
        if (active && active.workspace === workspace)
            return active;
        const last = root.bareAddress(workspace?.lastIpcObject?.lastwindow);
        const toplevels = workspace?.toplevels?.values ?? [];
        return last !== "" ? toplevels.find(t => root.bareAddress(t.address) === last) ?? null : null;
    }

    function bareAddress(address): string {
        return String(address ?? "").replace(/^0x/, "");
    }

    // Clicking the desktop sends an empty "activewindowv2" but leaves
    // Hyprland.activeToplevel set, so the focused monitor tracks it here
    property bool focusCleared: false
    readonly property bool windowExists: toplevel !== null && !(monitor?.focused && focusCleared)

    readonly property string windowTitle: toplevel?.title ?? ""

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindowv2")
                root.focusCleared = event.data === "," || event.data === "";
            // The last window of each workspace (lastIpcObject) only updates
            // on a refresh
            if (["activewindowv2", "workspacev2", "focusedmonv2", "closewindow", "movewindowv2"].includes(event.name))
                Qt.callLater(Hyprland.refreshWorkspaces);
        }
    }

    readonly property string appId: toplevel?.wayland?.appId ?? ""
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
