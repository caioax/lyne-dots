pragma ComponentBehavior: Bound
import QtQuick
import qs.config

Item {
    id: root

    signal regionSelected(real x, real y, real width, real height)

    // =========================================================================
    // PROPRIEDADES DO SHADER (usando Config para padronização)
    // =========================================================================

    property real dimOpacity: 0.6
    property real borderRadius: Config.radius
    property real outlineThickness: 2.0
    property url fragmentShader: Qt.resolvedUrl("dimming.frag.qsb")

    // =========================================================================
    // ESTADO DA SELEÇÃO
    // =========================================================================

    property point startPos

    // Geometria do retângulo de seleção
    property real selectionX: 0
    property real selectionY: 0
    property real selectionWidth: 0
    property real selectionHeight: 0

    // Alvos para animação
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 0
    property real targetHeight: 0

    // Posição do mouse para crosshair
    property real mouseX: 0
    property real mouseY: 0

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

    // Redesenha guias quando algo muda
    onSelectionXChanged: guides.requestPaint()
    onSelectionYChanged: guides.requestPaint()
    onSelectionWidthChanged: guides.requestPaint()
    onSelectionHeightChanged: guides.requestPaint()
    onMouseXChanged: guides.requestPaint()
    onMouseYChanged: guides.requestPaint()

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
    // GUIAS DE ALINHAMENTO (Canvas)
    // =========================================================================

    Canvas {
        id: guides
        anchors.fill: parent
        z: 2

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            ctx.beginPath();
            ctx.strokeStyle = Qt.rgba(Config.accentColor.r, Config.accentColor.g, Config.accentColor.b, 0.6);
            ctx.lineWidth = 1;
            ctx.setLineDash([5, 5]);

            if (!mouseArea.pressed) {
                // MODO 1: Crosshair no cursor (antes de clicar)
                ctx.moveTo(root.mouseX, 0);
                ctx.lineTo(root.mouseX, root.height);
                ctx.moveTo(0, root.mouseY);
                ctx.lineTo(root.width, root.mouseY);
            } else {
                // MODO 2: Guias ao redor da seleção (enquanto arrasta)
                // Verticais
                ctx.moveTo(root.selectionX, 0);
                ctx.lineTo(root.selectionX, root.height);
                ctx.moveTo(root.selectionX + root.selectionWidth, 0);
                ctx.lineTo(root.selectionX + root.selectionWidth, root.height);

                // Horizontais
                ctx.moveTo(0, root.selectionY);
                ctx.lineTo(root.width, root.selectionY);
                ctx.moveTo(0, root.selectionY + root.selectionHeight);
                ctx.lineTo(root.width, root.selectionY + root.selectionHeight);
            }

            ctx.stroke();
        }
    }

    // =========================================================================
    // DIMENSÕES DA SELEÇÃO (exibidas durante arrasto)
    // =========================================================================

    Rectangle {
        visible: mouseArea.pressed && root.selectionWidth > 50 && root.selectionHeight > 30

        x: root.selectionX + root.selectionWidth / 2 - width / 2
        y: root.selectionY + root.selectionHeight / 2 - height / 2

        width: dimensionText.implicitWidth + 16
        height: dimensionText.implicitHeight + 8

        radius: Config.radiusSmall
        color: Qt.alpha(Config.surface0Color, 0.9)

        Text {
            id: dimensionText
            anchors.centerIn: parent
            text: Math.round(root.selectionWidth) + " × " + Math.round(root.selectionHeight)
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.textColor
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
        cursorShape: Qt.CrossCursor

        Timer {
            id: updateTimer
            interval: 16
            repeat: true
            running: mouseArea.pressed
            onTriggered: {
                root.selectionX = root.targetX;
                root.selectionY = root.targetY;
                root.selectionWidth = root.targetWidth;
                root.selectionHeight = root.targetHeight;
            }
        }

        onPressed: mouse => {
            root.startPos = Qt.point(mouse.x, mouse.y);
            root.targetX = mouse.x;
            root.targetY = mouse.y;
            root.targetWidth = 0;
            root.targetHeight = 0;
            guides.requestPaint();
        }

        onPositionChanged: mouse => {
            // Sempre atualiza posição do mouse para crosshair
            root.mouseX = mouse.x;
            root.mouseY = mouse.y;

            if (pressed) {
                const x = Math.min(root.startPos.x, mouse.x);
                const y = Math.min(root.startPos.y, mouse.y);
                const w = Math.abs(mouse.x - root.startPos.x);
                const h = Math.abs(mouse.y - root.startPos.y);

                root.targetX = x;
                root.targetY = y;
                root.targetWidth = w;
                root.targetHeight = h;
            }
        }

        onReleased: {
            // Só emite se tiver selecionado uma área válida
            if (root.selectionWidth > 5 && root.selectionHeight > 5) {
                root.regionSelected(Math.round(root.selectionX), Math.round(root.selectionY), Math.round(root.selectionWidth), Math.round(root.selectionHeight));
            }
        }
    }
}
