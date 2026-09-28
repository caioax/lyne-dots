pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import "../../../services/ThemeGenerator.js" as ThemeGenerator

// Visual OKLCH color picker: a chroma × lightness plane at the current hue,
// a hue strip below and a preview. Parts of the plane outside sRGB are faded
// and the knob stops at their edge. `lch` is { l, c, h }; dragging emits
// picked() and leaves `lch` to the owner
ColumnLayout {
    id: root

    property var lch: ({
            l: 0.7,
            c: 0.1,
            h: 250
        })
    // Chroma at the plane's right edge (sRGB tops out around 0.32)
    readonly property real maxC: 0.33
    readonly property string hex: ThemeGenerator.oklch(lch.l, lch.c, lch.h)
    readonly property int stripHeight: Config.fontSizeIconSmall
    readonly property int knobSize: Config.fontSizeIconSmall

    // Chroma picked on the plane: moving the hue keeps it where sRGB allows,
    // instead of losing it for good at hues with a narrower gamut
    property real wantedC: lch.c

    onLchChanged: {
        if (!planeMouse.pressed && !hueMouse.pressed)
            wantedC = lch.c;
    }

    signal picked(real l, real c, real h)

    function pickPlane(x: real, y: real) {
        const l = Math.min(1, Math.max(0, 1 - y / plane.height));
        const c = Math.min(root.maxC, Math.max(0, x / plane.width * root.maxC));
        wantedC = c;
        root.picked(l, Math.min(c, ThemeGenerator.maxChroma(l, lch.h, c)), lch.h);
    }

    function pickHue(x: real) {
        const h = Math.min(360, Math.max(0, x / strip.width * 360));
        root.picked(lch.l, Math.min(wantedC, ThemeGenerator.maxChroma(lch.l, h, wantedC)), h);
    }

    spacing: Config.spacing

    RowLayout {
        Layout.fillWidth: true
        spacing: Config.spacing

        // ================= PLANE =================
        ShaderEffect {
            id: plane

            readonly property color outColor: Config.surface1Color
            readonly property size size: Qt.size(width, height)
            readonly property real mode: 0
            readonly property real hue: root.lch.h
            readonly property real lightness: root.lch.l
            readonly property real chroma: root.lch.c
            readonly property real maxChroma: root.maxC
            readonly property real radius: Config.radius

            Layout.fillWidth: true
            Layout.preferredHeight: Config.fontSizeNormal * 10
            fragmentShader: Qt.resolvedUrl("oklch.frag.qsb")

            Knob {
                x: Math.min(root.lch.c / root.maxC, 1) * plane.width - width / 2
                y: (1 - root.lch.l) * plane.height - height / 2
                color: root.hex
            }

            MouseArea {
                id: planeMouse
                anchors.fill: parent
                // Dragging inside the Settings page mustn't scroll it
                preventStealing: true
                cursorShape: Qt.CrossCursor
                onPressed: mouse => root.pickPlane(mouse.x, mouse.y)
                onPositionChanged: mouse => root.pickPlane(mouse.x, mouse.y)
            }
        }

        // ================= PREVIEW =================
        Rectangle {
            id: preview

            readonly property color ink: ThemeGenerator.contrast(root.hex, "#000000") > 7 ? "#000000" : "#ffffff"

            Layout.preferredWidth: Config.fontSizeNormal * 6
            Layout.fillHeight: true
            radius: Config.radius
            color: root.hex
            border.width: 1
            border.color: Qt.alpha(Config.textColor, 0.2)

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Config.padding * 1.5
                spacing: Math.round(Config.padding / 3)

                Text {
                    text: root.hex
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: preview.ink
                }

                Repeater {
                    model: [["L", Math.round(root.lch.l * 100) + "%"], ["C", root.lch.c.toFixed(3)], ["H", Math.round(root.lch.h) + "°"]]

                    Text {
                        required property var modelData
                        text: modelData[0] + " " + modelData[1]
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Qt.alpha(preview.ink, 0.75)
                    }
                }
            }
        }
    }

    // ================= HUE =================
    ShaderEffect {
        id: strip

        readonly property color outColor: Config.surface1Color
        readonly property size size: Qt.size(width, height)
        readonly property real mode: 1
        readonly property real hue: root.lch.h
        // Readable at any pick: grey or very dark colors still show the hues
        readonly property real lightness: Math.min(0.85, Math.max(0.5, root.lch.l))
        readonly property real chroma: 0.13
        readonly property real maxChroma: root.maxC
        readonly property real radius: height / 2

        Layout.fillWidth: true
        Layout.preferredHeight: root.stripHeight
        fragmentShader: Qt.resolvedUrl("oklch.frag.qsb")

        Knob {
            x: root.lch.h / 360 * strip.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: ThemeGenerator.oklch(strip.lightness, strip.chroma, root.lch.h)
        }

        MouseArea {
            id: hueMouse
            anchors.fill: parent
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => root.pickHue(mouse.x)
            onPositionChanged: mouse => root.pickHue(mouse.x)
        }
    }

    // Ring in the picked color, readable over light and dark parts
    component Knob: Rectangle {
        width: root.knobSize
        height: width
        radius: width / 2
        border.width: 2
        border.color: "#ffffff"

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.5)
        }
    }
}
