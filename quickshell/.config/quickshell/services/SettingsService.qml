pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Settings window state and page registry
Singleton {
    id: root

    property bool visible: false
    property string currentPage: "theme"
    // Theme whose detail view the Theme page opens next (taken and cleared by it)
    property string pendingThemeDetail: ""

    function openThemeDetail(themeName: string) {
        pendingThemeDetail = themeName;
        if (currentPage === "theme")
            themeDetailRequested(themeName);
        currentPage = "theme";
    }

    signal themeDetailRequested(string themeName)

    // Sidebar entries, grouped by category in this order. Each id needs a
    // component in SettingsWindow.pageComponents
    readonly property var categories: ["Appearance", "Shell", "Hyprland", "System"]
    readonly property var pages: [
        {
            id: "theme",
            label: "Theme",
            icon: "\u{f03d8}",
            description: "Colors, light or dark mode, transparency and the wallpaper each theme brings",
            category: "Appearance"
        },
        {
            id: "wallpaper",
            label: "Wallpaper",
            icon: "\u{f0e09}",
            description: "Your wallpaper library: apply, favorite, add and delete",
            category: "Appearance"
        },
        {
            id: "layout",
            label: "Layout",
            icon: "\u{f0607}",
            description: "Corners, spacing and motion",
            category: "Appearance"
        },
        {
            id: "typography",
            label: "Typography",
            icon: "\u{f06d6}",
            description: "Interface font and text and icon sizes",
            category: "Appearance"
        },
        {
            id: "bar",
            label: "Bar",
            icon: "\u{f1513}",
            description: "Template, position, size and behavior of the bar",
            category: "Shell"
        },
        {
            id: "launcher",
            label: "Launcher",
            icon: "\u{f003b}",
            description: "Template, search, favorites, hidden apps and usage ranking",
            category: "Shell"
        },
        {
            id: "clipboard",
            label: "Clipboard",
            icon: "\u{f014d}",
            description: "What the history keeps, and clearing it",
            category: "Shell"
        },
        {
            id: "dashboard",
            label: "Dashboard",
            icon: "\u{f056e}",
            description: "The panel under the bar clock: overview, system and more",
            category: "Shell"
        },
        {
            id: "power",
            label: "Power",
            icon: "\u{f0425}",
            description: "Power menu template, countdown and actions",
            category: "Shell"
        },
        {
            id: "notifications",
            label: "Notifications",
            icon: "\u{f009a}",
            description: "Popups, timeout and do not disturb",
            category: "Shell"
        },
        {
            id: "osd",
            label: "OSD",
            icon: "\u{f10a9}",
            description: "Volume and brightness indicator: style, position and when it shows",
            category: "Shell"
        },
        {
            id: "screenshot",
            label: "Screenshot",
            icon: "\u{f0e51}",
            description: "Capture overlay: opening mode, dimming and guides. Opens with Print",
            category: "Shell"
        },
        {
            id: "windows",
            label: "Windows",
            icon: "\u{f05b2}",
            description: "Gaps, borders, tiling and effects. Saved to hypr/local/settings.lua",
            category: "Hyprland"
        },
        {
            id: "input",
            label: "Input",
            icon: "\u{f037d}",
            description: "Mouse and touchpad. Saved to hypr/local/settings.lua",
            category: "Hyprland"
        },
        {
            id: "keyboard",
            label: "Keyboard",
            icon: "\u{f0313}",
            description: "Layouts, Caps Lock, Compose and key repeat",
            category: "Hyprland"
        },
        {
            id: "specials",
            label: "Specials",
            icon: "\u{f0018}",
            description: "Hidden app workspaces toggled with a shortcut, like WhatsApp and music",
            category: "Hyprland"
        },
        {
            id: "monitors",
            label: "Monitors",
            icon: "\u{f0379}",
            description: "Resolution, refresh rate, scale, rotation and layout of each monitor, tried before they're kept",
            category: "Hyprland"
        },
        {
            id: "graphics",
            label: "Graphics",
            icon: "\u{f08ae}",
            description: "Your GPUs, which one renders Hyprland, their links and the NVIDIA driver",
            category: "Hyprland"
        },
        {
            id: "workspaces",
            label: "Workspaces",
            icon: "\u{f0570}",
            description: "Each monitor's own workspaces, their order, next/previous and the laptop lid",
            category: "Hyprland"
        },
        {
            id: "keybinds",
            label: "Keybinds",
            icon: "\u{f030c}",
            description: "Change, disable or add shortcuts. Saved to hypr/local/settings.lua",
            category: "Hyprland"
        },
        {
            id: "lock",
            label: "Lock screen",
            icon: "\u{f033e}",
            description: "Lock screen template, what it shows and locking before sleep",
            category: "System"
        },
        {
            id: "idle",
            label: "Idle",
            icon: "\u{f04b2}",
            description: "Screen lock, screen off and what keeps the system awake",
            category: "System"
        },
        {
            id: "brightness",
            label: "Brightness",
            icon: "\u{f00df}",
            description: "Brightness keys and external monitors over DDC/CI",
            category: "System"
        },
        {
            id: "apps",
            label: "Apps",
            icon: "\u{f003b}",
            description: "Default terminal, file manager, browser and editor, and their shortcuts",
            category: "System"
        },
        {
            id: "autostart",
            label: "Autostart",
            icon: "\u{f14de}",
            description: "Apps and scripts started when you log in",
            category: "System"
        },
        {
            id: "profile",
            label: "Profile & Region",
            icon: "\u{f0009}",
            description: "Profile picture, weather location and AUR helper",
            category: "System"
        },
        {
            id: "about",
            label: "About",
            icon: "\u{f02fd}",
            description: "Dotfiles version, updates and system information",
            category: "System"
        }
    ]

    readonly property var currentEntry: pages.find(p => p.id === currentPage) ?? pages[0]
    // Page ids in sidebar order (grouped by category)
    readonly property var pageOrder: categories.reduce((ids, c) => ids.concat(pages.filter(p => p.category === c).map(p => p.id)), [])

    function stepPage(delta: int) {
        const i = pageOrder.indexOf(currentEntry.id);
        currentPage = pageOrder[(i + delta + pageOrder.length) % pageOrder.length];
    }

    // ================= SEARCH =================
    // Every page, group and row, read from the pages' QML source instead of
    // instantiating them: label/title/description given as plain strings.
    // Rows built from models (keybinds, specials) aren't in it
    property var searchIndex: []
    property bool indexing: false
    // Row (or group) the Settings window scrolls to and flashes once the
    // page shows: { page, group, label }
    property var pendingReveal: null

    signal revealRequested

    readonly property var rowTypes: ["SettingRow", "ToggleRow", "SliderRow", "StepperRow", "SelectRow", "TextFieldRow", "InfoRow", "TemplatePicker", "ColorEditRow"]
    readonly property string pagesDir: Qt.resolvedUrl("../modules/settings/pages/").toString().replace("file://", "")

    function pageFile(id: string): string {
        return id.charAt(0).toUpperCase() + id.slice(1) + "Page.qml";
    }

    function buildIndex() {
        if (indexing || searchIndex.length > 0)
            return;
        indexing = true;
        indexProc.command = ["sh", "-c", 'for f in "$@"; do printf "\\n@@FILE %s\\n" "$f"; cat "$f"; done', "sh"].concat(pages.map(p => pagesDir + pageFile(p.id)));
        indexProc.running = true;
    }

    // Walks the QML line by line with a stack of the objects opened by
    // braces; a property belongs to the innermost one, so the `label` of a
    // JS option object ({ label, value }) never counts as a row
    function parsePage(page: var, text: string): var {
        const out = [];
        const stack = [];
        const unescape = t => t.replace(/\\(.)/g, "$1");
        const groupOf = () => {
            for (let i = stack.length - 1; i >= 0; i--) {
                if (stack[i].type === "SettingsGroup")
                    return stack[i].props.title?.text ?? "";
            }
            return "";
        };
        const finish = e => {
            const label = e.props.label?.text ?? e.props.title?.text ?? "";
            if (label === "")
                return;
            const isRow = rowTypes.includes(e.type);
            if (!isRow && e.type !== "SettingsGroup")
                return;
            out.push({
                kind: isRow ? "row" : "group",
                page: page.id,
                pageLabel: page.label,
                icon: page.icon,
                group: isRow ? groupOf() : "",
                label: label,
                description: e.props.description?.text ?? "",
                words: e.props.description?.words ?? ""
            });
        };

        for (const raw of text.split("\n")) {
            const literals = [];
            const code = raw.replace(/"((?:[^"\\]|\\.)*)"/g, (m, g) => {
                literals.push(unescape(g));
                return '""';
            }).replace(/\/\/.*$/, "");
            const prop = code.match(/^\s*(label|title|description)\s*:\s*(.*)$/);
            if (prop && stack.length > 0 && stack[stack.length - 1].type !== "") {
                const pure = prop[2].trim() === '""' && literals.length === 1;
                stack[stack.length - 1].props[prop[1]] = {
                    text: pure ? literals[0] : "",
                    words: literals.join(" ")
                };
            }
            const type = code.match(/^\s*([A-Z]\w*)\s*\{/);
            let opened = false;
            for (const ch of code) {
                if (ch === "{") {
                    stack.push({
                        type: type && !opened ? type[1] : "",
                        props: {}
                    });
                    opened = true;
                } else if (ch === "}") {
                    const e = stack.pop();
                    if (e)
                        finish(e);
                }
            }
        }
        return out;
    }

    function parseIndex(text: string) {
        const byFile = {};
        for (const chunk of text.split("\n@@FILE ").slice(1)) {
            const nl = chunk.indexOf("\n");
            byFile[chunk.slice(0, nl)] = chunk.slice(nl + 1);
        }
        let index = [];
        for (const page of pages) {
            index.push({
                kind: "page",
                page: page.id,
                pageLabel: page.label,
                icon: page.icon,
                group: "",
                label: page.label,
                description: page.description,
                words: page.description + " " + page.category
            });
            index = index.concat(parsePage(page, byFile[pagesDir + pageFile(page.id)] ?? ""));
        }
        searchIndex = index;
    }

    // Entries matching every word of the query, best first: label matches
    // before description ones, pages and groups before rows on a tie
    function search(query: string): var {
        const q = query.trim().toLowerCase();
        if (q === "")
            return [];
        const words = q.split(/\s+/);
        const scored = [];
        searchIndex.forEach((e, i) => {
            const label = e.label.toLowerCase();
            const hay = (e.label + " " + e.group + " " + e.pageLabel + " " + e.words).toLowerCase();
            if (!words.every(w => hay.includes(w)))
                return;
            let score = e.kind === "page" ? 3 : e.kind === "group" ? 2 : 0;
            if (label === q)
                score += 100;
            else if (label.startsWith(q))
                score += 80;
            else if (label.includes(q))
                score += 60;
            else if (words.every(w => label.includes(w)))
                score += 40;
            else if (words.every(w => (e.group + " " + e.pageLabel).toLowerCase().includes(w)))
                score += 20;
            scored.push({
                e: e,
                score: score,
                i: i
            });
        });
        scored.sort((a, b) => b.score - a.score || a.i - b.i);
        return scored.slice(0, 50).map(r => r.e);
    }

    // Opens the entry's page; the window scrolls to the row and flashes it
    function reveal(entry: var) {
        pendingReveal = entry.kind === "page" ? null : {
            page: entry.page,
            group: entry.group !== "" ? entry.group : (entry.kind === "group" ? entry.label : ""),
            label: entry.kind === "row" ? entry.label : ""
        };
        if (currentPage === entry.page) {
            if (pendingReveal)
                revealRequested();
        } else {
            currentPage = entry.page;
        }
    }

    Process {
        id: indexProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseIndex(text);
                root.indexing = false;
            }
        }
    }

    function open(page: string) {
        if (page && pages.some(p => p.id === page))
            currentPage = page;
        visible = true;
    }

    function close() {
        visible = false;
    }

    function toggle() {
        visible = !visible;
    }

    IpcHandler {
        target: "settings"

        function open(page: string): void {
            root.open(page);
        }

        function toggle(): void {
            root.toggle();
        }

        function close(): void {
            root.close();
        }
    }
}
