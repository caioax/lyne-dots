pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root

    // --- API Properties ---
    required property string icon
    property string text: ""
    property color baseColor: Config.errorColor

    // --- Signals ---
    signal clicked

    // --- Dimensions & Styling ---
    implicitWidth: content.implicitWidth + (Config.padding * 2)
    implicitHeight: 32
    radius: Config.radius

    // Transparent background that tints on hover
    color: mouseArea.containsMouse ? Qt.alpha(baseColor, 0.15) : Qt.alpha(baseColor, 0)

    border.width: 1
    border.color: mouseArea.containsMouse ? baseColor : Qt.alpha(Config.surface2Color, 0.5)

    // --- Animations ---
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

    // --- Layout Content ---
    RowLayout {
        id: content

        anchors.fill: root.text === "" ? parent : undefined
        anchors.centerIn: root.text !== "" ? parent : undefined

        spacing: root.text === "" ? 0 : 6

        Text {
            text: root.icon
            font.family: Config.font
            font.pixelSize: Config.fontSizeNormal
            color: root.baseColor
            Layout.alignment: root.text === "" ? Qt.AlignHCenter | Qt.AlignVCenter : Qt.AlignVCenter
        }

        Text {
            id: label
            visible: text !== ""
            text: root.text
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: root.baseColor
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // --- Interaction ---
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.clicked()

        // Visual feedback on press
        onPressed: root.opacity = 0.7
        onReleased: root.opacity = 1.0
    }
}
