pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.config

Scope {
    id: root

    // Icons for each type (Nerd Font)
    readonly property var icons: ({
            "volume_off": "󰖁",
            "volume_low": "󰕿",
            "volume_medium": "󰖀",
            "volume_high": "󰕾",
            "mute": "󰝟",
            "brightness_low": "󰃞",
            "brightness_medium": "󰃟",
            "brightness_high": "󰃠"
        })

    function getIcon(): string {
        if (OsdService.type === "mute" || OsdService.muted) {
            return icons.mute;
        }
        if (OsdService.type === "brightness") {
            if (OsdService.value < 0.3)
                return icons.brightness_low;
            if (OsdService.value < 0.6)
                return icons.brightness_medium;
            return icons.brightness_high;
        }
        // Volume
        if (OsdService.value < 0.01)
            return icons.volume_off;
        if (OsdService.value < 0.33)
            return icons.volume_low;
        if (OsdService.value < 0.66)
            return icons.volume_medium;
        return icons.volume_high;
    }

    // Create OSD on all monitors
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: osdWindow

            required property var modelData

            screen: modelData

            // Position: bottom-center of the screen
            anchors.bottom: true
            margins.bottom: 80
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs_modules"

            implicitWidth: content.width
            implicitHeight: content.height
            color: "transparent"

            // Does not block mouse
            mask: Region {}

            // Visibility controlled by the service
            visible: OsdService.visible

            Rectangle {
                id: content
                width: 280
                height: 50
                radius: Config.radiusLarge
                color: Config.backgroundTransparentColor
                border.color: Qt.alpha(Config.accentColor, 0.2)
                border.width: 1

                // Entry animation
                scale: OsdService.visible ? 1 : 0.8
                opacity: OsdService.visible ? 1 : 0

                Behavior on scale {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animDuration
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14

                    // Icon
                    Text {
                        text: root.getIcon()
                        font.family: Config.font
                        font.pixelSize: 22
                        color: OsdService.muted ? Config.mutedColor : Config.accentColor

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDurationShort
                            }
                        }
                    }

                    // Progress bar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        radius: 3
                        color: Config.surface1Color

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom

                            width: parent.width * Math.min(1, OsdService.value)
                            radius: parent.radius
                            color: OsdService.muted ? Config.mutedColor : Config.accentColor

                            Behavior on width {
                                NumberAnimation {
                                    duration: Config.animDurationShort
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDurationShort
                                }
                            }
                        }
                    }

                    // Percentage
                    Text {
                        text: Math.round(OsdService.value * 100) + "%"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeNormal
                        font.weight: Font.DemiBold
                        color: OsdService.muted ? Config.mutedColor : Config.textColor
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 42

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDurationShort
                            }
                        }
                    }
                }
            }
        }
    }
}
