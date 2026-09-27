pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.config

// Region mode on top of the dimming: dashed guides to the screen edges, and
// once a region is drawn, handles to resize it and the inside to move it.
// Presses anywhere else fall through to the overlay, which draws a new one
Item {
    id: root

    required property var screenshot

    // Cursor, for the crosshair before anything is drawn
    property real guideMouseX: -1
    property real guideMouseY: -1

    readonly property real selX: screenshot.selectionX
    readonly property real selY: screenshot.selectionY
    readonly property real selW: screenshot.selectionWidth
    readonly property real selH: screenshot.selectionHeight
    // The outline is drawn outside the region, this wide
    readonly property real border: screenshot.hyprBorderSize
    readonly property bool editing: screenshot.hasSelection
    readonly property int handleSize: Config.padding * 2

    // Crosshair at the cursor, or lines from each edge of the region to the
    // screen edges, stopping at the outline
    readonly property var guideLines: {
        if (root.selW <= 0 || root.selH <= 0) {
            if (root.guideMouseX < 0)
                return [];
            return [[Qt.point(root.guideMouseX, 0), Qt.point(root.guideMouseX, height)], [Qt.point(0, root.guideMouseY), Qt.point(width, root.guideMouseY)]];
        }
        const left = root.selX - root.border / 2;
        const right = root.selX + root.selW + root.border / 2;
        const top = root.selY - root.border / 2;
        const bottom = root.selY + root.selH + root.border / 2;
        const lines = [];
        for (const x of [left, right])
            lines.push([Qt.point(x, 0), Qt.point(x, root.selY - root.border)], [Qt.point(x, root.selY + root.selH + root.border), Qt.point(x, height)]);
        for (const y of [top, bottom])
            lines.push([Qt.point(0, y), Qt.point(root.selX - root.border, y)], [Qt.point(root.selX + root.selW + root.border, y), Qt.point(width, y)]);
        return lines;
    }

    Shape {
        anchors.fill: parent
        visible: Config.screenshotGuides

        ShapePath {
            strokeColor: Qt.alpha(Config.textColor, 0.5)
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [Config.padding, Config.padding]
            fillColor: Qt.alpha(Config.textColor, 0)

            PathMultiline {
                paths: root.guideLines
            }
        }
    }

    // Drag the inside to move the region; double click captures it
    MouseArea {
        id: moveArea

        property point pressPos
        property point startPos

        visible: root.editing
        x: root.selX
        y: root.selY
        width: root.selW
        height: root.selH
        preventStealing: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.SizeAllCursor

        onPressed: mouse => {
            pressPos = mapToItem(root, mouse.x, mouse.y);
            startPos = Qt.point(root.selX, root.selY);
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const pos = mapToItem(root, mouse.x, mouse.y);
            root.screenshot.moveRegion(startPos.x + pos.x - pressPos.x, startPos.y + pos.y - pressPos.y);
        }
        onDoubleClicked: root.screenshot.confirmSelection()
    }

    // Corner and edge handles, centered on the outline. hx/hy: 0 = left/top
    // edge, 1 = right/bottom, 0.5 = that axis doesn't change
    Repeater {
        model: [
            {
                hx: 0,
                hy: 0
            },
            {
                hx: 0.5,
                hy: 0
            },
            {
                hx: 1,
                hy: 0
            },
            {
                hx: 1,
                hy: 0.5
            },
            {
                hx: 1,
                hy: 1
            },
            {
                hx: 0.5,
                hy: 1
            },
            {
                hx: 0,
                hy: 1
            },
            {
                hx: 0,
                hy: 0.5
            }
        ]

        Item {
            id: handle

            required property var modelData
            readonly property real hx: modelData.hx
            readonly property real hy: modelData.hy
            readonly property bool corner: hx !== 0.5 && hy !== 0.5
            // Edge handles leave when the region gets too small for them
            readonly property bool fits: (hx !== 0.5 || root.selW > root.handleSize * 4) && (hy !== 0.5 || root.selH > root.handleSize * 4)

            visible: root.editing && fits
            width: root.handleSize
            height: root.handleSize
            x: root.selX - root.border / 2 + hx * (root.selW + root.border) - width / 2
            y: root.selY - root.border / 2 + hy * (root.selH + root.border) - height / 2

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Config.accentColor
                border.width: 1
                border.color: Config.surface0Color
                scale: handleArea.containsMouse || handleArea.pressed ? 1.4 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Config.animDurationShort
                    }
                }
            }

            MouseArea {
                id: handleArea

                property point pressPos
                property rect startRect

                anchors.fill: parent
                anchors.margins: -Config.padding
                hoverEnabled: true
                preventStealing: true
                cursorShape: {
                    if (!handle.corner)
                        return handle.hx === 0.5 ? Qt.SizeVerCursor : Qt.SizeHorCursor;
                    return handle.hx === handle.hy ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor;
                }

                onPressed: mouse => {
                    pressPos = mapToItem(root, mouse.x, mouse.y);
                    startRect = Qt.rect(root.selX, root.selY, root.selW, root.selH);
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    const pos = mapToItem(root, mouse.x, mouse.y);
                    const dx = pos.x - pressPos.x;
                    const dy = pos.y - pressPos.y;
                    let left = startRect.x;
                    let top = startRect.y;
                    let right = startRect.x + startRect.width;
                    let bottom = startRect.y + startRect.height;
                    if (handle.hx === 0)
                        left += dx;
                    else if (handle.hx === 1)
                        right += dx;
                    if (handle.hy === 0)
                        top += dy;
                    else if (handle.hy === 1)
                        bottom += dy;
                    root.screenshot.setRegion(left, top, right, bottom);
                }
            }
        }
    }
}
