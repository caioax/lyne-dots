pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The icon theme (Settings › Icons; also `lyne icons`). The state keeps a
// family (Tela-blue, Papirus...): its -dark or -light variant follows the
// shell's theme (ThemeService.isDarkMode), a family without one uses its
// base theme. scripts/icons.sh (lyne's icons.sh lib) lists the families and
// writes the variant to GSettings, qt6ct/qt5ct, kdeglobals and the GTK
// settings.ini.
//
// Qt apps, this shell among them, read qt6ct's file again ~3 s after it
// changes, and KDE's icon engine (which draws their icons) only after
// KIconLoader's signal: the signal goes out after that, then `generation`
// grows. Icons already on screen stay in Qt's image cache under the same
// URL, so the shell's icon images take theirs from url(), which changes
// with the generation
Singleton {
    id: root

    readonly property string script: Qt.resolvedUrl("../scripts/icons.sh").toString().replace("file://", "")

    readonly property string theme: StateService.get("icons.theme", StateService.getDefault("icons.theme", "Tela-blue"))

    // Installed families: [{ id, name, path, dark, light, removable }],
    // sorted by name
    property var themes: []
    property bool loaded: false
    readonly property var current: themes.find(t => t.id === theme) ?? null
    // The saved theme isn't installed (apps fall back to another one)
    readonly property bool missing: loaded && current === null
    // The theme in use: the family's variant for the shell's mode
    readonly property string variant: variantOf(current, ThemeService.isDarkMode)

    // Grows each time the shell's own icons change theme
    property int generation: 0

    // The variant this shell shows (it starts with qt6ct's), "" until the
    // first apply
    property string _shown: ""
    property string _applied: ""
    property bool _pending: false
    property bool _refreshAgain: false

    onVariantChanged: applyDebounce.restart()

    function refresh() {
        if (listProc.running)
            _refreshAgain = true;
        else
            listProc.running = true;
    }

    function setTheme(id: string) {
        StateService.set("icons.theme", id);
    }

    function nameOf(id: string): string {
        return themes.find(t => t.id === id)?.name ?? id;
    }

    // A family's theme for a mode
    function variantOf(family: var, dark: bool): string {
        if (!family)
            return "";
        const base = family.path.split("/").pop();
        return (dark ? family.dark : family.light) || base;
    }

    // An icon of the theme as an image source: `fallback` when the theme
    // has no `name`, "" when neither is given. Use it instead of
    // "image://icon/…" and Quickshell.iconPath(), so the image loads again
    // when the theme changes
    function url(name: string, fallback: string): string {
        let icon = name ?? "";
        if (fallback && (icon === "" || !has(icon)))
            icon = fallback;
        return icon === "" ? "" : fresh("image://icon/" + icon);
    }

    // Whether the theme has an icon by that name (Quickshell.iconPath's
    // check), again after each theme change
    function has(name: string): bool {
        return generation >= 0 && name !== "" && Quickshell.iconPath(name, true) !== "";
    }

    // An image://icon/ source with the generation in it. Quickshell's icon
    // provider reads "?path=" as a folder to try when the theme has no such
    // icon; none exists there, so the result is the same, only the URL (Qt's
    // cache key) changes. Sources with their own query are left as is
    function fresh(source: string): string {
        if (generation === 0 || !source.startsWith("image://icon/") || source.includes("?"))
            return source;
        return source + "?path=lyne-icons-" + generation; // i18n-ignore
    }

    function apply() {
        if (StateService.isLoading || !loaded || variant === "" || variant === _applied)
            return;
        if (applyProc.running) {
            _pending = true;
            return;
        }
        _applied = variant;
        applyProc.command = [script, "apply", variant];
        applyProc.running = true;
    }

    Component.onCompleted: refresh()

    Connections {
        target: StateService

        function onStateLoaded() {
            applyDebounce.restart();
        }
    }

    // A theme switch moves the mode and maybe the family at once
    Timer {
        id: applyDebounce
        interval: 150
        onTriggered: root.apply()
    }

    // qt6ct reads its file again 3 s after it changes
    Timer {
        id: notifyTimer

        property string target: ""

        interval: 3500
        onTriggered: notifyProc.running = true
    }

    Process {
        id: listProc
        command: [root.script, "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.themes = JSON.parse(text);
                } catch (e) {
                    console.warn("[Icons] couldn't read the themes:", e);
                    root.themes = [];
                }
                root.loaded = true;
                applyDebounce.restart();
                if (root._refreshAgain) {
                    root._refreshAgain = false;
                    Qt.callLater(root.refresh);
                }
            }
        }
    }

    Process {
        id: applyProc

        property bool reload: false

        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "reload")
                    applyProc.reload = true;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("[Icons]", text.trim());
            }
        }
        onStarted: reload = false
        onExited: code => {
            const target = command[2];
            // The first apply: the shell started with qt6ct's theme, which
            // is this one unless the file just changed
            if (root._shown === "" && !reload)
                root._shown = target;
            if (code === 0 && (reload || target !== root._shown)) {
                notifyTimer.target = target;
                notifyTimer.restart();
            }
            if (root._pending) {
                root._pending = false;
                Qt.callLater(root.apply);
            }
        }
    }

    Process {
        id: notifyProc
        command: [root.script, "notify"]
        onExited: {
            root._shown = notifyTimer.target;
            root.generation++;
        }
    }
}
