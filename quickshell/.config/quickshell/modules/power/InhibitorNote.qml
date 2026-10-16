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
        text: root.list.map(i => i.why ? I18n.tr("%1 is blocking %2: %3", "<b>" + i.who + "</b>", i.what.replace(/:/g, ", "), i.why) : I18n.tr("%1 is blocking %2", "<b>" + i.who + "</b>", i.what.replace(/:/g, ", "))).join("<br>")
        textFormat: Text.StyledText
        wrapMode: Text.Wrap
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        color: Config.textColor
    }
}
