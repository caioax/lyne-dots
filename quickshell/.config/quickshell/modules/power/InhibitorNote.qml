pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services

// Warns about apps blocking sleep or shutdown (logind inhibitors)
Rectangle {
    id: root

    readonly property var list: PowerService.inhibitors

    visible: list.length > 0
    implicitWidth: icon.implicitWidth + message.implicitWidth + Config.spacing + Config.padding * 4
    implicitHeight: Math.max(icon.implicitHeight, message.implicitHeight) + Config.padding * 2
    radius: Config.radius
    color: Qt.alpha(Config.warningColor, 0.12)

    Text {
        id: icon

        anchors.left: parent.left
        anchors.leftMargin: Config.padding * 2
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{f0026}"
        font.family: Config.font
        font.pixelSize: Config.fontSizeIconSmall
        color: Config.warningColor
    }

    Text {
        id: message

        anchors.left: icon.right
        anchors.leftMargin: Config.spacing
        anchors.right: parent.right
        anchors.rightMargin: Config.padding * 2
        anchors.verticalCenter: parent.verticalCenter
        text: root.list.map(i => "<b>" + i.who + "</b> is blocking " + i.what.replace(/:/g, " and ") + (i.why ? ": " + i.why : "")).join("<br>")
        textFormat: Text.StyledText
        wrapMode: Text.Wrap
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        color: Config.textColor
    }
}
