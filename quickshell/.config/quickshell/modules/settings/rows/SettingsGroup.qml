pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Titled stack of SettingRows joined together: a small gap between rows and
// the large radius only on the ends of the group
ColumnLayout {
    id: root

    property string title
    default property alias rows: rowsLayout.data

    // Reading `visible` of each child in a binding tracks visibility changes
    // (and rows added later, e.g. by Repeaters) without manual connections
    readonly property var _visibleRows: Array.from(rowsLayout.children).filter(c => c.visible && c.isSettingRow === true)

    on_VisibleRowsChanged: {
        _visibleRows.forEach((row, i) => {
            row.first = i === 0;
            row.last = i === _visibleRows.length - 1;
        });
    }

    Layout.fillWidth: true
    spacing: Config.spacing

    Text {
        visible: root.title !== ""
        Layout.leftMargin: Config.padding
        text: root.title.toUpperCase()
        font.family: Config.font
        font.pixelSize: Config.fontSizeSmall
        font.bold: true
        font.letterSpacing: 1
        color: Config.accentColor
    }

    ColumnLayout {
        id: rowsLayout

        Layout.fillWidth: true
        spacing: Math.round(Config.padding / 3)
    }
}
