pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.config
import "../../components/"

PanelWindow {
    id: root

    visible: ClipboardService.visible

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "qs_modules"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    color: "transparent"

    // Click on background closes
    MouseArea {
        anchors.fill: parent
        onClicked: {
            contentLoader.item.forceActiveFocus();
            ClipboardService.hide();
        }
    }

    // Loader that creates/destroys the content
    Loader {
        id: contentLoader
        anchors.centerIn: parent
        active: ClipboardService.visible

        sourceComponent: Rectangle {
            id: content
            width: 520

            // Dynamic height based on content
            // Header(36) + spacing + searchBar(44) + spacing + separator(1) + margins(~28)
            property int fixedHeight: 36 + 44 + 1 + 28 + (Config.spacing * 3)
            property int listHeight: Math.min(420, clipList.contentHeight + 12)

            height: Math.max(200, fixedHeight + listHeight)
            radius: Config.radiusLarge
            color: Config.backgroundTransparentColor
            border.color: Qt.alpha(Config.accentColor, 0.2)
            border.width: 1

            // Smooth height animation
            Behavior on height {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Config.spacing + 4
                spacing: Config.spacing

                // Header
                RowLayout {
                    id: header
                    Layout.fillWidth: true
                    spacing: Config.spacing

                    // Icon
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: Config.radius
                        color: Config.surface1Color

                        Text {
                            anchors.centerIn: parent
                            text: "󰅍"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeLarge
                            color: Config.accentColor
                        }
                    }

                    // Title
                    Text {
                        Layout.fillWidth: true
                        text: "Clipboard"
                        font.family: Config.font
                        font.bold: true
                        font.pixelSize: Config.fontSizeLarge
                        color: Config.textColor
                    }

                    // Entry count
                    Rectangle {
                        visible: ClipboardService.filteredEntries.length > 0
                        Layout.preferredWidth: entryCountText.implicitWidth + 12
                        Layout.preferredHeight: 22
                        radius: height / 2
                        color: Config.surface1Color

                        Text {
                            id: entryCountText
                            anchors.centerIn: parent
                            text: ClipboardService.filteredEntries.length
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.subtextColor
                        }
                    }

                    // Clear All button
                    ClearButton {
                        visible: ClipboardService.entries.length > 0
                        icon: "󰆴"
                        text: "Clear"

                        onClicked: ClipboardService.clearAll()
                    }
                }

                // Search bar
                Rectangle {
                    id: searchBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: Config.radius
                    color: Config.surface0Color
                    border.width: searchInput.activeFocus ? 2 : 0
                    border.color: Config.accentColor

                    Behavior on border.width {
                        NumberAnimation {
                            duration: Config.animDurationShort
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Config.spacing + 6
                        anchors.rightMargin: Config.spacing + 6
                        spacing: Config.spacing

                        Text {
                            text: ""
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            color: searchInput.activeFocus ? Config.accentColor : Config.subtextColor

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDurationShort
                                }
                            }
                        }

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            color: Config.textColor
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            placeholderText: "Search clipboard..."
                            placeholderTextColor: Config.mutedColor

                            background: null

                            onTextChanged: ClipboardService.query = text

                            Keys.onEscapePressed: {
                                focus = false;
                                ClipboardService.hide();
                            }
                            Keys.onReturnPressed: ClipboardService.selectCurrent()
                            Keys.onUpPressed: ClipboardService.navigateUp()
                            Keys.onDownPressed: ClipboardService.navigateDown()
                            Keys.onTabPressed: event => {
                                ClipboardService.navigateDown();
                                event.accepted = true;
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                                    ClipboardService.navigateUp();
                                    event.accepted = true;
                                }
                            }

                            Component.onCompleted: {
                                ClipboardService.query = "";
                                ClipboardService.selectedIndex = 0;
                                Qt.callLater(forceActiveFocus);
                            }
                        }

                        // Clear search button
                        Rectangle {
                            visible: searchInput.text
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: height / 2
                            color: clearSearchMouse.containsMouse ? Config.surface2Color : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.subtextColor
                            }

                            MouseArea {
                                id: clearSearchMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.text = "";
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    id: separator
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Config.surface1Color
                }

                // Clipboard list
                ListView {
                    id: clipList
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    clip: true
                    spacing: 2
                    model: ClipboardService.filteredEntries
                    currentIndex: ClipboardService.selectedIndex

                    // Custom highlight
                    highlightFollowsCurrentItem: false
                    highlight: Rectangle {
                        width: clipList.width
                        height: 44
                        radius: Config.radius
                        color: Config.surface2Color

                        y: clipList.currentItem ? clipList.currentItem.y : 0

                        Behavior on y {
                            NumberAnimation {
                                duration: Config.animDurationShort
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    delegate: Item {
                        id: delegateItem
                        required property int index
                        required property var modelData

                        width: clipList.width
                        height: 44

                        property bool isSelected: index === ClipboardService.selectedIndex
                        property bool isHovered: delegateMouse.containsMouse

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 8

                            // Entry number
                            Text {
                                Layout.preferredWidth: 24
                                text: (delegateItem.index + 1).toString()
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.mutedColor
                                horizontalAlignment: Text.AlignRight
                            }

                            // Clipboard text
                            Text {
                                Layout.fillWidth: true
                                text: delegateItem.modelData?.text ?? ""
                                color: delegateItem.isSelected ? Config.textColor : Config.subtextColor
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeNormal
                                font.weight: delegateItem.isSelected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            // Delete button (visible on hover)
                            Rectangle {
                                visible: delegateItem.isHovered || delegateItem.isSelected
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: height / 2
                                color: deleteMouse.containsMouse ? Qt.alpha(Config.errorColor, 0.2) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.family: Config.font
                                    font.pixelSize: 12
                                    color: deleteMouse.containsMouse ? Config.errorColor : Config.mutedColor
                                }

                                MouseArea {
                                    id: deleteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ClipboardService.deleteItem(delegateItem.index)
                                }
                            }

                            // Selection indicator
                            Text {
                                visible: delegateItem.isSelected
                                text: "󰌑"
                                color: Config.accentColor
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                            }
                        }

                        MouseArea {
                            id: delegateMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Let delete button clicks through
                            propagateComposedEvents: true

                            onClicked: mouse => {
                                if (delegateItem.isSelected) {
                                    ClipboardService.selectItem(delegateItem.index);
                                } else {
                                    ClipboardService.selectedIndex = delegateItem.index;
                                }
                            }
                        }
                    }

                    // Empty state
                    Column {
                        anchors.centerIn: parent
                        spacing: Config.spacing
                        visible: clipList.count === 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: ClipboardService.query ? "󰅖" : "󰅍"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeIconLarge
                            color: Config.mutedColor
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: ClipboardService.query ? "No results" : "Clipboard is empty"
                            color: Config.subtextColor
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                        }
                    }

                    // Auto-scroll when navigating
                    onCurrentIndexChanged: {
                        positionViewAtIndex(currentIndex, ListView.Contain);
                    }

                    // Scrollbar
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded

                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: Config.surface2Color
                            opacity: parent.active ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Config.animDurationShort
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Focus grab
    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: ClipboardService.hide()
    }
}
