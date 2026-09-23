pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

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

    property real brightness: 1.0
    property int maxBrightness: 100
    property int currentBrightness: 100
    readonly property bool available: backlightDevice !== ""
    property string backlightDevice: ""
    readonly property int percentage: Math.round(brightness * 100)

    readonly property string icon: {
        if (brightness <= 0.1)
            return "󰃞";
        if (brightness <= 0.3)
            return "󰃟";
        if (brightness <= 0.6)
            return "󰃝";
        return "󰃠";
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
    // BACKLIGHT DETECTION
    // ========================================================================

    Process {
        id: detectBacklight
        command: ["bash", "-c", "ls /sys/class/backlight/ 2>/dev/null | head -1"]
        stdout: SplitParser {
            onRead: data => {
                const device = data.trim();
                if (device !== "") {
                    root.backlightDevice = device;
                    getMaxBrightness.running = true;
                }
            }
        }
    }

    Process {
        id: getMaxBrightness
        command: ["bash", "-c", "cat /sys/class/backlight/" + root.backlightDevice + "/max_brightness 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                const max = parseInt(data.trim());
                if (!isNaN(max) && max > 0) {
                    root.maxBrightness = max;
                    getCurrentBrightness.running = true;
                }
            }
        }
    }

    Process {
        id: getCurrentBrightness
        command: ["bash", "-c", "cat /sys/class/backlight/" + root.backlightDevice + "/brightness 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                const current = parseInt(data.trim());
                if (!isNaN(current)) {
                    root.currentBrightness = current;
                    root.brightness = current / root.maxBrightness;
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: root.available
        repeat: true
        onTriggered: getCurrentBrightness.running = true
    }

    // ========================================================================
    // PUBLIC FUNCTIONS - BRIGHTNESS
    // ========================================================================

    function setBrightness(value: real) {
        const clamped = Math.max(0.05, Math.min(1.0, value));
        const absoluteValue = Math.round(clamped * maxBrightness);

        root.brightness = clamped;
        root.currentBrightness = absoluteValue;

        setBrightnessProc.command = ["brightnessctl", "set", absoluteValue.toString()];
        setBrightnessProc.running = true;
    }

    function increaseBrightness() {
        setBrightness(brightness + 0.05);
    }

    function decreaseBrightness() {
        setBrightness(brightness - 0.05);
    }

    property real lastBrightness: 1.0

    function toggleBrightness() {
        if (brightness > 0.1) {
            lastBrightness = brightness;
            setBrightness(0.05);
        } else {
            setBrightness(lastBrightness);
        }
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
    // PROCESSES - BRIGHTNESS
    // ========================================================================

    Process {
        id: setBrightnessProc
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
