pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import "../../services/monitors.js" as Lib

// Identify (Settings › Monitors): each screen shows for a moment the number
// its monitor has on the map, its name and port
Scope {
    id: root

    // Set a tick after creation so the cards animate in
    property bool ready: false

    Component.onCompleted: Qt.callLater(() => ready = true)

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData

            readonly property int index: MonitorsService.monitors.findIndex(m => m.name === modelData.name)
            readonly property var monitor: index >= 0 ? MonitorsService.monitors[index] : null

            screen: modelData
            visible: monitor !== null
            implicitWidth: card.implicitWidth
            implicitHeight: card.implicitHeight
            color: "transparent"

            // Blurred like the other shell popups (hypr conf/appearance.lua)
            WlrLayershell.namespace: "qs_modules"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                id: card

                implicitWidth: Math.max(Config.fontSizeNormal * 18, content.implicitWidth + Config.padding * 6)
                implicitHeight: content.implicitHeight + Config.padding * 6
                radius: Config.radiusLarge
                color: Config.backgroundTransparentColor
                border.width: 1
                border.color: Config.surface2Color

                opacity: root.ready ? 1 : 0
                scale: root.ready ? 1 : Config.animPopupFromScale

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animDurationLong
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Config.animDurationLong
                        easing.type: Config.animPopupEasing
                    }
                }

                ColumnLayout {
                    id: content

                    anchors.centerIn: parent
                    spacing: Config.spacing

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: window.index + 1
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconLarge * 4
                        font.bold: true
                        color: Config.accentColor
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: window.monitor ? Lib.labelFor(window.monitor) : ""
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeLarge
                        font.bold: true
                        color: Config.textColor
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: window.monitor ? window.monitor.name + " · " + window.monitor.width + "×" + window.monitor.height + " · " + Math.round(window.monitor.refreshRate) + " Hz" : ""
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        color: Config.subtextColor
                    }
                }
            }
        }
    }
}
