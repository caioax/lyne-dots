pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// One app of the results list: icon box, name and description. The selected
// row gets the accent outline and the ⏎ hint; clicking launches it
Item {
    id: root

    required property var modelData
    required property int index
    property bool selected: false
    property bool showDescription: true
    readonly property bool hovered: mouse.containsMouse
    readonly property string description: modelData?.comment || modelData?.genericName || ""

    signal activated

    readonly property int iconBoxSize: Config.fontSizeIconLarge + Config.padding * 2

    implicitHeight: iconBoxSize + Config.padding * 2

    // Hover background; the selection is drawn by the list's highlight
    Rectangle {
        anchors.fill: parent
        radius: Config.radiusLarge
        color: root.hovered && !root.selected ? Config.surface0Color : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
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
                text: root.modelData?.name ?? ""
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

        // md-keyboard-return
        Text {
            visible: root.selected
            text: "\u{f0311}"
            font.family: Config.font
            font.pixelSize: Config.fontSizeIconSmall
            color: Config.accentColor
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
