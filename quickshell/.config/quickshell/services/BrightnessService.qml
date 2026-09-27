pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// Brightness per monitor (the laptop panel through brightnessctl, external
// monitors over DDC/CI through ddcutil) and night light (hyprsunset)
Singleton {
    id: root

    // Helper function to shorten the service call
    function getState(path, fallback) {
        return StateService.get(path, fallback);
    }
    function setState(path, value) {
        StateService.set(path, value);
    }

    // ========================================================================
    // PUBLIC PROPERTIES - BRIGHTNESS
    // ========================================================================

    // One Monitor per screen, in Quickshell.screens order
    readonly property list<QtObject> monitors: variants.instances
    readonly property var controllable: monitors.filter(m => m.available)
    readonly property bool available: controllable.length > 0
    readonly property var focused: monitorFor(Hyprland.focusedMonitor?.name ?? "")
    // What the keys adjust: the focused monitor, or the panel when it can't be
    // controlled (brightness.target "all": every controllable monitor)
    readonly property var primary: targets()[0] ?? null
    // Last monitor adjusted or changed from outside: what the OSD shows
    property var lastChanged: null
    readonly property var current: lastChanged ?? primary

    // sysfs device of the laptop panel ("" without one)
    property string backlightDevice: ""
    property int maxBrightness: 100
    // DRM connector -> I2C bus number, from `ddcutil detect`
    property var ddcBuses: ({})
    // ddcutil missing: external monitors have no control
    property bool ddcMissing: false
    property var _buses: ({})

    // A monitor's level changed (keys, sliders, or read from the hardware)
    signal levelChanged(var monitor)

    // md-brightness_5/6/7
    function iconFor(value: real): string {
        if (value < 0.3)
            return "\u{f00de}";
        if (value < 0.6)
            return "\u{f00df}";
        return "\u{f00e0}";
    }

    // ========================================================================
    // PUBLIC PROPERTIES - NIGHT LIGHT (HYPRSUNSET)
    // ========================================================================

    property bool nightLightEnabled: getState("nightLight.enabled", false)

    // Temperature in Kelvin (1000 = very warm/orange, 6500 = daylight)
    // Slider goes from 0.0 to 1.0, mapped to 2500K - 5500K
    property int nightLightTemperature: 4000

    // Intensity as a 0.0 - 1.0 value for the slider
    // 0.0 = warmer (2500K), 1.0 = cooler (5500K)
    property real nightLightIntensity: getState("nightLight.intensity", 0.5)

    // Night light icon
    readonly property string nightLightIcon: nightLightEnabled ? "󰌵" : "󰌶"

    // Temperature range the UI offers (Kelvin)
    readonly property int nightLightMin: 2500
    readonly property int nightLightMax: 5500

    // Approximate RGB of a black body at `kelvin` (Tanner Helland), used to
    // preview night light temperatures
    function temperatureColor(kelvin: real): color {
        const t = kelvin / 100;
        const clamp = v => Math.max(0, Math.min(255, v)) / 255;
        const r = t <= 66 ? 255 : 329.698727446 * Math.pow(t - 60, -0.1332047592);
        const g = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661 : 288.1221695283 * Math.pow(t - 60, -0.0755148492);
        const b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
        return Qt.rgba(clamp(r), clamp(g), clamp(b), 1);
    }

    // ========================================================================
    // INITIALIZATION
    // ========================================================================

    Component.onCompleted: {
        detectBacklight.running = true;
        root.detect();
        ensureHyprsunsetRunning.running = true;
    }

    // Connection with StateService to load persisted state
    Connections {
        target: StateService

        function onStateLoaded() {
            // Load night light state
            root.nightLightEnabled = root.getState("nightLight.enabled", false);
            root.nightLightIntensity = root.getState("nightLight.intensity", 0.5);
            root.updateTemperatureFromIntensity();

            console.log("[Brightness] Loaded state - enabled:", root.nightLightEnabled, "intensity:", root.nightLightIntensity);

            // Always apply the loaded state (enable or disable)
            applyStateTimer.restart();
        }
    }

    Timer {
        id: applyStateTimer
        interval: 1000
        onTriggered: {
            if (root.nightLightEnabled) {
                root.applyNightLight();
                return;
            }
            root.disableNightLight();
        }
    }

    // ========================================================================
    // INTERNAL FUNCTIONS
    // ========================================================================

    // Converts intensity (0-1) to Kelvin temperature
    function updateTemperatureFromIntensity() {
        // 0.0 = 2500K (very warm), 1.0 = 5500K (less warm)
        nightLightTemperature = Math.round(nightLightMin + nightLightIntensity * (nightLightMax - nightLightMin));
    }

    // Converts Kelvin temperature to intensity (0-1)
    function updateIntensityFromTemperature() {
        nightLightIntensity = (nightLightTemperature - nightLightMin) / (nightLightMax - nightLightMin);
    }

    // ========================================================================
    // PUBLIC FUNCTIONS - BRIGHTNESS
    // ========================================================================

    function monitorFor(name: string): var {
        return monitors.find(m => m.name === name) ?? null;
    }

    // "focused", a connector (HDMI-A-1) or a label (LG ULTRAGEAR, Built-in)
    function findMonitor(query: string): var {
        if (query === "" || query === "focused")
            return primary;
        return monitors.find(m => m.name === query || m.label === query) ?? null;
    }

    // Monitors the keys and the OSD wheel adjust
    function targets(): var {
        if (Config.brightnessTarget === "all")
            return controllable;
        if (focused?.available)
            return [focused];
        const fallback = monitors.find(m => m.method === "backlight") ?? controllable[0];
        return fallback ? [fallback] : [];
    }

    // Steps of brightness.step on the target monitors
    function adjust(steps: int) {
        const list = targets();
        list.forEach(m => m.set(m.brightness + Config.brightnessStep * steps));
        if (list.length > 0)
            lastChanged = list[0];
    }

    function increaseBrightness() {
        adjust(1);
    }

    function decreaseBrightness() {
        adjust(-1);
    }

    // Re-reads the external monitors (changes made on their own buttons)
    function refresh() {
        monitors.forEach(m => m.refresh());
    }

    // Looks for DDC/CI monitors again (hotplug, brightness.ddc turned on)
    function detect() {
        if (!Config.brightnessDdc || detectProc.running)
            return;
        // Detection probes every bus: wait for commands on their way
        if (monitors.some(m => m.proc.running)) {
            detectTimer.restart();
            return;
        }
        detectProc.running = true;
    }

    // qs ipc call brightness list | get <monitor> | set <monitor> <value>
    // Values like brightnessctl: 0.5, 50%, +5%, 5%-
    IpcHandler {
        target: "brightness"

        function list(): string {
            return root.monitors.map(m => `${m.name}\t${m.label}\t${m.method}${m.method === "ddc" ? " (bus " + m.bus + ")" : ""}\t${Math.round(m.brightness * 100)}%`).join("\n");
        }

        function get(monitor: string): string {
            const m = root.findMonitor(monitor);
            return m ? String(Math.round(m.brightness * 100)) : "Unknown monitor: " + monitor;
        }

        function set(monitor: string, value: string): string {
            const m = root.findMonitor(monitor);
            if (!m?.available)
                return m ? m.name + " has no brightness control" : "Unknown monitor: " + monitor;
            const match = value.match(/^([+]?)(\d*\.?\d+)(%?)(-?)$/);
            if (!match)
                return "Invalid value: " + value + " (0.5, 50%, +5%, 5%-)";
            const amount = parseFloat(match[2]) / (match[3] === "%" ? 100 : 1);
            const target = match[1] === "+" ? m.brightness + amount : match[4] === "-" ? m.brightness - amount : amount;
            m.set(target);
            root.lastChanged = m;
            return m.name + " set to " + Math.round(m.brightness * 100) + "%";
        }
    }

    // ========================================================================
    // MONITORS
    // ========================================================================

    Variants {
        id: variants
        model: Quickshell.screens

        Monitor {}
    }

    component Monitor: QtObject {
        id: monitor

        required property ShellScreen modelData
        readonly property string name: modelData.name
        readonly property bool internal: /^(eDP|LVDS|DSI)-/.test(name)
        readonly property string label: internal ? "Built-in" : (modelData.model || name)
        readonly property int bus: root.ddcBuses[name] ?? -1
        // "backlight" | "ddc" | "none"
        readonly property string method: {
            if (internal)
                return root.backlightDevice !== "" ? "backlight" : "none";
            return Config.brightnessDdc && bus >= 0 && !failed ? "ddc" : "none";
        }
        readonly property bool available: method !== "none"
        // The panel can go black at 0; monitors keep their own floor
        readonly property real minimum: method === "backlight" ? 0.05 : 0
        property real brightness: 1
        // First value read from the hardware
        property bool ready: false
        // DDC read failed before any success: treated as not controllable
        property bool failed: false
        property int ddcMax: 100

        // One command at a time per monitor: DDC buses don't take parallel
        // commands, and a Process must not be reused while it runs. While
        // one runs, the next write only replaces `_pending`, so dragging a
        // slider sends the latest value instead of a backlog
        property int _pending: -1
        property bool _readQueued: false
        // A write went out while a read ran: its result is stale
        property bool _stale: false
        property real _restore: 1
        // Reads that failed before the first success (the bus can be busy)
        property int _tries: 0
        // Last value written and its attempts: DDC writes can fail with EIO
        property int _written: -1
        property int _writeTries: 0

        function set(value: real) {
            if (!available)
                return;
            value = Math.max(minimum, Math.min(1, value));
            const raw = Math.round(value * (method === "ddc" ? ddcMax : root.maxBrightness));
            brightness = value;
            _pending = raw;
            _stale = true;
            _next();
        }

        // Icon click: dims to the minimum and back
        function toggle() {
            if (brightness > minimum + 0.05) {
                _restore = brightness;
                set(minimum);
            } else {
                set(_restore);
            }
        }

        function refresh() {
            // A queued write wins over what the monitor says now, and
            // detection holds the buses
            if (method !== "ddc" || _pending >= 0 || detectProc.running)
                return;
            _readQueued = true;
            _next();
        }

        function _next() {
            if (proc.running)
                return;
            if (_pending >= 0) {
                _writeTries = _pending === _written ? _writeTries + 1 : 1;
                _written = _pending;
                proc.command = method === "ddc" ? ["ddcutil", "-b", String(bus), "--noverify", "setvcp", "10", String(_pending)] : ["brightnessctl", "-q", "set", String(_pending)];
                _pending = -1;
                proc.running = true;
            } else if (_readQueued) {
                _readQueued = false;
                _stale = false;
                _written = -1;
                proc.command = ["ddcutil", "-b", String(bus), "getvcp", "10", "--brief"];
                proc.running = true;
            }
        }

        onBrightnessChanged: {
            if (ready)
                root.levelChanged(monitor);
        }

        readonly property Process proc: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    // "VCP 10 C <current> <max>"
                    const parts = text.trim().split(" ");
                    if (parts[0] !== "VCP" || parts[2] !== "C" || monitor._stale)
                        return;
                    const cur = parseInt(parts[3]);
                    const max = parseInt(parts[4]);
                    if (isNaN(cur) || !(max > 0))
                        return;
                    monitor.ddcMax = max;
                    monitor.brightness = cur / max;
                    monitor.ready = true;
                }
            }
            stderr: StdioCollector {
                id: errors
            }
            onExited: code => {
                // A failed write goes again unless a newer value is queued
                if (code === 0)
                    monitor._written = -1;
                else if (monitor._written >= 0 && monitor._pending < 0 && monitor._writeTries < 3)
                    monitor._pending = monitor._written;
                else if (code !== 0 && !monitor.ready && monitor.method === "ddc") {
                    if (++monitor._tries < 3) {
                        monitor.retry.restart();
                    } else {
                        console.warn("[Brightness] No DDC/CI answer from", monitor.name, "on bus", monitor.bus + ":", errors.text.trim());
                        monitor.failed = true;
                    }
                }
                monitor._next();
            }
        }

        readonly property Timer retry: Timer {
            interval: 1000
            onTriggered: monitor.refresh()
        }
    }

    // ========================================================================
    // DDC/CI DETECTION
    // ========================================================================

    Process {
        id: detectProc
        command: ["sh", "-c", "command -v ddcutil >/dev/null || exit 127; exec ddcutil detect --brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                const buses = {};
                // Blocks like "Display 1\n   I2C bus: /dev/i2c-13\n   DRM connector: card0-HDMI-A-1"
                // ("Invalid display" for panels without DDC/CI)
                text.trim().split("\n\n").filter(d => d.startsWith("Display ")).forEach(d => {
                    const bus = d.match(/I2C bus:\s*\/dev\/i2c-(\d+)/);
                    const connector = d.match(/DRM connector:\s*(\S+)/);
                    if (bus && connector)
                        buses[connector[1].replace(/^card\d+-/, "")] = parseInt(bus[1]);
                });
                root._buses = buses;
            }
        }
        onExited: code => {
            // Read only once ddcutil is gone: it holds the buses until then
            // A new detection gives monitors that failed another chance
            root.monitors.forEach(m => {
                m.failed = false;
                m._tries = 0;
            });
            root.ddcBuses = root._buses;
            root.refresh();
            root.ddcMissing = code === 127;
            if (root.ddcMissing)
                console.warn("[Brightness] ddcutil not found: external monitors have no brightness control");
        }
    }

    // Screens settle a moment after a hotplug before DDC answers
    Timer {
        id: detectTimer
        interval: 1500
        onTriggered: root.detect()
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            detectTimer.restart();
        }
    }

    Connections {
        target: Config

        function onBrightnessDdcChanged() {
            if (Config.brightnessDdc)
                root.detect();
        }
    }

    // Periodic re-read (brightness.pollInterval, 0 = never)
    Timer {
        interval: Math.max(1, Config.brightnessPollInterval) * 1000
        running: Config.brightnessPollInterval > 0 && root.monitors.some(m => m.method === "ddc")
        repeat: true
        onTriggered: root.refresh()
    }

    // And when a panel with brightness sliders opens
    property bool _panelOpen: WindowManagerService.activeModules["QuickSettings"] || WindowManagerService.activeModules["Dashboard"] || false
    on_PanelOpenChanged: {
        if (_panelOpen)
            refresh();
    }

    // ========================================================================
    // BACKLIGHT (LAPTOP PANEL)
    // ========================================================================

    Process {
        id: detectBacklight
        command: ["sh", "-c", "ls /sys/class/backlight/ 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root.backlightDevice = text.trim()
        }
    }

    FileView {
        id: maxBacklight
        path: root.backlightDevice !== "" ? "/sys/class/backlight/" + root.backlightDevice + "/max_brightness" : ""
        onLoaded: {
            const max = parseInt(text());
            if (max > 0)
                root.maxBrightness = max;
            backlight.reload();
        }
    }

    // sysfs sends no change events: polled
    FileView {
        id: backlight
        path: root.backlightDevice !== "" ? "/sys/class/backlight/" + root.backlightDevice + "/brightness" : ""
        onLoaded: {
            const panel = root.monitors.find(m => m.method === "backlight");
            const value = parseInt(text());
            // Skip while a write is on its way
            if (!panel || isNaN(value) || panel.proc.running || panel._pending >= 0)
                return;
            panel.brightness = value / root.maxBrightness;
            panel.ready = true;
        }
    }

    Timer {
        interval: 2000
        running: root.backlightDevice !== ""
        repeat: true
        onTriggered: backlight.reload()
    }

    // ========================================================================
    // PUBLIC FUNCTIONS - NIGHT LIGHT
    // ========================================================================

    function toggleNightLight() {
        if (nightLightEnabled) {
            disableNightLight();
        } else {
            enableNightLight();
        }
    }

    function enableNightLight() {
        nightLightEnabled = true;
        setState("nightLight.enabled", true);
        applyNightLight();
    }

    function disableNightLight() {
        nightLightEnabled = false;
        setState("nightLight.enabled", false);
        disableNightLightProc.running = true;
    }

    // Set the intensity and apply if active
    function setNightLightIntensity(intensity: real) {
        nightLightIntensity = Math.max(0.0, Math.min(1.0, intensity));
        updateTemperatureFromIntensity();
        setState("nightLight.intensity", nightLightIntensity);

        if (nightLightEnabled) {
            applyNightLight();
        }
    }

    function setNightLightTemperature(temp: int) {
        nightLightTemperature = Math.max(nightLightMin, Math.min(nightLightMax, temp));
        updateIntensityFromTemperature();
        setState("nightLight.intensity", nightLightIntensity);

        if (nightLightEnabled) {
            applyNightLight();
        }
    }

    // Apply the current temperature
    function applyNightLight() {
        enableNightLightProc.command = ["hyprctl", "hyprsunset", "temperature", nightLightTemperature.toString()];
        enableNightLightProc.running = true;
    }

    // ========================================================================
    // PROCESSES - NIGHT LIGHT (HYPRSUNSET)
    // ========================================================================

    Process {
        id: ensureHyprsunsetRunning
        command: ["bash", "-c", `
            if ! pgrep -x hyprsunset >/dev/null 2>&1; then
                hyprsunset &
                disown
                sleep 0.5
            fi
        `]
        onExited: {
            // hyprsunset is ready — apply state if already loaded
            if (!StateService.isLoading && root.nightLightEnabled) {
                root.applyNightLight();
            }
        }
    }

    Process {
        id: enableNightLightProc
        stdout: SplitParser {
            onRead: data => {
                console.log("[Brightness] Enable night light response:", data);
            }
        }
        stderr: SplitParser {
            onRead: data => {
                console.error("[Brightness] Enable night light error:", data);
                if (data.includes("error") || data.includes("failed")) {
                    restartAndEnableProc.running = true;
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                console.log("[Brightness] Night light enabled at", root.nightLightTemperature, "K");
            }
        }
    }

    Process {
        id: restartAndEnableProc
        command: ["bash", "-c", `
            pkill -x hyprsunset 2>/dev/null
            sleep 0.2
            hyprsunset &
            disown
            sleep 0.5
            hyprctl hyprsunset temperature ` + root.nightLightTemperature + `
        `]
    }

    Process {
        id: disableNightLightProc
        command: ["hyprctl", "hyprsunset", "identity"]
        onExited: (exitCode, exitStatus) => {
            console.log("[Brightness] Night light disabled");
        }
    }
}
