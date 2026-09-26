import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Time and date. `size` is the time's pixel size (the date follows it);
// `alignment` lines both up left, center or right
ColumnLayout {
    id: root

    property real size: Config.fontSizeIconLarge * 4
    property int alignment: Qt.AlignHCenter

    spacing: 0

    Text {
        Layout.alignment: root.alignment
        text: TimeService.format("HH:mm")
        font.family: Config.font
        font.pixelSize: root.size
        font.bold: true
        color: Config.textColor
    }

    Text {
        Layout.alignment: root.alignment
        text: TimeService.format("dddd, d MMMM")
        font.family: Config.font
        font.pixelSize: Math.max(Config.fontSizeLarge, Math.round(root.size / 5))
        color: Config.subtextColor
    }
}
