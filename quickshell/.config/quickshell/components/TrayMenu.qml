pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

PanelWindow {
    id: root

    // Properties received when opening
    property var rootMenuHandle: null
    property int anchorX: 0
    property int anchorY: 0

    // --- WINDOW CONFIGURATION ---
    color: "transparent"

    // Size
    implicitWidth: Math.max(220, mainColumn.implicitWidth)
    implicitHeight: mainColumn.implicitHeight

    WlrLayershell.namespace: "qs_modules"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: -1

    // Positions where the mouse clicked (or icon)
    anchors {
        left: true
        top: true
    }
    margins {
        left: Math.min(root.screen.width - implicitWidth - 10, root.anchorX)
        top: Math.min(root.screen.height - implicitHeight - 10, root.anchorY)
    }

    // --- NAVIGATION SYSTEM ---
    // Keeps the history of where we are. If empty, we are at the root.
    ListModel {
        id: menuStack
    }

    function pushSubMenu(menuItem) {
        if (menuItem && menuItem.menu) {
            // Adds the submenu to the history
            menuStack.append({
                "handle": menuItem.menu
            });
        }
    }

    function popSubMenu() {
        if (menuStack.count > 0) {
            menuStack.remove(menuStack.count - 1);
        }
    }

    // Defines which menu to show: the last from the stack or the root
    property var currentMenuHandle: {
        if (menuStack.count > 0) {
            return menuStack.get(menuStack.count - 1).handle;
        }
        return root.rootMenuHandle;
    }

    // --- FOCUS AND CLOSING ---
    HyprlandFocusGrab {
        id: focusGrab
        windows: [root]
        active: false
        onCleared: root.close()
    }

    function open() {
        root.visible = true;
        focusTimer.restart();
    }

    function close() {
        root.visible = false;
        menuStack.clear(); // Resets navigation on close
        focusGrab.active = false;
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
            focusGrab.active = true;
            background.forceActiveFocus();
        }
    }

    // The object that reads the items of the current menu
    QsMenuOpener {
        id: menuOpener
        menu: root.currentMenuHandle
    }

    // --- VISUALS ---
    Rectangle {
        id: background
        anchors.fill: parent
        color: Config.backgroundTransparentColor
        border.color: Config.surface2Color
        border.width: 1
        radius: Config.radius
        clip: true

        focus: true
        Keys.onEscapePressed: {
            if (menuStack.count > 0)
                popSubMenu();
            else
                root.close();
        }

        ColumnLayout {
            id: mainColumn
            width: parent.width
            spacing: 0

            // --- HEADER / BACK ---
            // Only appears if we are inside a submenu
            Rectangle {
                visible: menuStack.count > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                color: backMouse.containsMouse ? Config.surface1Color : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 5
                    Text {
                        text: "⬅ Back"
                        color: Config.accentColor
                        font.family: Config.font
                        font.bold: true
                        font.pixelSize: Config.fontSizeSmall
                    }
                }
                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: popSubMenu()
                }
            }

            // Divider if there is a back button
            Rectangle {
                visible: menuStack.count > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Config.surface2Color
            }

            // --- ITEMS LIST ---
            Repeater {
                model: menuOpener.children

                delegate: Rectangle {
                    id: itemDelegate

                    required property var modelData
                    required property int index

                    // Helpers
                    property bool isSeparator: (modelData.type === "separator" || modelData.isSeparator === true)
                    property bool isEnabled: modelData.enabled !== false
                    property bool hasSubMenu: (modelData.children && modelData.children.length > 0) || modelData.type === "menu"

                    Layout.preferredWidth: mainColumn.width - 3
                    Layout.preferredHeight: isSeparator ? 6 : 32
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                    color: itemMouse.containsMouse && !isSeparator ? Config.surface1Color : "transparent"
                    radius: Config.radius
                    opacity: isEnabled ? 1.0 : 0.5

                    // Separator
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 10
                        height: 1
                        color: Config.surface2Color
                        visible: parent.isSeparator
                    }

                    // Item Content
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10
                        visible: !parent.isSeparator

                        // Icon (resolved via TrayService to handle theme names, pixmaps, and file paths)
                        Image {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            source: modelData.icon ? TrayService.getMenuIconSource(modelData.icon) : ""
                            visible: source !== "" && status === Image.Ready
                            sourceSize: Qt.size(16, 16)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }

                        // Checkbox
                        Rectangle {
                            Layout.preferredWidth: 10
                            Layout.preferredHeight: 10
                            radius: (modelData.toggleType === 2) ? 5 : 2
                            color: "transparent"
                            border.color: Config.textColor
                            visible: (modelData.toggleType > 0) && (modelData.checked === true || modelData.status === "active")
                            Rectangle {
                                anchors.centerIn: parent
                                width: 6
                                height: 6
                                radius: parent.radius - 1
                                color: Config.textColor
                            }
                        }

                        // Text
                        Text {
                            text: {
                                var txt = modelData.text || modelData.title || "";
                                return txt.replace(/&/g, "").replace(/_/g, "");
                            }
                            color: Config.textColor
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        // Submenu Arrow
                        Text {
                            visible: parent.parent.hasSubMenu
                            text: "›"
                            color: Config.subtextColor
                            font.pixelSize: 14
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: !parent.isSeparator && parent.isEnabled
                        enabled: hoverEnabled
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (parent.hasSubMenu) {
                                // Pushes the submenu and the interface updates automatically
                                root.pushSubMenu(modelData);
                            } else {
                                // Normal Action
                                if (typeof modelData.activate === 'function')
                                    modelData.activate();
                                else if (typeof modelData.triggered === 'function')
                                    modelData.triggered();
                                else if (typeof modelData.click === 'function')
                                    modelData.click();

                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
