pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.config

Item {
    id: root

    property var monitor: Hyprland.focusedMonitor
    property var workspace: monitor?.activeWorkspace
    property var windows: workspace?.toplevels ?? []

    signal checkHover(real mouseX, real mouseY)
    signal regionSelected(real x, real y, real width, real height)

    // =========================================================================
    // PROPRIEDADES DO SHADER (usando Config)
    // =========================================================================

    property real dimOpacity: 0.6
    property real borderRadius: Config.radius
    property real outlineThickness: 2.0
    property url fragmentShader: Qt.resolvedUrl("dimming.frag.qsb")

    // =========================================================================
    // ESTADO DA SELEÇÃO
    // =========================================================================

    property point startPos
    property real selectionX: 0
    property real selectionY: 0
    property real selectionWidth: 0
    property real selectionHeight: 0

    // Nome da janela selecionada
    property string selectedWindowTitle: ""

    // =========================================================================
    // ANIMAÇÕES
    // =========================================================================

    Behavior on selectionX {
        SpringAnimation {
            spring: 4
            damping: 0.4
        }
    }
    Behavior on selectionY {
        SpringAnimation {
            spring: 4
            damping: 0.4
        }
    }
    Behavior on selectionWidth {
        SpringAnimation {
            spring: 4
            damping: 0.4
        }
    }
    Behavior on selectionHeight {
        SpringAnimation {
            spring: 4
            damping: 0.4
        }
    }

    // =========================================================================
    // SHADER DE DIMMING
    // =========================================================================

    ShaderEffect {
        anchors.fill: parent
        z: 0

        property vector4d selectionRect: Qt.vector4d(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight)
        property real dimOpacity: root.dimOpacity
        property vector2d screenSize: Qt.vector2d(root.width, root.height)
        property real borderRadius: root.borderRadius
        property real outlineThickness: root.outlineThickness

        fragmentShader: root.fragmentShader
    }

    // =========================================================================
    // INDICADOR DE JANELA SELECIONADA
    // =========================================================================

    Rectangle {
        visible: root.selectionWidth > 0 && root.selectedWindowTitle !== ""

        x: root.selectionX + 8
        y: root.selectionY + 8

        width: windowTitleRow.implicitWidth + 16
        height: 28

        radius: Config.radiusSmall
        color: Qt.alpha(Config.surface0Color, 0.95)

        border.width: 1
        border.color: Config.accentColor

        RowLayout {
            id: windowTitleRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: "󰖯"
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: Config.accentColor
            }

            Text {
                text: root.selectedWindowTitle
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.textColor

                // Limita largura do texto
                Layout.maximumWidth: 200
                elide: Text.ElideRight
            }
        }
    }

    // =========================================================================
    // DETECTORES DE JANELAS
    // =========================================================================

    Repeater {
        model: root.windows

        Item {
            required property var modelData

            Connections {
                target: root

                function onCheckHover(mouseX, mouseY) {
                    const monitorX = root.monitor.lastIpcObject.x;
                    const monitorY = root.monitor.lastIpcObject.y;

                    const windowX = modelData.lastIpcObject.at[0] - monitorX;
                    const windowY = modelData.lastIpcObject.at[1] - monitorY;

                    const width = modelData.lastIpcObject.size[0];
                    const height = modelData.lastIpcObject.size[1];

                    // Verifica se o mouse está dentro desta janela
                    if (mouseX >= windowX && mouseX <= windowX + width && mouseY >= windowY && mouseY <= windowY + height) {
                        root.selectionX = windowX;
                        root.selectionY = windowY;
                        root.selectionWidth = width;
                        root.selectionHeight = height;
                        root.selectedWindowTitle = modelData.lastIpcObject.title || modelData.lastIpcObject.class || "Janela";
                    }
                }
            }
        }
    }

    // =========================================================================
    // INTERAÇÃO DO MOUSE
    // =========================================================================

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        z: 3
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPositionChanged: mouse => {
            root.checkHover(mouse.x, mouse.y);
        }

        onReleased: mouse => {
            // Verifica se clicou dentro da seleção atual
            if (mouse.x >= root.selectionX && mouse.x <= root.selectionX + root.selectionWidth && mouse.y >= root.selectionY && mouse.y <= root.selectionY + root.selectionHeight && root.selectionWidth > 0) {
                root.regionSelected(Math.round(root.selectionX), Math.round(root.selectionY), Math.round(root.selectionWidth), Math.round(root.selectionHeight));
            }
        }
    }

    // =========================================================================
    // DICA: CLIQUE PARA CAPTURAR
    // =========================================================================

    Rectangle {
        visible: root.selectionWidth > 100 && root.selectionHeight > 60

        anchors.centerIn: parent

        width: clickHintText.implicitWidth + 20
        height: clickHintText.implicitHeight + 10

        radius: Config.radius
        color: Qt.alpha(Config.accentColor, 0.9)

        Text {
            id: clickHintText
            anchors.centerIn: parent
            text: "Clique para capturar"
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            font.bold: true
            color: Config.textReverseColor
        }
    }
}
