pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history from cliphist: data and actions only (the launcher's
// clipboard mode shows it). Read on demand, never polled.
//
// Each entry: { id, line, text, kind, format, size, width, height, color },
// newest first. `kind` is "image", "link", "color", "path" or "text"; the
// image fields are only set for images, `color` for colors
Singleton {
    id: root

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    property var entries: []
    property bool loaded: false
    // cliphist isn't installed
    property bool missing: false

    // Decoded images for the thumbnails, by entry id, once written
    property var thumbnails: ({})
    readonly property string thumbnailDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-clipboard"

    // Chars of each entry cliphist returns (its own default is 100)
    readonly property int previewWidth: 300

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    // Reads the history again; a call while reading runs once more after it
    function refresh() {
        if (listProc.running) {
            _refreshAgain = true;
            return;
        }
        listProc.running = true;
    }

    function copy(entry) {
        if (!entry)
            return;
        console.log("[Clipboard] Copying entry", entry.id);
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", entry.id]);
    }

    function remove(entry) {
        if (!entry)
            return;
        console.log("[Clipboard] Deleting entry", entry.id);
        // cliphist delete reads the whole list line from stdin
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", entry.line]);
        entries = entries.filter(e => e.id !== entry.id);
    }

    function wipe() {
        console.log("[Clipboard] Clearing the history");
        Quickshell.execDetached(["cliphist", "wipe"]);
        entries = [];
    }

    // Parses one `cliphist list` line ("id\tpreview")
    function parse(line: string): var {
        const tab = line.indexOf("\t");
        if (tab === -1)
            return null;
        const text = line.slice(tab + 1);
        const entry = {
            id: line.slice(0, tab),
            line: line,
            text: text,
            kind: "text"
        };

        // "[[ binary data 576 KiB png 1920x1080 ]]"
        const binary = text.match(/^\[\[ binary data (\S+ \S+) (\w+)(?: (\d+)x(\d+))? \]\]$/);
        if (binary) {
            entry.kind = "image";
            entry.size = binary[1];
            entry.format = binary[2];
            entry.width = Number(binary[3] ?? 0);
            entry.height = Number(binary[4] ?? 0);
        } else if (/^(https?|ftp):\/\/\S+$|^www\.\S+\.\S+$/i.test(text)) {
            entry.kind = "link";
        } else if (parseColor(text) !== null) {
            entry.kind = "color";
            entry.color = parseColor(text);
        } else if (/^(?:~|\/|file:\/\/)\S*$/.test(text)) {
            entry.kind = "path";
        }
        return entry;
    }

    // CSS color ("#rgb", "#rrggbbaa", "rgb(…)", "hsl(…)") as a QML color,
    // or null when the text isn't one
    function parseColor(text: string): var {
        const hex = text.match(/^#([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/i);
        if (hex) {
            let digits = hex[1];
            if (digits.length <= 4)
                digits = digits.split("").map(c => c + c).join("");
            const channel = i => parseInt(digits.slice(i, i + 2), 16) / 255;
            return Qt.rgba(channel(0), channel(2), channel(4), digits.length === 8 ? channel(6) : 1);
        }

        // Numbers split by commas, spaces or "/" (alpha), percents allowed
        const fn = text.match(/^(rgba?|hsla?)\(\s*([^)]*)\)$/i);
        if (!fn)
            return null;
        const parts = fn[2].split(/\s*[,\/]\s*|\s+/).filter(p => p !== "");
        if (parts.length < 3 || parts.length > 4 || parts.some(p => !/^-?[\d.]+(%|deg)?$/.test(p)))
            return null;
        const value = (p, scale) => p.endsWith("%") ? parseFloat(p) / 100 : parseFloat(p) / scale;
        const alpha = parts.length === 4 ? value(parts[3], 1) : 1;
        const clamp = v => Math.max(0, Math.min(1, v));
        if (fn[1].toLowerCase().startsWith("rgb"))
            return Qt.rgba(clamp(value(parts[0], 255)), clamp(value(parts[1], 255)), clamp(value(parts[2], 255)), clamp(alpha));
        const hue = ((parseFloat(parts[0]) % 360) + 360) % 360 / 360;
        return Qt.hsla(hue, clamp(value(parts[1], 100)), clamp(value(parts[2], 100)), clamp(alpha));
    }

    // ========================================================================
    // INTERNALS
    // ========================================================================

    property bool _refreshAgain: false

    Process {
        id: listProc

        // 127 = cliphist isn't installed
        command: ["sh", "-c", "command -v cliphist >/dev/null || exit 127; cliphist -preview-width " + root.previewWidth + " list"]

        stdout: StdioCollector {
            id: listOut
        }

        onExited: code => {
            root.missing = code === 127;
            if (code === 0)
                root.entries = listOut.text.split("\n").map(line => root.parse(line)).filter(e => e !== null);
            else if (!root.missing)
                console.error("[Clipboard] cliphist list failed, exit code:", code);
            root.loaded = true;

            if (root._refreshAgain) {
                root._refreshAgain = false;
                root.refresh();
                return;
            }
            root._decodeThumbnails();
        }
    }

    // Writes each image not decoded yet to thumbnailDir and drops the files
    // of entries gone from the history
    function _decodeThumbnails() {
        const ids = entries.filter(e => e.kind === "image").map(e => e.id);
        if (thumbProc.running)
            return;
        thumbProc.ids = ids;
        thumbProc.running = true;
    }

    Process {
        id: thumbProc

        property var ids: []

        command: ["sh", "-c", `
            dir="$1"; shift
            mkdir -p "$dir"
            for f in "$dir"/*; do
                [ -e "$f" ] || continue
                id="\${f##*/}"
                case " $* " in *" $id "*) ;; *) rm -f "$f" ;; esac
            done
            for id in "$@"; do
                [ -s "$dir/$id" ] || cliphist decode "$id" > "$dir/$id"
                echo "$id"
            done
        `, "sh", root.thumbnailDir, ...ids]

        stdout: StdioCollector {
            id: thumbOut
        }

        onExited: {
            const map = {};
            for (const id of thumbOut.text.split("\n"))
                if (id !== "")
                    map[id] = "file://" + root.thumbnailDir + "/" + id;
            root.thumbnails = map;
        }
    }
}
