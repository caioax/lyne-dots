pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services

// Keyboard layout in use ("US"). Click: the layouts of the keyboard typed on
// last, to pick one; wheel: next / previous; right click: Keyboard settings.
// bar.keyboardLayout: auto (only with 2+ layouts) | always | never
BarButton {
    id: root

    readonly property int count: KeyboardService.activeLayouts.length

    visible: KeyboardService.activeShort !== "" && (Config.barKeyboardLayout === "always" || (Config.barKeyboardLayout === "auto" && count > 1))
    active: popup.visible
    contentItem: content
    onClicked: popup.visible ? popup.closeWindow() : popup.reopen()
    onRightClicked: {
        SettingsService.currentPage = "keyboard";
        SettingsService.visible = true;
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => KeyboardService.switchLayout(event.angleDelta.y < 0 ? "next" : "prev")
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Math.round(Config.padding / 2)

        // md-keyboard
        Text {
            text: "\u{f030c}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: root.active ? Config.accentColor : Config.subtextColor
        }

        Text {
            text: KeyboardService.activeShort
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: root.active ? Config.accentColor : Config.textColor
        }
    }

    QsPopupWindow {
        id: popup

        anchorItem: root
        anchorSide: "right"
        moduleName: "KeyboardLayout"
        popupWidth: Config.fontSizeNormal * 28
        // The frame adds 32 around the content (QsPopupWindow)
        popupMaxHeight: list.implicitHeight + 32 + Config.padding
        contentImplicitHeight: list.implicitHeight
        visible: false

        ColumnLayout {
            id: list

            width: parent?.width ?? 0
            spacing: Math.round(Config.padding / 2)

            Text {
                Layout.leftMargin: Config.padding * 2
                Layout.bottomMargin: Config.padding
                text: "Keyboard layout"
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.subtextColor
            }

            Repeater {
                model: KeyboardService.activeLayouts

                Rectangle {
                    id: layoutRow

                    required property var modelData
                    required property int index
                    readonly property bool current: index === KeyboardService.activeIndex
                    readonly property color hoverTint: Config.surface1Color

                    Layout.fillWidth: true
                    implicitHeight: Config.fontSizeIconSmall * 2 + Config.padding
                    radius: Config.radius
                    color: current ? Qt.alpha(Config.accentColor, 0.15) : rowMouse.containsMouse ? hoverTint : Qt.alpha(hoverTint, 0)

                    Behavior on color {
                        enabled: !Config.themeTransitioning
                        ColorAnimation {
                            duration: Config.animDurationShort
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Config.padding * 2
                        anchors.rightMargin: Config.padding * 2
                        spacing: Config.spacing

                        Rectangle {
                            implicitWidth: Config.fontSizeIconSmall * 1.6
                            implicitHeight: implicitWidth
                            radius: Config.radiusSmall
                            color: layoutRow.current ? Qt.alpha(Config.accentColor, 0.2) : Config.surface1Color

                            Text {
                                anchors.centerIn: parent
                                text: KeyboardService.shortName(layoutRow.modelData)
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                font.bold: true
                                color: layoutRow.current ? Config.accentColor : Config.subtextColor
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: KeyboardService.describe(layoutRow.modelData)
                            elide: Text.ElideRight
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            color: Config.textColor
                        }

                        // md-check
                        Text {
                            visible: layoutRow.current
                            text: "\u{f012c}"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeIconSmall
                            color: Config.accentColor
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            KeyboardService.switchLayout(layoutRow.index);
                            popup.closeWindow();
                        }
                    }
                }
            }

            // Shortcut hint and a way to the settings
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Config.padding
                Layout.leftMargin: Config.padding * 2
                Layout.rightMargin: Config.padding
                spacing: Config.spacing

                Text {
                    Layout.fillWidth: true
                    readonly property string keys: KeybindsService.split(KeybindsService.binds.find(b => b.id === "switch-layout")?.keys ?? "").join(" + ")
                    text: keys !== "" ? keys + " switches layouts" : ""
                    elide: Text.ElideRight
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }

                ActionButton {
                    text: "Settings"
                    onClicked: {
                        popup.closeWindow();
                        SettingsService.currentPage = "keyboard";
                        SettingsService.visible = true;
                    }
                }
            }
        }
    }
}
