pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// Tray style "row": every icon always in the bar
Row {
    id: root

    required property var model

    signal itemActivated

    spacing: Math.round(Config.padding / 2)

    Repeater {
        model: root.model.items

        delegate: TrayItem {
            required property var modelData
            model: root.model
            item: modelData
            onActivated: root.itemActivated()
        }
    }
}
