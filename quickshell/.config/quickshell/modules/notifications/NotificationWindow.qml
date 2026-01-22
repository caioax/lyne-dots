pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services

PopupWindow {
    id: root

    // Configurações de tamanho
    readonly property int contentWidth: 400
    readonly property int contentHeight: 600
    readonly property int screenMargin: 15

    implicitWidth: contentWidth + (screenMargin * 2)
    implicitHeight: contentHeight
    color: "transparent"

    property bool isClosing: false
    property bool isOpening: false

    function closeWindow() {
        if (!visible)
            return;
        isClosing = true;
        closeTimer.restart();
    }

    Timer {
        id: closeTimer
        interval: Config.animDuration
        onTriggered: {
            root.visible = false;
            isClosing = false;
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [root]
        active: false
        onCleared: root.closeWindow()
    }

    Timer {
        id: grabTimer
        interval: 10
        onTriggered: {
            focusGrab.active = true;
            background.forceActiveFocus();
        }
    }

    onVisibleChanged: {
        if (visible) {
            isClosing = false;
            isOpening = true;
            WindowManagerService.registerOpen("NotificationWindow");
            grabTimer.restart();
        } else {
            focusGrab.active = false;
            isOpening = false;
            WindowManagerService.registerClose("NotificationWindow");
        }
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: background
            width: root.contentWidth
            height: root.contentHeight
            anchors.centerIn: parent
            color: Config.backgroundColor
            radius: Config.radiusLarge
            clip: true

            transformOrigin: Item.TopRight

            property bool showState: visible && !isClosing && isOpening

            scale: showState ? 1.0 : 0.9
            opacity: showState ? 1.0 : 0.0

            Behavior on scale {
                NumberAnimation {
                    duration: Config.animDurationLong
                    easing.type: Easing.OutExpo
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.animDurationShort
                }
            }

            Keys.onEscapePressed: root.closeWindow()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // ========== HEADER ==========
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Ícone decorativo
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: Config.radius
                        color: NotificationService.dndEnabled ? Qt.alpha(Config.warningColor, 0.2) : Config.surface1Color

                        Text {
                            anchors.centerIn: parent
                            text: NotificationService.dndEnabled ? "󰂛" : "󰂚"
                            font.family: Config.font
                            font.pixelSize: 20
                            color: NotificationService.dndEnabled ? Config.warningColor : Config.accentColor
                        }
                    }

                    // Título e contador
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Notificações"
                            font.family: Config.font
                            font.bold: true
                            font.pixelSize: Config.fontSizeLarge
                            color: Config.textColor
                        }

                        Text {
                            visible: NotificationService.count > 0 || NotificationService.dndEnabled
                            text: {
                                if (NotificationService.dndEnabled)
                                    return "Não perturbe ativo";
                                return NotificationService.count + (NotificationService.count === 1 ? " notificação" : " notificações");
                            }
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: NotificationService.dndEnabled ? Config.warningColor : Config.subtextColor
                        }
                    }

                    // Espaçador
                    Item {
                        Layout.fillWidth: true
                    }

                    // Botão DND Toggle
                    Rectangle {
                        id: dndBtn
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: dndContent.implicitWidth + 16
                        radius: Config.radius
                        color: {
                            if (NotificationService.dndEnabled)
                                return Config.warningColor;
                            if (dndMouse.containsMouse)
                                return Config.surface2Color;
                            return Config.surface1Color;
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animDurationShort
                            }
                        }

                        RowLayout {
                            id: dndContent
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: NotificationService.dndEnabled ? "󰂛" : "󰂚"
                                font.family: Config.font
                                font.pixelSize: 14
                                color: NotificationService.dndEnabled ? Config.textReverseColor : Config.subtextColor
                            }

                            Text {
                                text: "DND"
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                font.bold: true
                                color: NotificationService.dndEnabled ? Config.textReverseColor : Config.subtextColor
                            }
                        }

                        MouseArea {
                            id: dndMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.toggleDnd()
                        }
                    }

                    // Botão Limpar Tudo
                    Rectangle {
                        id: clearAllBtn
                        visible: NotificationService.count > 0
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: clearAllContent.implicitWidth + 20
                        radius: Config.radius
                        color: clearAllMouse.containsMouse ? Qt.alpha(Config.errorColor, 0.15) : Config.surface1Color

                        RowLayout {
                            id: clearAllContent
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "󰆴"
                                font.family: Config.font
                                font.pixelSize: 14
                                color: clearAllMouse.containsMouse ? Config.errorColor : Config.subtextColor
                            }

                            Text {
                                text: "Limpar"
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                font.bold: true
                                color: clearAllMouse.containsMouse ? Config.errorColor : Config.subtextColor
                            }
                        }

                        MouseArea {
                            id: clearAllMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.clearAll()
                        }
                    }
                }

                // ========== SEPARADOR ==========
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Config.surface1Color
                }

                // ========== LISTA DE NOTIFICAÇÕES ==========
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: listView
                        anchors.fill: parent
                        clip: true
                        spacing: 10
                        visible: NotificationService.count > 0

                        model: NotificationService.notifications

                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Config.animDuration
                            }
                            NumberAnimation {
                                property: "x"
                                from: 30
                                to: 0
                                duration: Config.animDuration
                                easing.type: Easing.OutQuad
                            }
                        }

                        remove: Transition {
                            NumberAnimation {
                                property: "opacity"
                                to: 0
                                duration: Config.animDurationShort
                            }
                        }

                        displaced: Transition {
                            NumberAnimation {
                                properties: "y"
                                duration: Config.animDuration
                                easing.type: Easing.OutQuad
                            }
                        }

                        delegate: NotificationCard {
                            required property var modelData

                            wrapper: modelData
                            popupMode: false
                            width: listView.width
                        }

                        ScrollBar.vertical: ScrollBar {
                            active: listView.moving || listView.contentHeight > listView.height
                            policy: ScrollBar.AsNeeded

                            contentItem: Rectangle {
                                implicitWidth: 4
                                implicitHeight: 100
                                radius: 2
                                color: Config.surface2Color
                                opacity: parent.active ? 0.8 : 0
                            }

                            background: Rectangle {
                                implicitWidth: 4
                                color: "transparent"
                            }
                        }
                    }

                    // Estado vazio
                    Column {
                        anchors.centerIn: parent
                        spacing: 12
                        visible: NotificationService.count === 0

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 64
                            height: 64
                            radius: 32
                            color: NotificationService.dndEnabled ? Qt.alpha(Config.warningColor, 0.2) : Config.surface1Color

                            Text {
                                anchors.centerIn: parent
                                text: NotificationService.dndEnabled ? "󰂛" : "󰂜"
                                font.family: Config.font
                                font.pixelSize: 28
                                color: NotificationService.dndEnabled ? Config.warningColor : Config.subtextColor
                                opacity: NotificationService.dndEnabled ? 1.0 : 0.5
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: NotificationService.dndEnabled ? "Modo Não Perturbe" : "Nenhuma notificação"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                            color: NotificationService.dndEnabled ? Config.warningColor : Config.subtextColor
                            opacity: 0.7
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: NotificationService.dndEnabled ? "Notificações silenciadas" : "Você está em dia!"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.subtextColor
                            opacity: 0.5
                        }
                    }
                }
            }
        }
    }
}
