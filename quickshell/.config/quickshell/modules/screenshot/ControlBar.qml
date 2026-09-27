pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import "../../components/"

// Card at the bottom center of the active monitor: mode switch, what is
// selected, actions, and the keys for the current state. It moves to the
// top while the selection covers its spot (and not the top one)
Rectangle {
    id: root

    required property var screenshot

    readonly property int buttonSize: Config.fontSizeIconSmall * 2
    // Clear of the shell bar, which is in the frozen image
    readonly property real edgeMargin: Config.barReservedHeight + Config.spacing * 2
    readonly property real bottomY: parent.height - height - edgeMargin
    readonly property real topY: edgeMargin
    readonly property bool atTop: covers(bottomY) && !covers(topY)
    readonly property string mode: screenshot.mode
    readonly property bool selecting: screenshot.selectionWidth > 0 && screenshot.selectionHeight > 0
    readonly property string size: screenshot.realWidth + " × " + screenshot.realHeight

    // Plays the entry animation once the overlay is up
    property bool shown: false

    // Whether the selection overlaps the card placed at `cardY`
    function covers(cardY: real): bool {
        const s = root.screenshot;
        if (!root.selecting)
            return false;
        return root.x < s.selectionX + s.selectionWidth && root.x + root.width > s.selectionX && cardY < s.selectionY + s.selectionHeight && cardY + root.height > s.selectionY;
    }

    Component.onCompleted: shown = true

    x: Math.round((parent.width - width) / 2)
    y: atTop ? topY : bottomY
    implicitWidth: content.implicitWidth + Config.padding * 4
    implicitHeight: content.implicitHeight + Config.padding * 4
    radius: Config.radiusLarge
    color: Config.backgroundColor
    border.width: 1
    border.color: Config.surface2Color

    scale: shown ? 1 : Config.animPopupFromScale
    opacity: shown ? 1 : 0

    Behavior on y {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Config.animPopupEasing
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }

    // Presses on the card must not reach the overlay (a new region)
    MouseArea {
        anchors.fill: parent
    }

    component Divider: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: root.buttonSize * 2 / 3
        color: Config.surface2Color
    }

    ColumnLayout {
        id: content

        anchors.centerIn: parent
        spacing: Config.padding * 2

        RowLayout {
            spacing: Config.spacing

            SegmentedControl {
                Layout.fillWidth: false
                Layout.preferredWidth: Config.fontSizeNormal * 6 * options.length
                implicitHeight: root.buttonSize
                options: root.screenshot.modes.map(mode => ({
                            label: root.screenshot.modeLabels[mode],
                            icon: root.screenshot.modeIcons[mode]
                        }))
                currentIndex: root.screenshot.modes.indexOf(root.mode)
                onSelected: index => root.screenshot.setMode(root.screenshot.modes[index])
            }

            Divider {}

            // Color mode: swatch + value
            Rectangle {
                visible: root.mode === "color"
                Layout.preferredWidth: Config.fontSizeSmall
                Layout.preferredHeight: Config.fontSizeSmall
                radius: Config.radiusSmall / 2
                color: root.screenshot.pickedColor
                border.width: 1
                border.color: Config.surface2Color
            }

            // What is selected; a fixed minimum so the card doesn't jump
            // while a region is drawn
            ColumnLayout {
                Layout.minimumWidth: Config.fontSizeSmall * 9
                Layout.maximumWidth: Config.fontSizeSmall * 18
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: {
                        switch (root.mode) {
                        case "window":
                            return root.selecting ? root.screenshot.selectedWindowClass || root.screenshot.selectedWindowTitle : "No window";
                        case "screen":
                            return root.screenshot.hyprlandMonitor?.name ?? "Screen";
                        case "color":
                            return root.screenshot.pickX >= 0 ? root.screenshot.pickedText : "No color";
                        default:
                            return root.selecting ? root.size : "No region";
                        }
                    }
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    font.bold: true
                    color: root.selecting || root.mode === "color" ? Config.textColor : Config.subtextColor
                }

                Text {
                    Layout.fillWidth: true
                    visible: (root.mode === "window" || root.mode === "screen") && root.selecting
                    text: root.size
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }
            }

            Divider {}

            ActionButton {
                icon: root.mode === "color" ? "\u{f018f}" : "\u{f012c}"
                text: root.mode === "color" ? "Copy" : "Capture"
                size: root.buttonSize
                enabled: root.screenshot.canConfirm
                opacity: enabled ? 1 : 0.4
                baseColor: Config.accentColor
                hoverColor: Qt.lighter(Config.accentColor, 1.1)
                textColor: Config.textReverseColor
                onClicked: root.screenshot.confirmSelection()
            }

            ActionButton {
                icon: "\u{f03eb}"
                text: "Edit"
                size: root.buttonSize
                enabled: root.screenshot.canConfirm && root.mode !== "color"
                opacity: enabled ? 1 : 0.4
                onClicked: root.screenshot.editSelection()
            }

            ActionButton {
                visible: root.mode === "region"
                icon: "\u{f054c}"
                size: root.buttonSize
                enabled: root.screenshot.hasSelection
                opacity: enabled ? 1 : 0.4
                onClicked: root.screenshot.resetSelection()
            }

            ActionButton {
                icon: "\u{f0156}"
                size: root.buttonSize
                baseColor: Qt.alpha(Config.errorColor, 0)
                hoverColor: Qt.alpha(Config.errorColor, 0.2)
                textColor: Config.subtextColor
                hoverTextColor: Config.errorColor
                onClicked: root.screenshot.cancelCapture()
            }
        }

        // Keys for the current state
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: Config.screenshotHints
            spacing: Config.spacing * 2

            Repeater {
                model: {
                    const hints = [];
                    if (root.mode === "region" && !root.screenshot.hasSelection)
                        hints.push(["drag", "select"]);
                    if (root.mode === "window")
                        hints.push(["click", "pick"]);
                    if (root.mode === "color")
                        hints.push(["click", "copy"], ["←↑↓→", "move"], ["shift", "×10"]);
                    else if (root.screenshot.canConfirm)
                        hints.push(["⏎", "capture"], ["E", "edit"]);
                    if (root.mode === "region" && root.screenshot.hasSelection)
                        hints.push(["←↑↓→", "move"], ["ctrl", "resize"], ["shift", "×10"]);
                    else
                        hints.push(["R W S C", "mode"]);
                    hints.push(["esc", "cancel"]);
                    return hints;
                }

                KeyHint {
                    required property var modelData

                    keys: modelData[0]
                    label: modelData[1]
                }
            }
        }
    }
}
