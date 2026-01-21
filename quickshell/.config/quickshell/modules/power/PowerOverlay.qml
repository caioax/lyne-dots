pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: window

            required property var modelData
            screen: modelData

            visible: PowerService.overlayVisible

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusiveZone: -1

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 100

            color: "transparent"

            // Área invisível para fechar ao clicar fora
            MouseArea {
                anchors.fill: parent
                onClicked: PowerService.hideOverlay()
            }

            // Widget flutuante minimalista
            Rectangle {
                id: powerWidget

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 15

                width: powerRow.implicitWidth + 32
                height: 52

                radius: height / 2
                color: Config.surface0Color

                border.width: 1
                border.color: Config.surface2Color

                // Animação de entrada
                property bool showState: PowerService.overlayVisible

                scale: showState ? 1.0 : 0.8
                opacity: showState ? 1.0 : 0.0

                Behavior on scale {
                    NumberAnimation {
                        duration: Config.animDurationLong
                        easing.type: Easing.OutBack
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animDuration
                    }
                }

                // Conteúdo
                RowLayout {
                    id: powerRow
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: [
                            { id: "lock", icon: "󰌾", color: Config.accentColor, tooltip: "Bloquear" },
                            { id: "logout", icon: "󰍃", color: Config.subtextColor, tooltip: "Sair" },
                            { id: "suspend", icon: "󰒲", color: Config.subtextColor, tooltip: "Suspender" },
                            { id: "reboot", icon: "󰜉", color: Config.warningColor, tooltip: "Reiniciar" },
                            { id: "shutdown", icon: "󰐥", color: Config.errorColor, tooltip: "Desligar" }
                        ]

                        delegate: Rectangle {
                            id: actionBtn

                            required property var modelData
                            required property int index

                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40

                            radius: width / 2

                            color: {
                                if (btnMouse.pressed)
                                    return Qt.alpha(modelData.color, 0.3);
                                if (btnMouse.containsMouse)
                                    return Qt.alpha(modelData.color, 0.15);
                                return "transparent";
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDurationShort
                                }
                            }

                            scale: btnMouse.pressed ? 0.9 : 1.0
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Config.animDurationShort
                                }
                            }

                            // Ícone
                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.family: Config.font
                                font.pixelSize: 20
                                color: btnMouse.containsMouse ? modelData.color : Config.textColor

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Config.animDurationShort
                                    }
                                }
                            }

                            // Tooltip
                            Rectangle {
                                visible: btnMouse.containsMouse
                                anchors.top: parent.bottom
                                anchors.topMargin: 6
                                anchors.horizontalCenter: parent.horizontalCenter

                                width: tooltipText.implicitWidth + 10
                                height: tooltipText.implicitHeight + 4
                                radius: Config.radiusSmall
                                color: Config.surface1Color

                                Text {
                                    id: tooltipText
                                    anchors.centerIn: parent
                                    text: modelData.tooltip
                                    font.family: Config.font
                                    font.pixelSize: 11
                                    color: Config.subtextColor
                                }
                            }

                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    PowerService.executeAction(modelData.id);
                                }
                            }
                        }
                    }

                    // Separador
                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 24
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        color: Config.surface2Color
                    }

                    // Botão fechar
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32

                        radius: width / 2
                        color: closeMouse.containsMouse ? Config.surface1Color : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: Config.font
                            font.pixelSize: 16
                            color: closeMouse.containsMouse ? Config.textColor : Config.subtextColor
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PowerService.hideOverlay()
                        }
                    }
                }

                focus: PowerService.overlayVisible

                Keys.onEscapePressed: PowerService.hideOverlay()

                Keys.onPressed: event => {
                    const actions = ["lock", "logout", "suspend", "reboot", "shutdown"];
                    if (event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
                        const index = event.key - Qt.Key_1;
                        PowerService.executeAction(actions[index]);
                    }
                }
            }

            onVisibleChanged: {
                if (visible) {
                    powerWidget.forceActiveFocus();
                }
            }
        }
    }
}
