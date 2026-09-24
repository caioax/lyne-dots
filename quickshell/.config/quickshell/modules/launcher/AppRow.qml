pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// One app of the results list: icon box, name and description. The selected
// row gets the accent outline and the ⏎ hint. Clicks go out as `activated`;
// the ⋮ button (on hover) and right click ask for the app menu
Item {
    id: root

    required property var modelData
    required property int index
    property bool selected: false
    property bool showDescription: true
    // A HoverHandler keeps reporting hover while over the ⋮ button
    readonly property bool hovered: rowHover.hovered
    readonly property string description: modelData?.comment || modelData?.genericName || ""

    signal activated
    signal menuRequested(Item anchor)

    readonly property int iconBoxSize: Config.fontSizeIconLarge + Config.padding * 2

    implicitHeight: iconBoxSize + Config.padding * 2

    Rectangle {
        anchors.fill: parent
        radius: Config.radiusLarge
        color: root.selected ? Config.surface1Color : root.hovered ? Config.surface0Color : "transparent"
        border.width: root.selected ? 1 : 0
        border.color: Qt.alpha(Config.accentColor, 0.6)

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }
    }

    HoverHandler {
        id: rowHover
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton)
                root.menuRequested(menuButton);
            else
                root.activated();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Config.padding
        anchors.rightMargin: Config.padding * 2
        spacing: Config.spacing + Config.padding

        Rectangle {
            Layout.preferredWidth: root.iconBoxSize
            Layout.preferredHeight: root.iconBoxSize
            radius: Config.radiusLarge
            color: root.selected ? Config.surface2Color : Config.surface1Color

            Image {
                anchors.centerIn: parent
                width: Config.fontSizeIconLarge
                height: width
                source: "image://icon/" + (root.modelData?.icon || "application-x-executable")
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: Math.round(Config.padding / 3)

            Text {
                width: parent.width
                // Chars matched by the search in accent
                text: LauncherService.highlightedName(root.modelData, Config.accentColor)
                textFormat: Text.StyledText
                elide: Text.ElideRight
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                font.bold: root.selected
                color: Config.textColor
            }

            Text {
                width: parent.width
                visible: root.showDescription && root.description !== ""
                text: root.description
                elide: Text.ElideRight
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
            }
        }

        MenuButton {
            id: menuButton
            visible: root.hovered
            onClicked: root.menuRequested(menuButton)
        }

        // md-keyboard-return
        Text {
            visible: root.selected && !menuButton.visible
            text: "\u{f0311}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconSmall
            color: Config.accentColor
        }
    }

}
