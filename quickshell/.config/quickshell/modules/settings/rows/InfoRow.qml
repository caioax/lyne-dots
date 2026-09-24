pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Read-only label: value row
SettingRow {
    id: root

    property string value

    Text {
        Layout.maximumWidth: root.width * 0.6
        text: root.value !== "" ? root.value : "—"
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
        font.family: Config.font
        font.pixelSize: Config.fontSizeNormal
        color: Config.subtextColor
    }
}
