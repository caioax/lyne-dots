pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.config

Item {
    id: root

    // --- Sizing Properties ---
    readonly property int itemWidth: Config.fontSizeSmall + Math.round(Config.padding / 2)
    readonly property int itemHeight: itemWidth
    readonly property int activeWidth: itemWidth * 2
    readonly property int activeHeight: Config.fontSizeSmall + Config.padding
    readonly property int itemSpacing: Math.round(Config.padding * 2 / 3)
    readonly property int visibleCount: 9
    readonly property int totalWorkspaces: 99

    // --- Monitor Logic ---
    readonly property var parentWindow: QsWindow.window
    readonly property var parentScreen: parentWindow?.screen ?? null

    property var currentMonitor: {
        if (!Hyprland)
            return null;
        return (parentScreen ? Hyprland.monitorFor(parentScreen) : null) ?? Hyprland.focusedMonitor ?? null;
    }

    readonly property string monitorName: currentMonitor?.name ?? ""
    property var activeWorkspace: currentMonitor?.activeWorkspace ?? null

    // --- Special Workspace Detection ---
    property string manualSpecialName: ""
    readonly property bool isSpecialWorkspace: manualSpecialName !== ""

    readonly property string specialWorkspaceName: {
        if (!isSpecialWorkspace)
            return "";
        return manualSpecialName.startsWith("special:") ? manualSpecialName.substring(8) : manualSpecialName;
    }

    // --- Normal Workspace Math ---
    property int activeId: (activeWorkspace && activeWorkspace.id > 0) ? activeWorkspace.id : 1
    property int monitorOffset: Math.floor((activeId - 1) / 100) * 100
    readonly property int relativeActiveId: Math.max(1, Math.min(activeId - monitorOffset, totalWorkspaces))

    // --- Layout Dimensions ---
    readonly property real viewportWidth: (itemWidth * visibleCount) + (activeWidth - itemWidth) + (itemSpacing * (visibleCount - 1))
    readonly property real itemStep: itemWidth + itemSpacing

    implicitWidth: isSpecialWorkspace ? specialIndicator.width : viewportWidth
    implicitHeight: activeHeight + itemSpacing

    // --- Special Workspaces Config ---
    readonly property var specialWorkspaces: ({
            "whatsapp": {
                icon: "󰖣",
                color: Config.successColor,
                name: "WhatsApp"
            },
            "spotify": {
                icon: "󰓇",
                color: Config.accentColor,
                name: "Music"
            },
            "magic": {
                icon: "󰀘",
                color: Config.warningColor,
                name: "Magic"
            }
        })

    // --- Cache Logic to prevent flashing ---
    property string cachedIcon: "󰀘"
    property string cachedName: ""
    property color cachedColor: Config.accentColor

    readonly property var currentSpecialConfig: {
        if (!isSpecialWorkspace)
            return null;
        return specialWorkspaces[specialWorkspaceName] ?? {
            icon: "󰀘",
            color: Config.accentColor,
            name: specialWorkspaceName.charAt(0).toUpperCase() + specialWorkspaceName.slice(1)
        };
    }

    // Updates the cache only when there is a valid workspace
    onCurrentSpecialConfigChanged: {
        if (currentSpecialConfig) {
            cachedIcon = currentSpecialConfig.icon;
            cachedName = currentSpecialConfig.name;
            cachedColor = currentSpecialConfig.color;
        }
    }

    // --- Scroll Logic ---
    readonly property int targetIndex: relativeActiveId - 1

    // The strip only scrolls when the active workspace leaves the visible
    // window, so switching among 1-9 never moves the other pills
    property int firstVisible: 0
    onTargetIndexChanged: {
        if (targetIndex < firstVisible)
            firstVisible = targetIndex;
        else if (targetIndex > firstVisible + visibleCount - 1)
            firstVisible = Math.min(targetIndex - visibleCount + 1, totalWorkspaces - visibleCount);
    }

    property real animatedScrollX: firstVisible * itemStep
    Behavior on animatedScrollX {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    // --- Occupied Workspaces ---
    property var occupiedWorkspaces: ({})
    function updateOccupiedWorkspaces() {
        if (!Hyprland || !Hyprland.workspaces)
            return;
        let newObj = {};
        for (let ws of Hyprland.workspaces.values) {
            if (ws && ws.id > 0)
                newObj[ws.id] = true;
        }
        occupiedWorkspaces = newObj;
    }

    Component.onCompleted: updateOccupiedWorkspaces()

    Timer {
        id: occupiedUpdateTimer
        interval: 10
        onTriggered: root.updateOccupiedWorkspaces()
    }

    // --- Event Handling ---
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!event)
                return;
            if (event.name === "activespecial") {
                let parts = event.data.split(',');
                let wsName = parts[0] || "";
                let targetMonitor = parts[1] || "";
                if (targetMonitor === "" || targetMonitor === root.monitorName) {
                    root.manualSpecialName = wsName;
                }
            }
            if (event.name === "workspace") {
                root.manualSpecialName = "";
                occupiedUpdateTimer.restart();
            }
            const refreshEvents = ["createworkspace", "destroyworkspace", "movewindow", "openwindow", "closewindow"];
            if (refreshEvents.includes(event.name))
                occupiedUpdateTimer.restart();
        }
    }

    // =========================================================================
    // SPECIAL WORKSPACE INDICATOR
    // =========================================================================
    Rectangle {
        id: specialIndicator
        visible: opacity > 0
        anchors.centerIn: parent

        // Opacity depends only on whether the state is special
        opacity: root.isSpecialWorkspace ? (specialHover.hovered ? 0.8 : 1.0) : 0

        scale: root.isSpecialWorkspace ? 1.0 : 0.9
        property int yOffset: root.isSpecialWorkspace ? 0 : Config.padding
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: yOffset

        width: specialContent.width + Config.padding * 3
        height: root.activeHeight
        radius: Config.radius

        color: root.cachedColor
        border.width: 1

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDurationShort
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on anchors.verticalCenterOffset {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Config.animDuration
            }
        }

        Row {
            id: specialContent
            anchors.centerIn: parent
            spacing: Config.padding * 0.8

            Text {
                // Uses the cached icon
                text: root.cachedIcon
                font {
                    family: Config.font
                    pixelSize: Config.fontSizeLarge
                }
                color: Config.textReverseColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                // Uses the cached name
                text: root.cachedName
                font {
                    family: Config.font
                    bold: true
                    pixelSize: Config.fontSizeNormal
                }
                color: Config.textReverseColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        TapHandler {
            onTapped: {
                if (root.specialWorkspaceName)
                    Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"" + root.specialWorkspaceName + "\")");
            }
        }
        HoverHandler {
            id: specialHover
            cursorShape: Qt.PointingHandCursor
        }
    }

    // =========================================================================
    // NORMAL WORKSPACES LIST
    // =========================================================================
    Item {
        id: workspacesContainer
        visible: !root.isSpecialWorkspace
        opacity: visible ? 1 : 0
        width: root.viewportWidth
        height: parent.height
        anchors.centerIn: parent
        clip: true

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
            }
        }

        Item {
            id: container
            x: -root.animatedScrollX
            width: (root.totalWorkspaces * root.itemStep) + (root.activeWidth - root.itemWidth)
            height: parent.height

            Repeater {
                model: root.totalWorkspaces
                delegate: Rectangle {
                    id: workspaceItem
                    required property int index
                    readonly property int workspaceId: root.monitorOffset + index + 1
                    readonly property bool isActive: workspaceId === root.activeId
                    readonly property bool isEmpty: root.occupiedWorkspaces[workspaceId] !== true

                    x: (index > root.targetIndex) ? (index * root.itemStep) + (root.activeWidth - root.itemWidth) : (index * root.itemStep)
                    anchors.verticalCenter: parent.verticalCenter
                    width: isActive ? root.activeWidth : root.itemWidth
                    height: isActive ? root.activeHeight : root.itemHeight
                    radius: Config.radius
                    color: isActive ? Config.accentColor : (!isEmpty ? Config.surface3Color : Qt.alpha(Config.surface2Color, 0.65))
                    opacity: !isActive ? (workspaceHover.hovered ? 0.8 : 1.0) : 1

                    // Same timing as the strip scroll, so pill and strip move together
                    Behavior on x {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animDuration
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animDurationShort
                        }
                    }

                    TapHandler {
                        onTapped: {
                            if (!workspaceItem.isActive)
                                Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspaceItem.workspaceId + " })");
                        }
                    }

                    HoverHandler {
                        id: workspaceHover
                        cursorShape: {
                            if (!workspaceItem.isActive)
                                return Qt.PointingHandCursor;
                        }
                    }
                }
            }
        }
    }
}
