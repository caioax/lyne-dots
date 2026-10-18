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
// with the generation. Previews: the files a few icons of each theme come
// from (scripts/icon-preview.py), read again with the list. install() picks
// an archive with zenity and unpacks its themes into ~/.local/share/icons
// (icons_install in the lib); remove() deletes one of those families
Singleton {
    id: root

    readonly property string script: Qt.resolvedUrl("../scripts/icons.sh").toString().replace("file://", "")
    readonly property string installDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/icons"

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

    // Icons shown in the previews, as icon-preview.py names them; narrow
    // cards show the first ones
    readonly property var slots: ["folder", "terminal", "browser", "symbolic", "settings", "home"]
    // { theme id: { slot: file } }, for every family's themes
    property var previews: ({})

    property bool installing: false
    // Outcome of the last install or removal, for Settings: { ok, text }
    // (null until there's one)
    property var status: null
    // Ids just installed, for the status
    property var _installed: []

    // Grows each time the shell's own icons change theme
    property int generation: 0

    // The variant this shell shows (it starts with qt6ct's), "" until the
    // first apply
    property string _shown: ""
    property string _applied: ""
    property bool _pending: false
    property bool _refreshAgain: false
    property bool _previewsAgain: false

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

    // A preview icon of a theme as an image source, "" when it has none
    function previewUrl(id: string, slot: string): string {
        const file = previews[id]?.[slot] ?? "";
        return file === "" ? "" : "file://" + file.split("/").map(encodeURIComponent).join("/");
    }

    function install() {
        if (installProc.running)
            return;
        installing = true;
        status = null;
        installProc.running = true;
    }

    function remove(id: string) {
        if (id === theme || removeProc.running)
            return;
        removeProc.removing = nameOf(id);
        removeProc.command = [script, "remove", id];
        removeProc.running = true;
    }

    function openFolder() {
        Quickshell.execDetached(["bash", "-c", 'mkdir -p "$1" && xdg-open "$1"', "bash", installDir]);
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

    function _makePreviews() {
        if (previewProc.running) {
            _previewsAgain = true;
            return;
        }
        const ids = [];
        for (const t of themes)
            ids.push(t.path.split("/").pop(), t.dark, t.light);
        previewProc.command = [script, "preview"].concat(ids.filter(id => id !== ""));
        previewProc.running = true;
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
                root._makePreviews();
                if (root._installed.length > 0) {
                    // A family's variants come in as themes of their own
                    const names = [...new Set(root._installed.map(id => {
                            const family = root.themes.find(t => t.id === id || t.dark === id || t.light === id);
                            return family?.name ?? id;
                        }))];
                    root._installed = [];
                    root.status = {
                        ok: true,
                        text: names.length === 1 ? I18n.tr("Installed %1: pick it above", names[0]) : I18n.tr("Installed %1: pick one above", names.join(", "))
                    };
                }
                if (root._refreshAgain) {
                    root._refreshAgain = false;
                    Qt.callLater(root.refresh);
                }
            }
        }
    }

    // zenity's dialog texts come translated as $2..$5; the lib's lines
    // ("installed <id>", "updated <id>") on stdout, its exit code tells why
    // it failed
    Process {
        id: installProc

        property var lines: []

        command: ["bash", "-c", `
            if ! command -v zenity >/dev/null; then
                notify-send "$4" "$5"
                exit 10
            fi
            file=$(zenity --file-selection --title="$2" --filename="$HOME/" --file-filter="$3 | *.tar.gz *.tgz *.tar.xz *.txz *.tar.bz2 *.tar.zst *.tar *.zip *.7z") || exit 11
            "$1" install "$file"
        `, "bash", root.script, I18n.tr("Install an icon theme"), I18n.tr("Archives"), I18n.tr("Icons"), I18n.tr("Install zenity to pick a file")]
        stdout: SplitParser {
            onRead: data => installProc.lines.push(data.trim())
        }
        onStarted: lines = []
        onExited: code => {
            root.installing = false;
            switch (code) {
            case 0:
                // Said once the list is read again, with the themes' names
                root._installed = installProc.lines.map(l => l.split(" ").slice(1).join(" ")).filter(id => id !== "");
                break;
            case 2:
                root.status = {
                    ok: false,
                    text: I18n.tr("Couldn't open that file: use a .tar.gz, .tar.xz or .zip archive")
                };
                break;
            case 3:
                root.status = {
                    ok: false,
                    text: I18n.tr("No icon theme in that file (a folder with an index.theme that lists icons)")
                };
                break;
            case 4:
                root.status = {
                    ok: false,
                    text: I18n.tr("That file has a cursor theme: install it in Settings › %1", I18n.translate("Cursor"))
                };
                break;
            default:
                // Cancelled, or no zenity (it said so in a notification)
                break;
            }
            root.refresh();
        }
    }

    Process {
        id: removeProc

        property string removing: ""

        onExited: code => {
            root.status = code === 0 ? {
                ok: true,
                text: I18n.tr("Removed %1", removing)
            } : {
                ok: false,
                text: I18n.tr("Couldn't remove %1", removing)
            };
            root.refresh();
        }
    }

    Process {
        id: previewProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.previews = JSON.parse(text);
                } catch (e) {
                    root.previews = {};
                }
                if (root._previewsAgain) {
                    root._previewsAgain = false;
                    Qt.callLater(root._makePreviews);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("[Icons] previews:", text.trim());
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
