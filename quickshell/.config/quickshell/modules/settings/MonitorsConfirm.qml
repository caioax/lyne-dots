pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services
import "../../components/"

// "Keep these display settings?" on every monitor while MonitorsService
// tries new ones: whichever screen still shows something can answer, and
// the keyboard goes to the focused monitor's card, so Enter keeps and Esc
// reverts even on a black screen. Doing nothing reverts when the time runs
// out. Doesn't dim: the point is to look at the result.
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
            // The focused monitor takes the keyboard (the first one when
            // Hyprland doesn't say)
            readonly property bool hasKeyboard: {
                const name = Hyprland.focusedMonitor?.name ?? "";
                const known = Quickshell.screens.some(s => s.name === name);
                return known ? modelData.name === name : modelData === Quickshell.screens[0];
            }

            screen: modelData
            anchors.top: true
            margins.top: Math.round(modelData.height * 0.12)
            implicitWidth: card.implicitWidth
            implicitHeight: card.implicitHeight
            color: "transparent"

            // Blurred like the other shell popups (hypr conf/appearance.lua)
            WlrLayershell.namespace: "qs_modules"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: hasKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Rectangle {
                id: card

                readonly property bool shown: root.ready

                implicitWidth: Config.fontSizeNormal * 30
                implicitHeight: content.implicitHeight + Config.padding * 4
                radius: Config.radiusLarge
                color: Config.backgroundTransparentColor
                border.width: 1
                border.color: Config.surface2Color

                opacity: shown ? 1 : 0
                scale: shown ? 1 : Config.animPopupFromScale

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

                Item {
                    anchors.fill: parent
                    focus: window.hasKeyboard
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            MonitorsService.keep();
                        else if (event.key === Qt.Key_Escape)
                            MonitorsService.revert("");
                        else
                            return;
                        event.accepted = true;
                    }
                }

                ColumnLayout {
                    id: content

                    anchors.fill: parent
                    anchors.margins: Config.padding * 2
                    spacing: Config.spacing * 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Config.padding

                        // md-monitor
                        Text {
                            text: "\u{f0379}"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeIconLarge
                            color: Config.accentColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(Config.padding / 3)

                            Text {
                                Layout.fillWidth: true
                                text: "Keep these display settings?"
                                elide: Text.ElideRight
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeLarge
                                font.bold: true
                                color: Config.textColor
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Going back to the previous ones in " + MonitorsService.trialRemaining + " s"
                                elide: Text.ElideRight
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeNormal
                                color: Config.subtextColor
                            }
                        }
                    }

                    // Time left, draining smoothly between the seconds
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Math.round(Config.padding / 3)
                        radius: height / 2
                        color: Config.surface1Color

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            color: Config.accentColor
                            width: parent.width * Math.max(0, MonitorsService.trialRemaining - 1) / MonitorsService.trialSeconds

                            Behavior on width {
                                NumberAnimation {
                                    duration: 1000
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Config.spacing * 2

                        KeyHint {
                            visible: window.hasKeyboard
                            keys: "Esc"
                            label: "revert"
                        }

                        KeyHint {
                            visible: window.hasKeyboard
                            keys: "Enter"
                            label: "keep"
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        ActionButton {
                            text: "Revert"
                            size: Config.fontSizeIconSmall + Config.padding * 2
                            baseColor: Config.surface1Color
                            onClicked: MonitorsService.revert("")
                        }

                        ActionButton {
                            text: "Keep"
                            size: Config.fontSizeIconSmall + Config.padding * 2
                            baseColor: Config.accentColor
                            hoverColor: Qt.lighter(Config.accentColor, 1.15)
                            textColor: Config.textReverseColor
                            onClicked: MonitorsService.keep()
                        }
                    }
                }
            }
        }
    }
}
