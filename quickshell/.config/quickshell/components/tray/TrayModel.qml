pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Tray state shared by every tray style: the items to show and what to do
// with them. Styles only read `items` and call the actions; the widget that
// owns the model opens the context menu on menuRequested.
QtObject {
    id: root

    readonly property var items: TrayService.items
    readonly property bool hasItems: items.length > 0

    signal menuRequested(var item, Item anchor)

    function iconSource(item) {
        return TrayService.getIconSource(item?.icon ?? "");
    }

    function activate(item) {
        item.activate();
    }

    function openMenu(item, anchor) {
        if (item.hasMenu)
            menuRequested(item, anchor);
    }
}
