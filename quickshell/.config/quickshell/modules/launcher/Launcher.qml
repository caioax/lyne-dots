pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.config

PanelWindow {
    id: root

    visible: LauncherService.visible

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    color: "transparent"

    // Clique no fundo fecha
    MouseArea {
        anchors.fill: parent
        onClicked: LauncherService.hide()
    }

    // Loader que cria/destrói o conteúdo
    Loader {
        id: contentLoader
        anchors.centerIn: parent
        active: LauncherService.visible

        sourceComponent: Rectangle {
            id: content
            width: 520

            // Altura dinâmica baseada no conteúdo
            property int listHeight: Math.min(420, appList.contentHeight + 12)
            property int totalHeight: listHeight + searchBar.height + 32

            height: totalHeight
            radius: Config.radiusLarge
            color: Config.backgroundColor
            border.color: Qt.alpha(Config.accentColor, 0.2)
            border.width: 1

            // Animação de escala na entrada
            scale: 1
            opacity: 1

            // Animação de altura suave
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

                // Barra de busca
                Rectangle {
                    id: searchBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
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
                            font.pixelSize: Config.fontSizeLarge
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            placeholderText: "Buscar aplicativos..."
                            placeholderTextColor: Config.mutedColor

                            // Remove o background padrão do TextField
                            background: null

                            onTextChanged: LauncherService.query = text

                            Keys.onEscapePressed: LauncherService.hide()
                            Keys.onReturnPressed: LauncherService.launchSelected()
                            Keys.onUpPressed: {
                                if (LauncherService.selectedIndex > 0)
                                    LauncherService.selectedIndex--;
                            }
                            Keys.onDownPressed: {
                                if (LauncherService.selectedIndex < LauncherService.filteredApps.length - 1)
                                    LauncherService.selectedIndex++;
                            }
                            Keys.onTabPressed: event => {
                                if (LauncherService.selectedIndex < LauncherService.filteredApps.length - 1)
                                    LauncherService.selectedIndex++;
                                event.accepted = true;
                            }

                            Keys.onPressed: event => {
                                // Shift+Tab para voltar
                                if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                                    if (LauncherService.selectedIndex > 0)
                                        LauncherService.selectedIndex--;
                                    event.accepted = true;
                                }
                            }

                            // Foco automático ao ser criado
                            Component.onCompleted: {
                                LauncherService.query = "";
                                LauncherService.selectedIndex = 0;
                                Qt.callLater(forceActiveFocus);
                            }
                        }

                        // Contador de resultados
                        Rectangle {
                            visible: LauncherService.filteredApps.length > 0
                            Layout.preferredWidth: countText.implicitWidth + 12
                            Layout.preferredHeight: 22
                            radius: height / 2
                            color: Config.surface1Color

                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: LauncherService.filteredApps.length
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.subtextColor
                            }
                        }

                        // Botão limpar
                        Rectangle {
                            visible: searchInput.text
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: height / 2
                            color: clearMouse.containsMouse ? Config.surface2Color : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animDurationShort
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.subtextColor
                            }

                            MouseArea {
                                id: clearMouse
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

                // Separador
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Config.surface1Color
                }

                // Lista de apps
                ListView {
                    id: appList
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    clip: true
                    spacing: 4
                    model: LauncherService.filteredApps
                    currentIndex: LauncherService.selectedIndex

                    // Animações de adicionar/remover items
                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Config.animDurationShort
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 0.8
                            to: 1
                            duration: Config.animDurationShort
                            easing.type: Easing.OutBack
                        }
                    }

                    remove: Transition {
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: Config.animDurationShort
                        }
                        NumberAnimation {
                            property: "scale"
                            to: 0.8
                            duration: Config.animDurationShort
                        }
                    }

                    displaced: Transition {
                        NumberAnimation {
                            property: "y"
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Highlight customizado
                    highlightFollowsCurrentItem: false
                    highlight: Rectangle {
                        width: appList.width
                        height: 56
                        radius: Config.radius
                        color: Config.surface2Color

                        y: appList.currentItem ? appList.currentItem.y : 0

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

                        width: appList.width
                        height: 56

                        property bool isSelected: index === LauncherService.selectedIndex
                        property bool isHovered: delegateMouse.containsMouse

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            // Ícone com background
                            Rectangle {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                radius: Config.radiusSmall
                                color: Config.surface0Color

                                Image {
                                    anchors.centerIn: parent
                                    width: 32
                                    height: 32
                                    source: {
                                        const icon = delegateItem.modelData?.icon ?? "";
                                        return icon ? "image://icon/" + icon : "image://icon/application-x-executable";
                                    }
                                    sourceSize: Qt.size(32, 32)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }
                            }

                            // Textos
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: delegateItem.modelData?.name ?? ""
                                    color: delegateItem.isSelected ? Config.textColor : Config.textColor
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeNormal
                                    font.weight: delegateItem.isSelected ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: delegateItem.modelData?.comment || delegateItem.modelData?.genericName || ""
                                    color: Config.subtextColor
                                    font.family: Config.font
                                    font.pixelSize: Config.fontSizeSmall
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }
                            }

                            // Indicador de seleção
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
                            onClicked: {
                                if (delegateItem.isSelected) {
                                    // Segundo clique: abre o app
                                    LauncherService.launch(delegateItem.modelData);
                                } else {
                                    // Primeiro clique: seleciona
                                    LauncherService.selectedIndex = delegateItem.index;
                                }
                            }
                        }
                    }

                    // Estado vazio
                    Column {
                        anchors.centerIn: parent
                        spacing: Config.spacing
                        visible: appList.count === 0
                        opacity: visible ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Config.animDurationShort
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: LauncherService.query ? "󰅖" : "󰑓"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeIconLarge
                            color: Config.mutedColor

                            RotationAnimator on rotation {
                                from: 0
                                to: 360
                                duration: 1000
                                loops: Animation.Infinite
                                running: !LauncherService.query && appList.count === 0
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: LauncherService.query ? "Nenhum resultado" : "Carregando..."
                            color: Config.subtextColor
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeNormal
                        }
                    }

                    // Auto-scroll ao navegar (sem animação para não afetar mouse)
                    onCurrentIndexChanged: {
                        positionViewAtIndex(currentIndex, ListView.Contain);
                    }

                    // Scroll suave
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
        onCleared: LauncherService.hide()
    }
}
