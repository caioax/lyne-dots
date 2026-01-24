pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.config

Item {
    id: root

    // --- Sizing Properties ---
    readonly property int itemWidth: 15
    readonly property int itemHeight: 15
    readonly property int activeWidth: 30
    readonly property int activeHeight: 18
    readonly property int itemSpacing: 4
    readonly property int visibleCount: 9
    readonly property int totalWorkspaces: 99

    // --- Calculated Dimensions ---
    readonly property real viewportWidth: (itemWidth * visibleCount) + (activeWidth - itemWidth) + (itemSpacing * (visibleCount - 1))
    readonly property real itemStep: itemWidth + itemSpacing

    implicitWidth: isSpecialWorkspace ? specialIndicator.width : viewportWidth
    implicitHeight: activeHeight + 4

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
                icon: "",
                color: Config.warningColor,
                name: "Magic"
            }
        })

    // --- Monitor & Workspace Logic ---
    property var currentMonitor: screen ? Hyprland.monitorFor(screen) : (Hyprland.focusedMonitor ?? null)
    readonly property string activeSpecialFull: currentMonitor?.lastIpcObject?.specialWorkspace?.name ?? ""
    readonly property bool isSpecialWorkspace: activeSpecialFull !== ""

    readonly property string specialWorkspaceName: {
        if (!isSpecialWorkspace)
            return "";
        return activeSpecialFull.startsWith("special:") ? activeSpecialFull.substring(8) : activeSpecialFull;
    }

    readonly property var currentSpecialConfig: {
        if (!isSpecialWorkspace)
            return null;
        return specialWorkspaces[specialWorkspaceName] ?? {
            icon: "󰀘",
            color: Config.accentColor,
            name: specialWorkspaceName.charAt(0).toUpperCase() + specialWorkspaceName.slice(1)
        };
    }

    property var activeWorkspace: currentMonitor?.activeWorkspace ?? null
    property int activeId: activeWorkspace?.id ?? 1
    property int monitorOffset: Math.floor((activeId - 1) / 100) * 100

    readonly property int relativeActiveId: {
        let relative = activeId - monitorOffset;
        return Math.max(1, Math.min(relative, totalWorkspaces));
    }

    // --- Scroll Logic (clamped at edges) ---
    readonly property int targetIndex: relativeActiveId - 1

    readonly property real targetScrollX: {
        let centerOffset = Math.floor(visibleCount / 2);
        let maxScrollIndex = totalWorkspaces - visibleCount;
        let firstVisible = Math.max(0, Math.min(targetIndex - centerOffset, maxScrollIndex));
        return firstVisible * itemStep;
    }

    property real animatedScrollX: targetScrollX

    Behavior on animatedScrollX {
        NumberAnimation {
            duration: Config.animDurationLong
            easing.type: Easing.OutQuint
        }
    }

    // --- Visibility range for hybrid virtualization ---
    readonly property int renderBuffer: 10
    readonly property int renderStart: Math.max(0, targetIndex - renderBuffer)
    readonly property int renderEnd: Math.min(totalWorkspaces - 1, targetIndex + renderBuffer)

    // --- Cached workspace IDs (avoids accessing Hyprland.workspaces during rapid updates) ---
    property var occupiedWorkspaces: ({})

    function updateOccupiedWorkspaces() {
        let newObj = {};
        let values = Hyprland.workspaces?.values;
        if (values) {
            for (let ws of values) {
                if (ws && ws.id > 0) newObj[ws.id] = true;
            }
        }
        occupiedWorkspaces = newObj;
    }

    Component.onCompleted: updateOccupiedWorkspaces()

    Timer {
        id: occupiedUpdateTimer
        interval: 50
        onTriggered: root.updateOccupiedWorkspaces()
    }

    // --- IPC Listeners (debounced to avoid race conditions) ---
    Timer {
        id: refreshDebounce
        interval: 16  // ~1 frame
        onTriggered: {
            if (Hyprland) Hyprland.refreshMonitors();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activespecial" || event.name === "workspace" || event.name === "focusedmon") {
                refreshDebounce.restart();
            }
            // Update occupied workspaces cache on relevant events
            if (event.name === "createworkspace" || event.name === "destroyworkspace" ||
                event.name === "openwindow" || event.name === "closewindow" ||
                event.name === "movewindow") {
                occupiedUpdateTimer.restart();
            }
        }
        function onFocusedMonitorChanged() {
            refreshDebounce.restart();
        }
    }

    // --- Transitions ---
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Config.animDuration
        }
    }

    // =========================================================================
    // SPECIAL WORKSPACE INDICATOR
    // =========================================================================
    Rectangle {
        id: specialIndicator
        visible: root.isSpecialWorkspace
        opacity: visible ? 1 : 0
        width: specialContent.width + Config.padding * 3
        height: root.activeHeight
        anchors.verticalCenter: parent.verticalCenter
        radius: Config.radius
        color: root.currentSpecialConfig?.color ?? Config.accentColor
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.1)

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
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
                text: root.currentSpecialConfig?.icon ?? "󰀘"
                font {
                    family: Config.font
                    pixelSize: Config.fontSizeLarge
                }
                color: Config.textReverseColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.currentSpecialConfig?.name ?? root.specialWorkspaceName
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
                let wsName = root.specialWorkspaceName;
                if (wsName)
                    Hyprland.dispatch("togglespecialworkspace " + wsName);
            }
        }

        HoverHandler {
            id: specialHover
            cursorShape: Qt.PointingHandCursor
        }

        scale: specialHover.hovered ? 0.95 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: Config.animDuration
            }
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

            // Modelo numérico fixo - delegates são reusados, não recriados
            Repeater {
                model: root.totalWorkspaces

                delegate: Rectangle {
                    id: workspaceItem
                    required property int index

                    readonly property int workspaceId: root.monitorOffset + index + 1
                    readonly property bool isActive: workspaceId === root.activeId && !root.isSpecialWorkspace
                    readonly property bool isEmpty: root.occupiedWorkspaces[workspaceId] !== true

                    // Hybrid virtualization: renderiza só os próximos do ativo
                    readonly property bool shouldRender: index >= root.renderStart && index <= root.renderEnd
                    visible: shouldRender

                    x: {
                        let baseX = index * root.itemStep;
                        return (index > root.targetIndex) ? baseX + (root.activeWidth - root.itemWidth) : baseX;
                    }

                    anchors.verticalCenter: parent.verticalCenter
                    width: isActive ? root.activeWidth : root.itemWidth
                    height: isActive ? root.activeHeight : root.itemHeight
                    radius: Config.radius

                    color: isActive ? Config.accentColor : (!isEmpty ? Config.surface3Color : Config.surface1Color)

                    Behavior on x {
                        NumberAnimation {
                            duration: Config.animDurationShort
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: Config.animDurationShort
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: Config.animDurationShort
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animDuration
                        }
                    }

                    TapHandler {
                        onTapped: {
                            let targetId = workspaceItem.workspaceId;
                            Hyprland.dispatch("workspace " + targetId);
                        }
                    }

                    HoverHandler {
                        id: hoverHandler
                        cursorShape: !workspaceItem.isActive ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }

                    opacity: hoverHandler.hovered && !isActive ? 0.7 : 1.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animDuration
                        }
                    }
                }
            }
        }
    }
}
