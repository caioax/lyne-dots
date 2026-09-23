pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Rounded surface used by the sections of popups (system monitor, calendar...)
Rectangle {
    id: root

    default property alias content: layout.data
    property alias spacing: layout.spacing
    readonly property int padding: Config.padding * 2

    implicitWidth: layout.implicitWidth + padding * 2
    implicitHeight: layout.implicitHeight + padding * 2
    radius: Config.radiusLarge
    color: Config.surface0Color

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: Config.spacing
    }
}
