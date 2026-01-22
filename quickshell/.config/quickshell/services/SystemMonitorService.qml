pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ========================================================================
    // CPU PROPERTIES
    // ========================================================================

    readonly property int cpuUsage: internal.cpuUsage
    readonly property int cpuTemp: internal.cpuTemp
    readonly property string cpuIcon: "󰻠"

    // ========================================================================
    // GPU PROPERTIES
    // ========================================================================

    readonly property int gpuUsage: internal.gpuUsage
    readonly property int gpuTemp: internal.gpuTemp
    readonly property string gpuIcon: "󰢮"
    readonly property string gpuType: internal.gpuType // "nvidia", "amd", "intel", "unknown"

    // ========================================================================
    // INTERNAL STATE
    // ========================================================================

    QtObject {
        id: internal

        property int cpuUsage: 0
        property int cpuTemp: 0
        property int gpuUsage: 0
        property int gpuTemp: 0
        property string gpuType: "unknown"

        // CPU calculation state
        property real prevTotal: 0
        property real prevIdle: 0
    }

    // ========================================================================
    // INITIALIZATION
    // ========================================================================

    Component.onCompleted: {
        detectGpu.running = true;
        updateCpuUsage.running = true;
        updateCpuTemp.running = true;
    }

    // ========================================================================
    // UPDATE TIMER
    // ========================================================================

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            updateCpuUsage.running = true;
            updateCpuTemp.running = true;

            if (internal.gpuType === "nvidia") {
                updateNvidiaGpu.running = true;
            } else if (internal.gpuType === "amd") {
                updateAmdGpuUsage.running = true;
                updateAmdGpuTemp.running = true;
            } else if (internal.gpuType === "intel") {
                updateIntelGpuTemp.running = true;
            }
        }
    }

    // ========================================================================
    // GPU DETECTION
    // ========================================================================

    Process {
        id: detectGpu
        command: ["bash", "-c", `
            if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
                echo "nvidia"
            elif [ -f /sys/class/drm/card0/device/gpu_busy_percent ] || [ -f /sys/class/drm/card1/device/gpu_busy_percent ]; then
                echo "amd"
            elif [ -d /sys/class/drm/card0/gt ] || ls /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1; then
                echo "intel"
            else
                echo "unknown"
            fi
        `]
        stdout: SplitParser {
            onRead: data => {
                const type = data.trim();
                internal.gpuType = type;
                console.log("[SystemMonitor] Detected GPU type:", type);

                // Trigger initial GPU update
                if (type === "nvidia") {
                    updateNvidiaGpu.running = true;
                } else if (type === "amd") {
                    updateAmdGpuUsage.running = true;
                    updateAmdGpuTemp.running = true;
                } else if (type === "intel") {
                    updateIntelGpuTemp.running = true;
                }
            }
        }
    }

    // ========================================================================
    // CPU MONITORING
    // ========================================================================

    Process {
        id: updateCpuUsage
        command: ["bash", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                // Format: cpu user nice system idle iowait irq softirq steal guest guest_nice
                const parts = data.trim().split(/\s+/);
                if (parts.length >= 5) {
                    const user = parseFloat(parts[1]) || 0;
                    const nice = parseFloat(parts[2]) || 0;
                    const system = parseFloat(parts[3]) || 0;
                    const idle = parseFloat(parts[4]) || 0;
                    const iowait = parseFloat(parts[5]) || 0;
                    const irq = parseFloat(parts[6]) || 0;
                    const softirq = parseFloat(parts[7]) || 0;
                    const steal = parseFloat(parts[8]) || 0;

                    const total = user + nice + system + idle + iowait + irq + softirq + steal;
                    const idleTime = idle + iowait;

                    if (internal.prevTotal > 0) {
                        const totalDiff = total - internal.prevTotal;
                        const idleDiff = idleTime - internal.prevIdle;

                        if (totalDiff > 0) {
                            const usage = Math.round(((totalDiff - idleDiff) / totalDiff) * 100);
                            internal.cpuUsage = Math.max(0, Math.min(100, usage));
                        }
                    }

                    internal.prevTotal = total;
                    internal.prevIdle = idleTime;
                }
            }
        }
    }

    Process {
        id: updateCpuTemp
        command: ["bash", "-c", `
            # Try different thermal zone sources
            for zone in /sys/class/thermal/thermal_zone*/temp; do
                type_file="\${zone%/temp}/type"
                if [ -f "$type_file" ]; then
                    type=$(cat "$type_file" 2>/dev/null)
                    if [[ "$type" == *"cpu"* ]] || [[ "$type" == *"x86_pkg"* ]] || [[ "$type" == *"coretemp"* ]]; then
                        cat "$zone" 2>/dev/null
                        exit 0
                    fi
                fi
            done
            # Fallback to first thermal zone
            cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0"
        `]
        stdout: SplitParser {
            onRead: data => {
                const temp = parseInt(data.trim());
                if (!isNaN(temp)) {
                    // Temperature is in millidegrees Celsius
                    internal.cpuTemp = Math.round(temp / 1000);
                }
            }
        }
    }

    // ========================================================================
    // NVIDIA GPU MONITORING
    // ========================================================================

    Process {
        id: updateNvidiaGpu
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(",").map(s => s.trim());
                if (parts.length >= 2) {
                    const usage = parseInt(parts[0]);
                    const temp = parseInt(parts[1]);

                    if (!isNaN(usage)) internal.gpuUsage = usage;
                    if (!isNaN(temp)) internal.gpuTemp = temp;
                }
            }
        }
    }

    // ========================================================================
    // AMD GPU MONITORING
    // ========================================================================

    Process {
        id: updateAmdGpuUsage
        command: ["bash", "-c", `
            for card in /sys/class/drm/card*/device/gpu_busy_percent; do
                if [ -f "$card" ]; then
                    cat "$card" 2>/dev/null
                    exit 0
                fi
            done
            echo "0"
        `]
        stdout: SplitParser {
            onRead: data => {
                const usage = parseInt(data.trim());
                if (!isNaN(usage)) {
                    internal.gpuUsage = usage;
                }
            }
        }
    }

    Process {
        id: updateAmdGpuTemp
        command: ["bash", "-c", `
            # Try to find AMD GPU temperature
            for hwmon in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do
                if [ -f "$hwmon" ]; then
                    cat "$hwmon" 2>/dev/null
                    exit 0
                fi
            done
            # Fallback to amdgpu specific path
            cat /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input 2>/dev/null || echo "0"
        `]
        stdout: SplitParser {
            onRead: data => {
                const temp = parseInt(data.trim());
                if (!isNaN(temp)) {
                    // Temperature is in millidegrees Celsius
                    internal.gpuTemp = Math.round(temp / 1000);
                }
            }
        }
    }

    // ========================================================================
    // INTEL GPU MONITORING
    // ========================================================================

    Process {
        id: updateIntelGpuTemp
        command: ["bash", "-c", `
            # Intel integrated GPUs share temp with CPU
            for zone in /sys/class/thermal/thermal_zone*/temp; do
                type_file="\${zone%/temp}/type"
                if [ -f "$type_file" ]; then
                    type=$(cat "$type_file" 2>/dev/null)
                    if [[ "$type" == *"gpu"* ]] || [[ "$type" == *"pch"* ]]; then
                        cat "$zone" 2>/dev/null
                        exit 0
                    fi
                fi
            done
            # Fallback - Intel iGPU shares temp with package
            cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0"
        `]
        stdout: SplitParser {
            onRead: data => {
                const temp = parseInt(data.trim());
                if (!isNaN(temp)) {
                    internal.gpuTemp = Math.round(temp / 1000);
                }
            }
        }
    }

    // ========================================================================
    // HELPER FUNCTIONS
    // ========================================================================

    function getUsageColor(usage: int): color {
        if (usage >= 90) return "#f7768e"; // error/red
        if (usage >= 70) return "#e0af68"; // warning/yellow
        return "#9ece6a"; // success/green
    }

    function getTempColor(temp: int): color {
        if (temp >= 85) return "#f7768e"; // error/red
        if (temp >= 70) return "#e0af68"; // warning/yellow
        return "#9ece6a"; // success/green
    }
}
