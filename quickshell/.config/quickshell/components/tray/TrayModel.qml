pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// Tray state shared by every tray style: the items to show and what to do
// with them. Styles only read `items` and call the actions; the widget that
// owns the model opens the context menu on menuRequested.
QtObject {
    id: root

    readonly property var items: TrayService.items
    readonly property bool hasItems: items.length > 0

    // Pinned items in pin order, and the rest in tray order
    readonly property var pinnedIds: Config.barTrayPinned
    readonly property var pinnedItems: pinnedIds.map(id => items.find(i => i.id === id)).filter(i => i !== undefined)
    readonly property var restItems: items.filter(i => !pinnedIds.includes(i.id))

    signal menuRequested(var item, Item anchor)
    // The context menu went away: "triggered", "escape" or "outside"
    signal menuClosed(string reason)

    function iconSource(item) {
        return TrayService.getIconSource(item?.icon ?? "");
    }

    function activate(item) {
        item.activate();
    }

    function isPinned(item) {
        return pinnedIds.includes(item.id);
    }

    function setPinned(item, pinned) {
        const ids = pinnedIds.filter(id => id !== item.id);
        if (pinned)
            ids.push(item.id);
        StateService.set("bar.tray.pinned", ids);
    }

    // Pinning lives in the menu too, so every item gets one in that style
    function hasMenu(item) {
        return item.hasMenu || Config.barTrayStyle === "pinned";
    }

    // Shell rows on top of the item's own menu
    function menuExtras(item) {
        if (Config.barTrayStyle !== "pinned")
            return [];
        const pinned = isPinned(item);
        return [
            {
                action: pinned ? "unpin" : "pin",
                label: pinned ? "Unpin from bar" : "Pin to bar",
                // md-pin_off / md-pin
                glyph: pinned ? "\u{f0404}" : "\u{f0403}"
            }
        ];
    }

    function runExtra(item, action) {
        if (action === "pin" || action === "unpin")
            setPinned(item, action === "pin");
    }

    function openMenu(item, anchor) {
        if (hasMenu(item))
            menuRequested(item, anchor);
    }
}
