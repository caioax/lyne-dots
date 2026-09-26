pragma Singleton
import QtQuick
import Quickshell.Services.SystemTray
import qs.config

QtObject {
    id: root

    // Every tray item, in the user's order (bar.tray.order; items missing
    // from it keep the tray's order after the ordered ones)
    readonly property var items: {
        const order = Config.barTrayOrder;
        const rank = item => {
            const i = order.indexOf(item.id);
            return i < 0 ? order.length : i;
        };
        return [...SystemTray.items.values].sort((a, b) => rank(a) - rank(b));
    }
    // The ones the bar shows (not hidden)
    readonly property var shownItems: items.filter(i => !isHidden(i.id))

    // Checks whether there are items in the tray
    readonly property bool hasItems: shownItems.length > 0

    // --- PINNING (bar.tray.pinned, used by the "pinned" style) ---
    readonly property var pinnedIds: Config.barTrayPinned

    function isPinned(id) {
        return pinnedIds.includes(id);
    }

    function setPinned(id, pinned) {
        const ids = pinnedIds.filter(x => x !== id);
        if (pinned)
            ids.push(id);
        StateService.set("bar.tray.pinned", ids);
    }

    // --- HIDING (bar.tray.hidden: never shown in the bar) ---
    readonly property var hiddenIds: Config.barTrayHidden

    function isHidden(id) {
        return hiddenIds.includes(id);
    }

    function setHidden(id, hidden) {
        const ids = hiddenIds.filter(x => x !== id);
        if (hidden)
            ids.push(id);
        StateService.set("bar.tray.hidden", ids);
    }

    // --- ORDER ---
    // Swaps a running item with its neighbour (dir -1 = earlier). Saved ids
    // of items not running now stay in the list, after the running ones
    function move(id, dir) {
        const ids = items.map(i => i.id);
        const from = ids.indexOf(id);
        const to = from + dir;
        if (from < 0 || to < 0 || to >= ids.length)
            return;
        ids[from] = ids[to];
        ids[to] = id;
        StateService.set("bar.tray.order", ids.concat(Config.barTrayOrder.filter(x => !ids.includes(x))));
    }

    // Saved ids (pinned or hidden) of items that aren't running
    readonly property var missingIds: [...new Set(pinnedIds.concat(hiddenIds))].filter(id => !items.some(i => i.id === id))

    // Forgets an item that isn't running anymore
    function forget(id) {
        setPinned(id, false);
        setHidden(id, false);
        StateService.set("bar.tray.order", Config.barTrayOrder.filter(x => x !== id));
    }

    // Name to show for an item: its title, else its id
    function itemName(item) {
        return item?.title || item?.tooltipTitle || item?.id || "";
    }

    // --- ICON LOGIC ---
    function getIconSource(iconString) {
        if (!iconString)
            return "image://icon/image-missing";

        // Fix for URL parameters (common in Electron/Steam apps)
        if (iconString.includes("?path=")) {
            const split = iconString.split("?path=");
            if (split.length === 2) {
                const name = split[0];
                const path = split[1];
                let fileName = name;
                if (fileName.includes("/")) {
                    fileName = fileName.substring(fileName.lastIndexOf("/") + 1);
                }
                return "file://" + path + "/" + fileName;
            }
        }

        // Absolute file paths
        if (iconString.startsWith("/"))
            return "file://" + iconString;

        // Already a fully qualified URL (file://, image://qsimage/, image://icon/, etc.)
        if (iconString.startsWith("file://") || iconString.startsWith("image://"))
            return iconString;

        // Theme icon name (Freedesktop standard)
        return "image://icon/" + iconString;
    }

    // Resolves menu item icon source, returning empty string for missing icons
    function getMenuIconSource(iconString) {
        if (!iconString || iconString === "")
            return "";
        return getIconSource(iconString);
    }

    // Keeps reference to the currently open menu to ensure only 1 exists in the entire system
    property var activeMenu: null

    function registerActiveMenu(menuInstance) {
        if (activeMenu && activeMenu !== menuInstance) {
            // If there is already an open menu and we try to open another, close the previous one
            if (typeof activeMenu.close === "function") {
                activeMenu.close();
            } else {
                activeMenu.visible = false;
            }
        }
        activeMenu = menuInstance;
    }
}
