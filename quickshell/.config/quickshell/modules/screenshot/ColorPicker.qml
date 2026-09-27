pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.config

// Color mode: a round lens next to the cursor with the pixels around the
// picked one, magnified on a grid, and a chip with the color under it.
// Everything is read from the frozen image, so it is the captured color
Item {
    id: root

    required property var screenshot
    // The frozen Image of this monitor, and its file for reading pixels
    required property Item frozen
    required property string source

    readonly property int cells: 11
    readonly property int cellSize: Config.padding * 2
    readonly property int lensSize: cells * cellSize
    readonly property real px: screenshot.pickX
    readonly property real py: screenshot.pickY
    readonly property color picked: screenshot.pickedColor
    // Theme text color that stands out on the picked color
    readonly property color contrast: {
        const lum = 0.2126 * picked.r + 0.7152 * picked.g + 0.0722 * picked.b;
        const text = Config.textColor;
        const textLum = 0.2126 * text.r + 0.7152 * text.g + 0.0722 * text.b;
        return Math.abs(textLum - lum) > 0.4 ? Config.textColor : Config.textReverseColor;
    }

    // Beside the cursor, flipped away from the screen edges
    readonly property real gap: Config.spacing * 3
    readonly property bool flipX: px + gap + lensSize > width
    readonly property bool flipY: py + gap + lensSize + chip.height + Config.padding > height

    Item {
        id: lens

        visible: root.px >= 0
        x: root.flipX ? root.px - root.gap - width : root.px + root.gap
        y: root.flipY ? root.py - root.gap - height - chip.height - Config.padding : root.py + root.gap
        width: root.lensSize
        height: root.lensSize

        ClippingRectangle {
            anchors.fill: parent
            radius: width / 2
            color: Config.scrimColor

            // Pixels around the picked one, blown up without smoothing
            ShaderEffectSource {
                anchors.fill: parent
                sourceItem: root.frozen
                sourceRect: Qt.rect(root.px - Math.floor(root.cells / 2), root.py - Math.floor(root.cells / 2), root.cells, root.cells)
                smooth: false
            }

            // Pixel grid
            Repeater {
                model: root.cells - 1

                Rectangle {
                    required property int index
                    x: (index + 1) * root.cellSize
                    width: 1
                    height: root.lensSize
                    color: Qt.alpha(Config.scrimColor, 0.2)
                }
            }
            Repeater {
                model: root.cells - 1

                Rectangle {
                    required property int index
                    y: (index + 1) * root.cellSize
                    width: root.lensSize
                    height: 1
                    color: Qt.alpha(Config.scrimColor, 0.2)
                }
            }

            // The picked pixel
            Rectangle {
                x: Math.floor(root.cells / 2) * root.cellSize - border.width
                y: x
                width: root.cellSize + border.width * 2
                height: width
                color: Qt.alpha(root.contrast, 0)
                border.width: 2
                border.color: root.contrast
            }
        }

        // Ring in the picked color
        Rectangle {
            anchors.fill: parent
            anchors.margins: -border.width
            radius: width / 2
            color: Qt.alpha(root.picked, 0)
            border.width: Config.padding / 2
            border.color: root.picked
        }
    }

    // Swatch + value
    Rectangle {
        id: chip

        visible: lens.visible
        anchors.horizontalCenter: lens.horizontalCenter
        anchors.top: lens.bottom
        anchors.topMargin: Config.padding * 1.5
        width: chipRow.implicitWidth + Config.padding * 3
        height: chipRow.implicitHeight + Config.padding * 2
        radius: height / 2
        color: Config.backgroundColor
        border.width: 1
        border.color: Config.surface2Color

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: Config.padding

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Config.fontSizeSmall
                height: width
                radius: Config.radiusSmall / 2
                color: root.picked
                border.width: 1
                border.color: Config.surface2Color

                // Reads the picked pixel from the capture file, copied 1:1
                // (a stretched draw would blend in its neighbors). Hidden
                // under the swatch: a Canvas only paints while visible
                Canvas {
                    id: sampler

                    readonly property real scale: root.screenshot.monitorScale

                    width: 1
                    height: 1
                    z: -1

                    Component.onCompleted: loadImage(root.source)
                    onImageLoaded: requestPaint()
                    // Every monitor has a picker; only the shown one reads
                    // (a hidden Canvas still paints, with its own image)
                    onPaint: {
                        if (!root.visible || !isImageLoaded(root.source) || root.px < 0)
                            return;
                        const x = root.px;
                        const y = root.py;
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, 1, 1);
                        ctx.drawImage(root.source, Math.floor(x * scale), Math.floor(y * scale), 1, 1, 0, 0, 1, 1);
                        const data = ctx.getImageData(0, 0, 1, 1).data;
                        root.screenshot.setSample(x, y, Qt.rgba(data[0] / 255, data[1] / 255, data[2] / 255, 1));
                    }

                    Connections {
                        target: root

                        function onVisibleChanged() {
                            sampler.requestPaint();
                        }
                        function onPxChanged() {
                            sampler.requestPaint();
                        }
                        function onPyChanged() {
                            sampler.requestPaint();
                        }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.screenshot.pickedText
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                color: Config.textColor
            }
        }
    }
}
