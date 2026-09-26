pragma Singleton
import QtQuick
import Quickshell.Services.SystemTray
import qs.config

QtObject {
    id: root

    // List of tray items
    readonly property var items: SystemTray.items.values

    // Checks whether there are items in the tray
    readonly property bool hasItems: items.length > 0

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
