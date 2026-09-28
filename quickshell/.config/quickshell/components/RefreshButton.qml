pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root

    property bool loading: false
    property int size: 36
    property string tooltipText: "Refresh"

    signal clicked

    implicitWidth: size
    implicitHeight: size
    Layout.preferredWidth: size
    Layout.preferredHeight: size
    radius: Config.radius

    color: {
        if (root.loading)
            return Config.accentColor;
        if (mouseArea.containsMouse)
            return Config.surface2Color;
        return Config.surface1Color;
    }

    Behavior on color {
        enabled: !Config.themeTransitioning
        ColorAnimation { duration: Config.animDurationShort }
    }

    // Refresh Icon (visible when NOT loading)
    Text {
        anchors.centerIn: parent
        text: "󰑐"
        font.family: Config.font
        font.pixelSize: Config.fontSizeIcon
        color: Config.textColor
        visible: !root.loading
    }

    // Spinner (visible when loading)
    Spinner {
        anchors.centerIn: parent
        running: root.loading
        size: Config.fontSizeIcon
        color: Config.textReverseColor
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
