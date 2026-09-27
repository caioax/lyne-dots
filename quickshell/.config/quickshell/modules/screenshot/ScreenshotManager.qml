pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

Scope {
    id: root

    // =========================================================================
    // STATE
    // =========================================================================

    property bool active: false
    property string mode: "region"  // "region", "window", "screen"
    property bool editMode: false
    property string captureTimestamp: ""

    // Selection coordinates
    property real selectionX: 0
    property real selectionY: 0
    property real selectionWidth: 0
    property real selectionHeight: 0

    // Confirmation state
    property bool hasSelection: false

    // Window info
    property string selectedWindowTitle: ""
    property string selectedWindowClass: ""

    // Monitor tracking
    property var hyprlandMonitor: Hyprland.focusedMonitor
    property var activeScreen: null

    // IPC data (fresh on each capture)
    property var windowsFromIpc: []
    property var monitorsFromIpc: []
    // Global cursor position when the capture started
    property point cursorFromIpc: Qt.point(-1, -1)

    // Size in the monitor's own pixels, as it will be saved
    readonly property real monitorScale: root.hyprlandMonitor?.scale || 1
    readonly property int realWidth: Math.round(root.selectionWidth * root.monitorScale)
    readonly property int realHeight: Math.round(root.selectionHeight * root.monitorScale)
    // Enter / double click: a chosen selection, or the window under the mouse
    readonly property bool canConfirm: root.hasSelection || (root.mode === "window" && root.selectionWidth > 0)

    // Window rounding and border size from Hyprland, so a window selection
    // outlines the window like its own border. Regions and screens are cut
    // square, so they are drawn square
    property int hyprRounding: 0
    property int hyprBorderSize: 2
    readonly property int selectionRadius: root.mode === "window" ? root.hyprRounding : 0

    // Animations
    readonly property bool activeAnimations: Config.screenshotAnimations && root.active && root.mode !== "region"

    readonly property var modes: ["region", "window", "screen"]
    readonly property var modeIcons: ({
            region: "\u{f0a6d}",
            window: "\u{f05af}",
            screen: "\u{f0379}"
        })

    // =========================================================================
    // ANIMATIONS
    // =========================================================================

    Behavior on selectionX {
        enabled: root.activeAnimations
        NumberAnimation {
            duration: Config.animDurationLong
            easing.type: Easing.OutExpo
        }
    }
    Behavior on selectionY {
        enabled: root.activeAnimations
        NumberAnimation {
            duration: Config.animDurationLong
            easing.type: Easing.OutExpo
        }
    }
    Behavior on selectionWidth {
        enabled: root.activeAnimations
        NumberAnimation {
            duration: Config.animDurationLong
            easing.type: Easing.OutExpo
        }
    }
    Behavior on selectionHeight {
        enabled: root.activeAnimations
        NumberAnimation {
            duration: Config.animDurationLong
            easing.type: Easing.OutExpo
        }
    }

    // =========================================================================
    // IPC PROCESSES
    // =========================================================================

    // One hyprctl call; --batch separates the replies with two blank lines
    Process {
        id: hyprctlInfo
        command: ["hyprctl", "-j", "--batch", "monitors; clients; getoption decoration:rounding; getoption general:border_size; cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n\n\n").map(part => {
                    try {
                        return JSON.parse(part);
                    } catch (e) {
                        return null;
                    }
                });
                root.monitorsFromIpc = parts[0] ?? [];
                root.windowsFromIpc = parts[1] ?? [];
                root.hyprRounding = parts[2]?.int ?? 0;
                root.hyprBorderSize = parts[3]?.int ?? 2;
                root.cursorFromIpc = parts[4] ? Qt.point(parts[4].x, parts[4].y) : Qt.point(-1, -1);
                root.applyInitialMode();
                root.startGrimCapture();
            }
        }
    }

    Process {
        id: grimCapture
        onExited: root.active = true
    }

    // =========================================================================
    // PUBLIC FUNCTIONS
    // =========================================================================

    function startCapture() {
        prepareCapture();
        hyprctlInfo.running = true;
    }

    function tempPathForScreen(screenName: string): string {
        if (root.captureTimestamp === "")
            return "";
        return Quickshell.cachePath(`screenshot-${root.captureTimestamp}-${screenName}.png`);
    }

    function cleanupTempFiles() {
        const paths = root.monitorsFromIpc.map(m => tempPathForScreen(m.name));
        if (paths.length > 0)
            Quickshell.execDetached(["rm", "-f", ...paths]);
        root.captureTimestamp = "";
    }

    function cancelCapture() {
        root.hasSelection = false;
        cleanupTempFiles();
        root.active = false;
    }

    function resetSelection() {
        root.editMode = false;
        root.hasSelection = false;
        root.selectionX = 0;
        root.selectionY = 0;
        root.selectionWidth = 0;
        root.selectionHeight = 0;
        root.selectedWindowTitle = "";
        root.selectedWindowClass = "";
    }

    function setMode(newMode: string) {
        resetSelection();
        root.mode = newMode;

        if (newMode === "screen") {
            root.selectionX = 0;
            root.selectionY = 0;
            root.selectionWidth = root.activeScreen?.width || 1920;
            root.selectionHeight = root.activeScreen?.height || 1080;
            root.hasSelection = true;
            root.selectedWindowTitle = root.hyprlandMonitor?.name || "Monitor";
        }
    }

    // Region in overlay coordinates, kept on the screen; a drag past an edge
    // flips it instead of going negative
    function setRegion(left: real, top: real, right: real, bottom: real) {
        const w = root.activeScreen?.width ?? 0;
        const h = root.activeScreen?.height ?? 0;
        const l = Math.max(0, Math.min(left, right));
        const t = Math.max(0, Math.min(top, bottom));
        root.selectionX = l;
        root.selectionY = t;
        root.selectionWidth = Math.min(w, Math.max(left, right)) - l;
        root.selectionHeight = Math.min(h, Math.max(top, bottom)) - t;
    }

    // Moves the region, stopping at the screen edges
    function moveRegion(x: real, y: real) {
        const w = root.activeScreen?.width ?? 0;
        const h = root.activeScreen?.height ?? 0;
        root.selectionX = Math.max(0, Math.min(x, w - root.selectionWidth));
        root.selectionY = Math.max(0, Math.min(y, h - root.selectionHeight));
    }

    // Arrow keys: move by (dx, dy), or with `resize` grow the right and
    // bottom edges (at least 1px)
    function nudge(dx: int, dy: int, resize: bool) {
        if (root.mode !== "region" || !root.hasSelection)
            return;
        if (resize)
            setRegion(root.selectionX, root.selectionY, root.selectionX + Math.max(1, root.selectionWidth + dx), root.selectionY + Math.max(1, root.selectionHeight + dy));
        else
            moveRegion(root.selectionX + dx, root.selectionY + dy);
    }

    function confirmSelection() {
        if (root.mode === "window" && !root.hasSelection && root.selectionWidth <= 0)
            return;
        root.editMode = false;
        saveScreenshot(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight);
    }

    function editSelection() {
        root.editMode = true;
        saveScreenshot(root.selectionX, root.selectionY, root.selectionWidth, root.selectionHeight);
    }

    // Windows shown on a monitor, topmost first: an open special workspace
    // covers the regular one; then pinned, fullscreen and floating windows
    // are above tiled ones, and the most recently focused wins a tie
    function windowsOnScreen(screenName: string): var {
        const monitor = root.monitorsFromIpc.find(m => m.name === screenName);
        if (!monitor)
            return [];

        const specialId = monitor.specialWorkspace?.name ? monitor.specialWorkspace.id : null;
        const activeId = monitor.activeWorkspace?.id;
        const rank = win => [win.workspace?.id === specialId ? 0 : 1, win.pinned ? 0 : 1, win.fullscreen ? 0 : 1, win.floating ? 0 : 1, win.focusHistoryID ?? 0];

        return root.windowsFromIpc.filter(win => {
            if (!win?.at || !win?.size || win.hidden || win.mapped === false)
                return false;
            if (win.title === "" && win.class === "")
                return false;
            return win.workspace?.id === activeId || (specialId !== null && win.workspace?.id === specialId);
        }).sort((a, b) => {
            const ra = rank(a);
            const rb = rank(b);
            for (let i = 0; i < ra.length; i++)
                if (ra[i] !== rb[i])
                    return ra[i] - rb[i];
            return 0;
        }).map(win => ({
                    x: win.at[0] - monitor.x,
                    y: win.at[1] - monitor.y,
                    width: win.size[0],
                    height: win.size[1],
                    title: win.title || win.class || "Window",
                    windowClass: win.class || ""
                }));
    }

    function checkWindowAt(mouseX: real, mouseY: real, screenName: string) {
        const win = windowsOnScreen(screenName).find(w => mouseX >= w.x && mouseX <= w.x + w.width && mouseY >= w.y && mouseY <= w.y + w.height);
        if (!win) {
            resetSelection();
            return;
        }
        root.selectionX = win.x;
        root.selectionY = win.y;
        root.selectionWidth = win.width;
        root.selectionHeight = win.height;
        root.selectedWindowTitle = win.title;
        root.selectedWindowClass = win.windowClass;
    }

    // =========================================================================
    // PRIVATE FUNCTIONS
    // =========================================================================

    // Mode from Settings, ready before the overlay shows: the window under
    // the cursor, or the whole screen
    function applyInitialMode() {
        // Hyprland.focusedMonitor can still be empty right after a start:
        // take the focused monitor from the hyprctl reply
        const focused = root.monitorsFromIpc.find(m => m.focused);
        const screen = Quickshell.screens.find(s => s.name === focused?.name);
        if (screen) {
            root.activeScreen = screen;
            root.hyprlandMonitor = Hyprland.monitorFor(screen);
        }

        setMode(Config.screenshotMode);
        const monitor = root.monitorsFromIpc.find(m => m.name === root.activeScreen?.name);
        if (root.mode === "window" && monitor)
            checkWindowAt(root.cursorFromIpc.x - monitor.x, root.cursorFromIpc.y - monitor.y, monitor.name);
    }

    function prepareCapture() {
        root.mode = "region";
        resetSelection();
        root.activeScreen = null;

        const monitor = Hyprland.focusedMonitor;
        if (monitor) {
            for (const screen of Quickshell.screens) {
                if (screen.name === monitor.name) {
                    root.activeScreen = screen;
                    root.hyprlandMonitor = monitor;
                    break;
                }
            }
        }

        root.captureTimestamp = String(Date.now());
    }

    // Uncompressed PNGs (-l 0): the default compression takes ~1.5s per
    // monitor, this ~35ms, and the files are deleted after the crop anyway
    function startGrimCapture() {
        const args = [];
        for (const monitor of root.monitorsFromIpc)
            args.push(monitor.name, tempPathForScreen(monitor.name));
        grimCapture.command = ["sh", "-c", 'while [ $# -gt 0 ]; do grim -l 0 -o "$1" "$2" & shift 2; done; wait', "sh", ...args];
        grimCapture.running = true;
    }

    function saveScreenshot(x: real, y: real, width: real, height: real) {
        if (width < 5 || height < 5)
            return;

        // The capture of each monitor is in its own pixels
        const scale = root.hyprlandMonitor?.scale || 1;
        const sourcePath = tempPathForScreen(root.hyprlandMonitor?.name || "");
        const geometry = Math.round(width * scale) + "x" + Math.round(height * scale) + "+" + Math.round(x * scale) + "+" + Math.round(y * scale);
        const timestamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
        const tempFiles = root.monitorsFromIpc.map(m => tempPathForScreen(m.name));

        // $1 source, $2 crop geometry, $3 file name, $4 edit in satty, then
        // the temp files to delete. Saved to <XDG pictures dir>/Screenshots
        const script = `
            src="$1"; geometry="$2"; name="$3"; edit="$4"; shift 4
            trap 'rm -f "$@"' EXIT
            dir="$(xdg-user-dir PICTURES 2>/dev/null)"
            [ -n "$dir" ] && [ "$dir" != "$HOME" ] || dir="$HOME/Pictures"
            dir="$dir/Screenshots"
            out="$dir/$name"
            mkdir -p "$dir" || exit 1
            if [ "$edit" = 1 ]; then
                magick "$src" -crop "$geometry" +repage png:- | satty --filename - --output-filename "$out" --early-exit --init-tool brush --disable-notifications
            else
                magick "$src" -crop "$geometry" +repage "$out"
            fi
            [ -f "$out" ] || exit 1
            wl-copy --type image/png < "$out"
            notify-send -i accessories-screenshot -a "Screenshot" "Screenshot Saved!" "Path: $out"
        `;

        const edit = root.editMode;
        root.active = false;
        root.hasSelection = false;
        root.editMode = false;
        root.captureTimestamp = "";
        Quickshell.execDetached(["sh", "-c", script, "sh", sourcePath, geometry, `screenshot-${timestamp}.png`, edit ? "1" : "0", ...tempFiles]);
    }

    // =========================================================================
    // OVERLAY (loaded only when active)
    // =========================================================================

    Loader {
        active: root.active
        sourceComponent: Component {
            Variants {
                model: Quickshell.screens

                delegate: ScreenshotOverlay {
                    required property var modelData
                    screen: modelData
                    screenshot: root
                }
            }
        }
    }
}
