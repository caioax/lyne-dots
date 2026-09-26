pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

// One power action. `variant` picks the look: "tile" (card with the icon
// box and label), "square" (icon only), "round" (circle, label below) or
// "row" (full-width line with the box and the label, for narrow columns).
// First click selects, a click on the selected one runs it; while its
// countdown runs, a ring fills around the icon and the seconds replace it
Item {
    id: root

    required property var action
    property string variant: "tile"
    // Countdown shown here only, without opening the power menu
    property bool inPlace: false
    // The letter keycap (off where letters type, like the lock screen)
    property bool showKey: true

    readonly property bool selected: PowerService.selectedId === action.id
    readonly property bool pending: PowerService.pendingId === action.id
    readonly property bool hovered: mouse.containsMouse
    readonly property color tone: action.tone === "error" ? Config.errorColor : action.tone === "warning" ? Config.warningColor : Config.accentColor

    readonly property bool tile: variant === "tile"
    readonly property bool round: variant === "round"
    readonly property bool line: variant === "row"
    readonly property real boxSize: {
        if (round)
            return Config.fontSizeIconLarge * 2.4;
        if (tile)
            return Config.fontSizeIcon * 2.4;
        if (line)
            return Config.fontSizeIcon * 1.8;
        return Config.fontSizeIcon * 2.6;
    }
    // Room around the box for the countdown ring
    readonly property real ringGap: line ? Config.padding / 2 : Config.padding

    implicitWidth: {
        if (tile)
            return Config.fontSizeNormal * 7;
        if (line)
            return rowLayout.implicitWidth + Config.padding * 2;
        if (round)
            return Math.max(boxSize, label.implicitWidth) + ringGap * 2;
        return boxSize + ringGap * 2;
    }
    implicitHeight: {
        if (tile)
            return column.implicitHeight + Config.padding * 5;
        if (line)
            return rowLayout.implicitHeight + Config.padding;
        return column.implicitHeight + (round ? 0 : ringGap * 2);
    }

    scale: mouse.pressed ? 0.96 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }

    // Tile and row background (the other variants are just the box)
    Rectangle {
        visible: root.tile || root.line
        anchors.fill: parent
        radius: Config.radiusLarge
        color: {
            if (root.selected)
                return Qt.alpha(root.tone, 0.14);
            if (root.hovered)
                return Config.cardHoverColor;
            // Rows sit on a card already: no fill at rest
            return root.line ? Qt.alpha(Config.cardHoverColor, 0) : Config.cardColor;
        }
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

        visible: !root.line
        anchors.centerIn: parent
        spacing: Config.padding

        IconBox {
            Layout.alignment: Qt.AlignHCenter
            button: root
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
            visible: root.tile && root.showKey
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

    RowLayout {
        id: rowLayout

        visible: root.line
        anchors.fill: parent
        anchors.leftMargin: Config.padding
        anchors.rightMargin: Config.padding * 2
        spacing: Config.spacing

        IconBox {
            button: root
        }

        Text {
            Layout.fillWidth: true
            text: root.action.label
            elide: Text.ElideRight
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            font.bold: root.selected
            color: root.selected ? Config.textColor : Config.subtextColor
        }

        // Seconds left while counting down
        Text {
            visible: root.pending
            text: Math.ceil(PowerService.remaining / 1000) + "s"
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: root.tone
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.selected) {
                PowerService.request(root.action.id, root.inPlace);
            } else {
                PowerService.cancel();
                PowerService.selectedId = root.action.id;
            }
        }
    }

    // The action's box with the countdown ring around it and the letter
    component IconBox: Item {
        required property Item button

        implicitWidth: button.boxSize + button.ringGap * 2
        implicitHeight: implicitWidth

        Rectangle {
            id: box

            anchors.centerIn: parent
            width: button.boxSize
            height: button.boxSize
            radius: button.round ? width / 2 : Config.radiusLarge
            color: {
                if (button.selected)
                    return button.tone;
                if (button.hovered && !button.tile && !button.line)
                    return Config.cardHoverColor;
                return button.tile || button.line ? Config.surface1Color : Config.cardColor;
            }

            Behavior on color {
                ColorAnimation {
                    duration: Config.animDurationShort
                }
            }

            Text {
                anchors.centerIn: parent
                // Rows show the seconds at their end instead
                text: button.pending && !button.line ? Math.ceil(PowerService.remaining / 1000) : button.action.glyph
                font.family: Config.font
                font.pixelSize: button.round ? Config.fontSizeIconLarge : button.line ? Config.fontSizeIconSmall : Config.fontSizeIcon
                font.bold: button.pending && !button.line
                color: button.selected ? Config.textReverseColor : button.hovered ? button.tone : Config.textColor

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
            active: button.pending

            sourceComponent: ProgressRing {
                value: (1 - PowerService.pendingProgress) * 100
                strokeWidth: Math.max(2, Config.padding / 2)
                color: button.tone
                trackColor: Qt.alpha(button.tone, 0.2)
            }
        }

        // Letter that runs it
        Rectangle {
            visible: !button.tile && !button.line && button.showKey
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: Math.max(height, keyText.implicitWidth + Config.padding)
            height: keyText.implicitHeight
            radius: Config.radiusSmall
            color: Config.surface1Color

            Text {
                id: keyText

                anchors.centerIn: parent
                text: button.action.key
                font.family: Config.font
                font.pixelSize: Math.round(Config.fontSizeSmall * 0.85)
                font.bold: true
                color: Config.subtextColor
            }
        }
    }
}
