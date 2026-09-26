pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// Tray style "pinned": the pinned items stay in the bar (in pin order), the
// rest waits in the overflow popup
Row {
    id: root

    required property var model

    signal itemActivated

    spacing: Math.round(Config.padding / 2)

    Repeater {
        model: root.model.pinnedItems

        delegate: TrayItem {
            required property var modelData
            model: root.model
            item: modelData
            onActivated: root.itemActivated()
        }
    }

    OverflowStyle {
        model: root.model
        items: root.model.restItems
        onItemActivated: root.itemActivated()
    }
}
