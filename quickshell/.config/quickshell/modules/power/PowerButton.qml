pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// One power action. `variant` picks the look: "tile" (card with the icon
// box and label), "square" (icon only) or "round" (circle, label below).
// First click selects, a click on the selected one runs it; while its
// countdown runs, a ring fills around the icon and the seconds replace it
Item {
    id: root

    required property var action
    property string variant: "tile"

    readonly property bool selected: PowerService.selectedId === action.id
    readonly property bool pending: PowerService.pendingId === action.id
    readonly property bool hovered: mouse.containsMouse
    readonly property color tone: action.tone === "error" ? Config.errorColor : action.tone === "warning" ? Config.warningColor : Config.accentColor

    readonly property bool tile: variant === "tile"
    readonly property bool round: variant === "round"
    readonly property real boxSize: round ? Config.fontSizeIconLarge * 2.4 : tile ? Config.fontSizeIcon * 2.4 : Config.fontSizeIcon * 2.6
    // Room around the box for the countdown ring
    readonly property real ringGap: Config.padding

    implicitWidth: tile ? Config.fontSizeNormal * 7 : round ? Math.max(boxSize, label.implicitWidth) + ringGap * 2 : boxSize + ringGap * 2
    implicitHeight: tile ? column.implicitHeight + Config.padding * 5 : column.implicitHeight + (round ? 0 : ringGap * 2)

    scale: mouse.pressed ? 0.96 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }

    // Tile background (the other variants are just the box)
    Rectangle {
        visible: root.tile
        anchors.fill: parent
        radius: Config.radiusLarge
        color: root.selected ? Qt.alpha(root.tone, 0.14) : root.hovered ? Config.cardHoverColor : Config.cardColor
        border.width: 1
        border.color: Qt.alpha(root.tone, root.selected ? 0.6 : 0)

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }
    }

    ColumnLayout {
        id: column

        anchors.centerIn: parent
        spacing: Config.padding

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: root.boxSize + root.ringGap * 2
            implicitHeight: implicitWidth

            Rectangle {
                id: box

                anchors.centerIn: parent
                width: root.boxSize
                height: root.boxSize
                radius: root.round ? width / 2 : Config.radiusLarge
                color: {
                    if (root.selected)
                        return root.tone;
                    if (root.hovered && !root.tile)
                        return Config.cardHoverColor;
                    return root.tile ? Config.surface1Color : Config.cardColor;
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animDurationShort
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.pending ? Math.ceil(PowerService.remaining / 1000) : root.action.glyph
                    font.family: Config.font
                    font.pixelSize: root.round ? Config.fontSizeIconLarge : Config.fontSizeIcon
                    font.bold: root.pending
                    color: root.selected ? Config.textReverseColor : root.hovered ? root.tone : Config.textColor

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animDurationShort
                        }
                    }
                }
            }

            // Fills up while the countdown runs
            Loader {
                anchors.fill: parent
                active: root.pending

                sourceComponent: ProgressRing {
                    value: (1 - PowerService.pendingProgress) * 100
                    strokeWidth: Math.max(2, Config.padding / 2)
                    color: root.tone
                    trackColor: Qt.alpha(root.tone, 0.2)
                }
            }

            // Letter that runs it
            Rectangle {
                visible: !root.tile
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: Math.max(height, keyText.implicitWidth + Config.padding)
                height: keyText.implicitHeight
                radius: Config.radiusSmall
                color: Config.surface1Color

                Text {
                    id: keyText

                    anchors.centerIn: parent
                    text: root.action.key
                    font.family: Config.font
                    font.pixelSize: Math.round(Config.fontSizeSmall * 0.85)
                    font.bold: true
                    color: Config.subtextColor
                }
            }
        }

        Text {
            id: label

            visible: root.variant !== "square"
            Layout.alignment: Qt.AlignHCenter
            text: root.action.label
            font.family: Config.font
            font.pixelSize: root.round ? Config.fontSizeNormal : Config.fontSizeSmall
            font.bold: root.selected
            color: root.selected ? Config.textColor : Config.subtextColor
        }

        // Letter under the tile label
        Rectangle {
            visible: root.tile
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.max(implicitHeight, tileKey.implicitWidth + Config.padding * 2)
            implicitHeight: tileKey.implicitHeight + Config.padding / 2
            radius: Config.radiusSmall
            color: root.selected ? Qt.alpha(root.tone, 0.2) : Config.surface1Color

            Text {
                id: tileKey

                anchors.centerIn: parent
                text: root.action.key
                font.family: Config.font
                font.pixelSize: Math.round(Config.fontSizeSmall * 0.85)
                font.bold: true
                color: root.selected ? root.tone : Config.mutedColor
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.selected) {
                PowerService.request(root.action.id);
            } else {
                PowerService.cancel();
                PowerService.selectedId = root.action.id;
            }
        }
    }
}
