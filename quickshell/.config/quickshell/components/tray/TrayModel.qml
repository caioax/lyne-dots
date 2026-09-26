pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// Tray state shared by every tray style: the items to show and what to do
// with them. Styles only read `items` and call the actions; the widget that
// owns the model opens the context menu on menuRequested.
QtObject {
    id: root

    // Shown items in the user's order, split for the pinned style
    readonly property var items: TrayService.shownItems
    readonly property bool hasItems: items.length > 0
    readonly property var pinnedItems: items.filter(i => TrayService.isPinned(i.id))
    readonly property var restItems: items.filter(i => !TrayService.isPinned(i.id))

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
        return TrayService.isPinned(item.id);
    }

    function setPinned(item, pinned) {
        TrayService.setPinned(item.id, pinned);
    }

    // Every item gets a menu: the shell rows (pin, hide) are always there
    function hasMenu(item) {
        return true;
    }

    // Shell rows on top of the item's own menu
    function menuExtras(item) {
        const extras = [];
        if (Config.barTrayStyle === "pinned") {
            const pinned = isPinned(item);
            extras.push({
                action: pinned ? "unpin" : "pin",
                label: pinned ? "Unpin from bar" : "Pin to bar",
                // md-pin_off / md-pin
                glyph: pinned ? "\u{f0404}" : "\u{f0403}"
            });
        }
        extras.push({
            action: "hide",
            label: "Hide from bar",
            // md-eye_off
            glyph: "\u{f0209}"
        });
        return extras;
    }

    function runExtra(item, action) {
        if (action === "pin" || action === "unpin")
            setPinned(item, action === "pin");
        else if (action === "hide")
            TrayService.setHidden(item.id, true);
    }

    function openMenu(item, anchor) {
        if (hasMenu(item))
            menuRequested(item, anchor);
    }
}
