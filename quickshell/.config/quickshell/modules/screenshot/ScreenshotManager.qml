pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.services

Scope {
    id: root

    // =========================================================================
    // ESTADO GLOBAL
    // =========================================================================

    property bool active: false
    property string mode: "region"
    property string tempPath: ""
    property string outputPath: ""

    // Seleção atual
    property real selectionX: 0
    property real selectionY: 0
    property real selectionWidth: 0
    property real selectionHeight: 0

    // Targets para animação spring
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 0
    property real targetHeight: 0

    // Estado de preview
    property bool hasSelection: false

    // Feedback de seleção de janela
    property string selectedWindowTitle: ""
    property string selectedWindowClass: ""
    property bool isHoveringWindow: false

    // Monitor atual
    property var currentMonitor: Hyprland.focusedMonitor

    readonly property var modes: ["region", "window", "screen"]
    readonly property var modeIcons: ({
            region: "󰩭",
            window: "󰖯",
            screen: "󰍹"
        })
    readonly property var modeLabels: ({
            region: "Região",
            window: "Janela",
            screen: "Tela"
        })

    // =========================================================================
    // ANIMAÇÕES SPRING
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
    // FUNÇÕES
    // =========================================================================

    function startCapture() {
        root.mode = "region";
        root.hasSelection = false;
        root.selectionX = 0;
        root.selectionY = 0;
        root.selectionWidth = 0;
        root.selectionHeight = 0;
        root.targetX = 0;
        root.targetY = 0;
        root.targetWidth = 0;
        root.targetHeight = 0;
        root.active = true;
    }

    function cancelCapture() {
        root.active = false;
        root.hasSelection = false;
    }

    function resetSelection() {
        root.hasSelection = false;
        root.selectionX = 0;
        root.selectionY = 0;
        root.selectionWidth = 0;
        root.selectionHeight = 0;
        root.targetX = 0;
        root.targetY = 0;
        root.targetWidth = 0;
        root.targetHeight = 0;
        root.selectedWindowTitle = "";
        root.selectedWindowClass = "";
        root.isHoveringWindow = false;
    }

    function confirmSelection() {
        if (root.selectionWidth < 5 || root.selectionHeight < 5)
            return;

        const monitor = root.currentMonitor;
        if (!monitor)
            return;

        const scale = monitor.scale || 1;
        const monitorX = monitor.lastIpcObject?.x || 0;
        const monitorY = monitor.lastIpcObject?.y || 0;

        const absX = root.selectionX + monitorX;
        const absY = root.selectionY + monitorY;

        const scaledX = Math.round(absX * scale);
        const scaledY = Math.round(absY * scale);
        const scaledWidth = Math.round(root.selectionWidth * scale);
        const scaledHeight = Math.round(root.selectionHeight * scale);

        const picturesDir = Quickshell.env("XDG_PICTURES_DIR") || (Quickshell.env("HOME") + "/Pictures/Screenshots");
        const timestamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
        root.outputPath = `${picturesDir}/screenshot-${timestamp}.png`;

        screenshotProcess.command = ["sh", "-c", `mkdir -p "${picturesDir}" && ` + `grim -g "${scaledX},${scaledY} ${scaledWidth}x${scaledHeight}" "${root.outputPath}" && ` + `wl-copy < "${root.outputPath}"`];

        screenshotProcess.running = true;
    }

    function captureFullScreen() {
        const monitor = root.currentMonitor;
        if (!monitor)
            return;

        const picturesDir = Quickshell.env("XDG_PICTURES_DIR") || (Quickshell.env("HOME") + "/Pictures/Screenshots");
        const timestamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
        root.outputPath = `${picturesDir}/screenshot-${timestamp}.png`;

        screenshotProcess.command = ["sh", "-c", `mkdir -p "${picturesDir}" && ` + `grim -o "${monitor.name}" "${root.outputPath}" && ` + `wl-copy < "${root.outputPath}"`];

        screenshotProcess.running = true;
    }

    // =========================================================================
    // PROCESSOS
    // =========================================================================

    Process {
        id: screenshotProcess
        running: false

        onExited: (exitCode, exitStatus) => {
            root.active = false;
            root.hasSelection = false;

            if (exitCode === 0) {
                notifyProcess.command = ["notify-send", "-i", "accessories-screenshot", "-a", "Screenshot", "-u", "low", "Screenshot Capturado", "Salvo em " + root.outputPath.split("/").pop()];
                notifyProcess.running = true;
            }
        }
    }

    Process {
        id: notifyProcess
        running: false
    }

    // =========================================================================
    // JANELAS POR MONITOR
    // =========================================================================

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: window

            required property var modelData

            screen: modelData
            visible: root.active

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            color: "transparent"

            property var hyprMonitor: Hyprland.monitorFor(modelData)
            property bool isActiveMonitor: hyprMonitor && root.currentMonitor && hyprMonitor.name === root.currentMonitor.name

            // Workspace e janelas deste monitor
            property var workspace: hyprMonitor?.activeWorkspace
            property var windows: workspace?.toplevels ?? []

            // =========================================================================
            // TELA CONGELADA
            // =========================================================================

            ScreencopyView {
                anchors.fill: parent
                captureSource: window.screen
                z: 0
            }

            // =========================================================================
            // SHADER DE DIMMING
            // =========================================================================

            ShaderEffect {
                anchors.fill: parent
                z: 1

                property vector4d selectionRect: Qt.vector4d(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight)
                property real dimOpacity: 0.6
                property vector2d screenSize: Qt.vector2d(width, height)
                property real borderRadius: Config.radius
                property real outlineThickness: 2.0

                fragmentShader: Qt.resolvedUrl("dimming.frag.qsb")

                // Só mostra o recorte no monitor ativo
                visible: window.isActiveMonitor
            }

            // Dimming simples para monitores inativos
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.6)
                visible: !window.isActiveMonitor
                z: 1
            }

            // =========================================================================
            // GUIAS DE ALINHAMENTO (como no original)
            // =========================================================================

            Canvas {
                id: guides
                anchors.fill: parent
                z: 2
                visible: window.isActiveMonitor

                property real mouseX: mainMouse.mouseX
                property real mouseY: mainMouse.mouseY

                onMouseXChanged: requestPaint()
                onMouseYChanged: requestPaint()

                Connections {
                    target: root
                    function onSelectionXChanged() {
                        guides.requestPaint();
                    }
                    function onSelectionYChanged() {
                        guides.requestPaint();
                    }
                    function onSelectionWidthChanged() {
                        guides.requestPaint();
                    }
                    function onSelectionHeightChanged() {
                        guides.requestPaint();
                    }
                }

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    ctx.beginPath();
                    ctx.strokeStyle = "rgba(255, 255, 255, 0.5)";
                    ctx.lineWidth = 1;
                    ctx.setLineDash([5, 5]);

                    if (!mainMouse.pressed && !root.hasSelection) {
                        // Crosshair no cursor
                        ctx.moveTo(mouseX, 0);
                        ctx.lineTo(mouseX, height);
                        ctx.moveTo(0, mouseY);
                        ctx.lineTo(width, mouseY);
                    } else if (root.selectionWidth > 0 && root.selectionHeight > 0) {
                        // Guias ao redor da seleção
                        ctx.moveTo(root.selectionX, 0);
                        ctx.lineTo(root.selectionX, height);
                        ctx.moveTo(root.selectionX + root.selectionWidth, 0);
                        ctx.lineTo(root.selectionX + root.selectionWidth, height);

                        ctx.moveTo(0, root.selectionY);
                        ctx.lineTo(width, root.selectionY);
                        ctx.moveTo(0, root.selectionY + root.selectionHeight);
                        ctx.lineTo(width, root.selectionY + root.selectionHeight);
                    }

                    ctx.stroke();
                }
            }

            // =========================================================================
            // INTERAÇÃO DO MOUSE
            // =========================================================================

            MouseArea {
                id: mainMouse
                anchors.fill: parent
                z: 3
                hoverEnabled: true
                cursorShape: root.hasSelection ? Qt.ArrowCursor : Qt.CrossCursor

                property real startX: 0
                property real startY: 0

                // Timer para atualizar seleção com animação spring
                Timer {
                    id: updateTimer
                    interval: 16
                    repeat: true
                    running: mainMouse.pressed

                    onTriggered: {
                        root.selectionX = root.targetX;
                        root.selectionY = root.targetY;
                        root.selectionWidth = root.targetWidth;
                        root.selectionHeight = root.targetHeight;
                    }
                }

                onEntered: {
                    root.currentMonitor = window.hyprMonitor;
                }

                onPositionChanged: mouse => {
                    root.currentMonitor = window.hyprMonitor;

                    // Modo janela: detecta janela sob o cursor
                    if (root.mode === "window" && !root.hasSelection) {
                        checkWindowHover(mouse.x, mouse.y);
                    }

                    // Modo região: arrasta seleção
                    if (mainMouse.pressed && root.mode === "region") {
                        const x = Math.min(startX, mouse.x);
                        const y = Math.min(startY, mouse.y);
                        const w = Math.abs(mouse.x - startX);
                        const h = Math.abs(mouse.y - startY);

                        root.targetX = x;
                        root.targetY = y;
                        root.targetWidth = w;
                        root.targetHeight = h;
                    }

                    guides.requestPaint();
                }

                onPressed: mouse => {
                    if (root.hasSelection) {
                        // Clicou fora da seleção? Reseta
                        if (mouse.x < root.selectionX || mouse.x > root.selectionX + root.selectionWidth || mouse.y < root.selectionY || mouse.y > root.selectionY + root.selectionHeight) {
                            root.resetSelection();
                        }
                        return;
                    }

                    if (root.mode === "region") {
                        startX = mouse.x;
                        startY = mouse.y;
                        root.targetX = mouse.x;
                        root.targetY = mouse.y;
                        root.targetWidth = 0;
                        root.targetHeight = 0;
                    }
                }

                onReleased: mouse => {
                    if (root.mode === "region" && !root.hasSelection) {
                        if (root.selectionWidth > 10 && root.selectionHeight > 10) {
                            root.hasSelection = true;
                        }
                    } else if (root.mode === "window" && !root.hasSelection) {
                        // Clicou em uma janela
                        if (root.selectionWidth > 0 && root.selectionHeight > 0) {
                            root.hasSelection = true;
                        }
                    }
                }

                // Detecta janela sob o cursor (modo window)
                function checkWindowHover(mx: real, my: real) {
                    if (!window.hyprMonitor)
                        return;

                    const monitorX = window.hyprMonitor.lastIpcObject?.x || 0;
                    const monitorY = window.hyprMonitor.lastIpcObject?.y || 0;

                    let foundWindow = false;

                    // Itera em ordem reversa para priorizar janelas no topo (z-order)
                    for (let i = window.windows.length - 1; i >= 0; i--) {
                        const win = window.windows[i];
                        if (!win || !win.lastIpcObject)
                            continue;

                        const winX = win.lastIpcObject.at[0] - monitorX;
                        const winY = win.lastIpcObject.at[1] - monitorY;
                        const winW = win.lastIpcObject.size[0];
                        const winH = win.lastIpcObject.size[1];

                        if (mx >= winX && mx <= winX + winW && my >= winY && my <= winY + winH) {
                            root.targetX = winX;
                            root.targetY = winY;
                            root.targetWidth = winW;
                            root.targetHeight = winH;

                            root.selectionX = winX;
                            root.selectionY = winY;
                            root.selectionWidth = winW;
                            root.selectionHeight = winH;

                            // Feedback visual: título e classe da janela
                            root.selectedWindowTitle = win.lastIpcObject.title || "";
                            root.selectedWindowClass = win.lastIpcObject.class || "";
                            root.isHoveringWindow = true;
                            foundWindow = true;
                            return;
                        }
                    }

                    // Nenhuma janela encontrada sob o cursor
                    if (!foundWindow) {
                        root.isHoveringWindow = false;
                        root.selectedWindowTitle = "";
                        root.selectedWindowClass = "";
                        root.selectionX = 0;
                        root.selectionY = 0;
                        root.selectionWidth = 0;
                        root.selectionHeight = 0;
                    }
                }
            }

            // =========================================================================
            // ATALHO ESC
            // =========================================================================

            Shortcut {
                sequence: "Escape"
                onActivated: root.cancelCapture()
            }

            // =========================================================================
            // BARRA DE CONTROLE INFERIOR (z alto para ficar clicável)
            // =========================================================================

            Rectangle {
                id: controlBar
                visible: window.isActiveMonitor
                z: 10

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40

                width: controlContent.implicitWidth + 24
                height: 48

                radius: height / 2
                color: Config.surface0Color
                border.width: 1
                border.color: Config.surface2Color

                scale: root.active ? 1.0 : 0.9
                opacity: root.active ? 1.0 : 0.0

                Behavior on scale {
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutBack
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animDurationShort
                    }
                }

                // Highlight do modo selecionado
                Rectangle {
                    id: highlight
                    height: 36
                    width: 36
                    y: 6
                    radius: height / 2
                    color: Config.accentColor
                    x: 6 + (root.modes.indexOf(root.mode) * 44)

                    Behavior on x {
                        NumberAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Row {
                    id: controlContent
                    anchors.centerIn: parent
                    spacing: 8

                    // Modos
                    Repeater {
                        model: root.modes

                        delegate: Item {
                            required property string modelData
                            required property int index

                            width: 36
                            height: 36

                            Text {
                                anchors.centerIn: parent
                                text: root.modeIcons[modelData]
                                font.family: Config.font
                                font.pixelSize: 18
                                color: root.mode === modelData ? Config.textReverseColor : Config.textColor
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    root.resetSelection();
                                    root.mode = modelData;

                                    if (modelData === "screen") {
                                        root.captureFullScreen();
                                    }
                                }
                            }
                        }
                    }

                    // Separador
                    Rectangle {
                        width: 1
                        height: 24
                        color: Config.surface2Color
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Botão Confirmar (visível quando tem seleção)
                    Rectangle {
                        visible: root.hasSelection
                        width: 36
                        height: 36
                        radius: width / 2
                        color: confirmMouse.containsMouse ? Config.accentColor : Config.surface1Color

                        Text {
                            anchors.centerIn: parent
                            text: "󰄬"
                            font.family: Config.font
                            font.pixelSize: 18
                            color: confirmMouse.containsMouse ? Config.textReverseColor : Config.successColor
                        }

                        MouseArea {
                            id: confirmMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.confirmSelection()
                        }
                    }

                    // Botão Refazer (visível quando tem seleção)
                    Rectangle {
                        visible: root.hasSelection
                        width: 36
                        height: 36
                        radius: width / 2
                        color: resetMouse.containsMouse ? Config.surface2Color : Config.surface1Color

                        Text {
                            anchors.centerIn: parent
                            text: "󰑓"
                            font.family: Config.font
                            font.pixelSize: 18
                            color: Config.warningColor
                        }

                        MouseArea {
                            id: resetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetSelection()
                        }
                    }

                    // Separador antes do cancelar
                    Rectangle {
                        width: 1
                        height: 24
                        color: Config.surface2Color
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Botão cancelar
                    Item {
                        width: 36
                        height: 36

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: Config.font
                            font.pixelSize: 16
                            color: cancelMouse.containsMouse ? Config.errorColor : Config.subtextColor
                        }

                        MouseArea {
                            id: cancelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cancelCapture()
                        }
                    }
                }
            }

            // =========================================================================
            // INDICADOR DE DIMENSÕES (quando arrastando)
            // =========================================================================

            Rectangle {
                visible: window.isActiveMonitor && root.selectionWidth > 60 && root.selectionHeight > 40 && (mainMouse.pressed || root.hasSelection)
                z: 5

                x: root.selectionX + root.selectionWidth / 2 - width / 2
                y: root.selectionY + root.selectionHeight / 2 - height / 2

                width: dimText.implicitWidth + 16
                height: dimText.implicitHeight + 8
                radius: Config.radiusSmall
                color: Qt.alpha(Config.surface0Color, 0.9)

                Text {
                    id: dimText
                    anchors.centerIn: parent
                    text: Math.round(root.selectionWidth) + " × " + Math.round(root.selectionHeight)
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: Config.textColor
                }
            }

            // =========================================================================
            // INDICADOR DE JANELA SELECIONADA (modo window)
            // =========================================================================

            Rectangle {
                id: windowInfoBadge
                visible: window.isActiveMonitor && root.mode === "window" && root.isHoveringWindow && root.selectedWindowTitle !== ""
                z: 6

                x: root.selectionX + 12
                y: root.selectionY + 12

                width: windowInfoContent.implicitWidth + 20
                height: 36
                radius: Config.radius
                color: Qt.alpha(Config.surface0Color, 0.95)
                border.width: 2
                border.color: Config.accentColor

                // Animação de entrada
                scale: visible ? 1.0 : 0.8
                opacity: visible ? 1.0 : 0.0

                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutBack
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                    }
                }

                Row {
                    id: windowInfoContent
                    anchors.centerIn: parent
                    spacing: 10

                    // Ícone da janela
                    Text {
                        text: "󰖯"
                        font.family: Config.font
                        font.pixelSize: 16
                        color: Config.accentColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Título da janela
                    Text {
                        text: root.selectedWindowTitle
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        font.bold: true
                        color: Config.textColor
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 250)
                    }

                    // Separador (se tiver classe)
                    Rectangle {
                        visible: root.selectedWindowClass !== "" && root.selectedWindowClass !== root.selectedWindowTitle
                        width: 1
                        height: 16
                        color: Config.surface2Color
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Classe da janela
                    Text {
                        visible: root.selectedWindowClass !== "" && root.selectedWindowClass !== root.selectedWindowTitle
                        text: root.selectedWindowClass
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // =========================================================================
            // DICA DE USO
            // =========================================================================

            Rectangle {
                visible: window.isActiveMonitor && !root.hasSelection && root.mode !== "screen"
                z: 10

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 20
                anchors.bottomMargin: 40

                width: hintContent.implicitWidth + 16
                height: 32
                radius: Config.radius
                color: Qt.alpha(Config.surface0Color, 0.9)

                Row {
                    id: hintContent
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        width: escText.implicitWidth + 8
                        height: escText.implicitHeight + 4
                        radius: 4
                        color: Config.surface1Color
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: escText
                            anchors.centerIn: parent
                            text: "ESC"
                            font.family: Config.font
                            font.pixelSize: Config.fontSizeSmall
                            font.bold: true
                            color: Config.subtextColor
                        }
                    }

                    Text {
                        text: root.mode === "region" ? "Arraste para selecionar" : "Clique em uma janela"
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.subtextColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
