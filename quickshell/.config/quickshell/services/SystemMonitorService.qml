pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    // ========================================================================
    // SETTINGS
    // ========================================================================

    readonly property int interval: 2000
    readonly property int historyLength: 60 // samples (2 minutes at 2s)

    // Expensive collectors (GPU, disk) only run while at least one
    // monitor popup is open. Popups call acquire()/release() on visibility.
    property int _watchers: 0
    readonly property bool detailed: _watchers > 0

    function acquire() {
        _watchers++;
    }

    function release() {
        _watchers = Math.max(0, _watchers - 1);
    }

    onDetailedChanged: {
        if (!detailed) {
            // Samples taken minutes apart would render as a continuous line / a
            // long-window CPU average, so start fresh on the next open
            gpuHistory = [];
            return;
        }
        updateDisk.running = true;
        root._pollDetailed();
    }

    // ========================================================================
    // SYSTEM INFO
    // ========================================================================

    readonly property string hostname: hostnameFile.text().trim()
    readonly property string kernel: kernelFile.text().trim()
    property string uptime: "0m" // e.g. "2d 5h" or "3h 12m"

    // ========================================================================
    // CPU
    // ========================================================================

    readonly property string cpuIcon: "󰻠"
    property string cpuName: ""
    property int cpuUsage: 0
    property int cpuTemp: 0
    property var coreUsages: []   // per-thread usage, 0-100
    property real cpuFreq: 0      // GHz (average over all threads)
    property real loadAvg: 0
    property var cpuHistory: []

    // ========================================================================
    // GPU
    // ========================================================================

    readonly property string gpuIcon: "󰢮"
    property string gpuType: "unknown" // "nvidia", "amd", "intel", "unknown"
    property string gpuName: ""
    property bool gpuSleeping: false   // dGPU runtime-suspended (we don't wake it)
    property int gpuUsage: 0
    property int gpuTemp: 0
    property real gpuMemUsed: 0        // bytes
    property real gpuMemTotal: 0       // bytes
    property real gpuPower: -1         // watts, -1 when unavailable
    property var gpuHistory: []

    // ========================================================================
    // MEMORY
    // ========================================================================

    property int memUsage: 0
    property real memUsed: 0     // bytes
    property real memTotal: 0    // bytes
    property real swapUsed: 0    // bytes
    property real swapTotal: 0   // bytes
    property var memHistory: []

    // ========================================================================
    // DISK
    // ========================================================================

    property var disks: [] // [{ mount, used, total, usage }]

    // ========================================================================
    // NETWORK
    // ========================================================================

    property string netInterface: ""
    property real netDown: 0      // bytes/s
    property real netUp: 0        // bytes/s
    property real netDownTotal: 0 // bytes since shell start
    property real netUpTotal: 0
    property var netDownHistory: []
    property var netUpHistory: []

    // ========================================================================
    // HELPERS
    // ========================================================================

    function formatBytes(bytes) {
        if (bytes >= 1099511627776)
            return (bytes / 1099511627776).toFixed(1) + " TiB";
        if (bytes >= 1073741824)
            return (bytes / 1073741824).toFixed(1) + " GiB";
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(0) + " MiB";
        if (bytes >= 1024)
            return (bytes / 1024).toFixed(0) + " KiB";
        return Math.round(bytes) + " B";
    }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec >= 1048576)
            return (bytesPerSec / 1048576).toFixed(1) + " MB/s";
        if (bytesPerSec >= 1024)
            return (bytesPerSec / 1024).toFixed(0) + " KB/s";
        return Math.round(bytesPerSec) + " B/s";
    }

    function formatGiB(bytes) {
        return (bytes / 1073741824).toFixed(1);
    }

    function usageColor(usage) {
        if (usage >= 90)
            return Config.errorColor;
        if (usage >= 70)
            return Config.warningColor;
        return Config.accentColor;
    }

    function tempColor(temp) {
        if (temp >= 85)
            return Config.errorColor;
        if (temp >= 70)
            return Config.warningColor;
        return Config.successColor;
    }

    function _push(history, value) {
        const next = history.length >= historyLength ? history.slice(1) : history.slice();
        next.push(value);
        return next;
    }

    function _cleanCpuName(name) {
        // "11th Gen Intel(R) Core(TM) i7-11800H @ 2.30GHz" -> "Core i7-11800H"
        // "AMD Ryzen 7 5800X 8-Core Processor"              -> "Ryzen 7 5800X"
        return name.replace(/\(R\)|\(TM\)|\bCPU\b|@.*$|\d+-Core Processor/gi, "").replace(/^\d+\w\w Gen /i, "").replace(/^(Intel|AMD)\s+/i, "").replace(/\s+/g, " ").trim();
    }

    // ========================================================================
    // INTERNAL STATE
    // ========================================================================

    QtObject {
        id: internal

        property var prevCpu: []          // [{ total, idle }] index 0 = aggregate
        property real prevRx: -1
        property real prevTx: -1
        property real prevNetTime: 0

        // Sensor paths resolved at startup
        property string cpuTempPath: ""
        property string nvidiaPciPath: ""
        property string amdBusyPath: ""
        property string amdTempPath: ""
        property string amdVramUsedPath: ""
        property string amdVramTotalPath: ""
        property string intelFreqPath: ""
        property string intelFreqMaxPath: ""
    }

    // ========================================================================
    // TIMERS
    // ========================================================================

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            meminfoFile.reload();
            netFile.reload();
            uptimeFile.reload();
            if (internal.cpuTempPath !== "")
                cpuTempFile.reload();

            if (root.detailed)
                root._pollDetailed();
        }
    }

    Timer {
        interval: 30000
        running: root.detailed
        repeat: true
        onTriggered: updateDisk.running = true
    }

    function _pollDetailed() {
        cpuinfoFile.reload();
        loadavgFile.reload();

        switch (gpuType) {
        case "nvidia":
            if (internal.nvidiaPciPath !== "")
                nvidiaPowerFile.reload();
            else if (!updateNvidia.running)
                updateNvidia.running = true;
            break;
        case "amd":
            amdBusyFile.reload();
            amdTempFile.reload();
            amdVramUsedFile.reload();
            amdVramTotalFile.reload();
            break;
        case "intel":
            intelFreqFile.reload();
            intelFreqMaxFile.reload();
            break;
        }
    }

    // ========================================================================
    // HARDWARE DETECTION (runs once)
    // ========================================================================

    Process {
        running: true
        command: ["sh", "-c", `
            for h in /sys/class/hwmon/hwmon*; do
                case "$(cat "$h/name" 2>/dev/null)" in
                    coretemp|k10temp|zenpower|cpu_thermal) echo "cpuTemp=$h/temp1_input"; break ;;
                esac
            done
            for z in /sys/class/thermal/thermal_zone*; do
                case "$(cat "$z/type" 2>/dev/null)" in
                    x86_pkg_temp|TCPU|cpu*) echo "cpuTempFallback=$z/temp"; break ;;
                esac
            done

            if command -v nvidia-smi >/dev/null 2>&1; then
                echo "gpu=nvidia"
                for d in /sys/bus/pci/devices/*; do
                    [ "$(cat "$d/vendor" 2>/dev/null)" = "0x10de" ] || continue
                    case "$(cat "$d/class" 2>/dev/null)" in
                        0x03*) echo "nvidiaPci=$d"; break ;;
                    esac
                done
            elif busy=$(ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1) && [ -n "$busy" ]; then
                d=\${busy%/gpu_busy_percent}
                echo "gpu=amd"
                echo "amdBusy=$busy"
                echo "amdTemp=$(ls "$d"/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)"
                echo "amdVramUsed=$d/mem_info_vram_used"
                echo "amdVramTotal=$d/mem_info_vram_total"
                echo "gpuName=$(cat "$d/product_name" 2>/dev/null || echo "AMD Radeon")"
            elif freq=$(ls /sys/class/drm/card*/gt_act_freq_mhz 2>/dev/null | head -1) && [ -n "$freq" ]; then
                echo "gpu=intel"
                echo "intelFreq=$freq"
                echo "intelFreqMax=\${freq%/gt_act_freq_mhz}/gt_RP0_freq_mhz"
                echo "gpuName=Intel Graphics"
            fi
        `]
        stdout: SplitParser {
            onRead: line => {
                const i = line.indexOf("=");
                if (i < 0)
                    return;
                const key = line.slice(0, i);
                const value = line.slice(i + 1).trim();

                switch (key) {
                case "cpuTemp":
                    internal.cpuTempPath = value;
                    break;
                case "cpuTempFallback":
                    if (internal.cpuTempPath === "")
                        internal.cpuTempPath = value;
                    break;
                case "gpu":
                    root.gpuType = value;
                    console.log("[SystemMonitor] Detected GPU type:", value);
                    break;
                case "gpuName":
                    root.gpuName = value;
                    break;
                case "nvidiaPci":
                    internal.nvidiaPciPath = value;
                    break;
                case "amdBusy":
                    internal.amdBusyPath = value;
                    break;
                case "amdTemp":
                    internal.amdTempPath = value;
                    break;
                case "amdVramUsed":
                    internal.amdVramUsedPath = value;
                    break;
                case "amdVramTotal":
                    internal.amdVramTotalPath = value;
                    break;
                case "intelFreq":
                    internal.intelFreqPath = value;
                    break;
                case "intelFreqMax":
                    internal.intelFreqMaxPath = value;
                    break;
                }
            }
        }
    }

    // ========================================================================
    // STATIC FILES
    // ========================================================================

    FileView {
        id: hostnameFile
        path: "/proc/sys/kernel/hostname"
    }

    FileView {
        id: kernelFile
        path: "/proc/sys/kernel/osrelease"
    }

    // ========================================================================
    // CPU
    // ========================================================================

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const lines = text().split("\n");
            const prev = internal.prevCpu;
            const next = [];
            const usages = [];

            for (const line of lines) {
                if (!line.startsWith("cpu"))
                    break;
                const f = line.split(/\s+/);
                let total = 0;
                for (let i = 1; i <= 8; i++)
                    total += parseInt(f[i]) || 0;
                const idle = (parseInt(f[4]) || 0) + (parseInt(f[5]) || 0);
                const idx = next.length;
                next.push({ total, idle });

                const p = prev[idx];
                const dt = p ? total - p.total : 0;
                usages.push(dt > 0 ? Math.max(0, Math.min(100, Math.round((1 - (idle - p.idle) / dt) * 100))) : 0);
            }

            internal.prevCpu = next;
            if (prev.length === 0)
                return;

            root.cpuUsage = usages[0];
            root.coreUsages = usages.slice(1);
            root.cpuHistory = root._push(root.cpuHistory, usages[0]);
        }
    }

    FileView {
        id: cpuTempFile
        path: internal.cpuTempPath
        onLoaded: {
            const t = parseInt(text());
            if (!isNaN(t))
                root.cpuTemp = Math.round(t / 1000);
        }
    }

    FileView {
        id: cpuinfoFile
        path: "/proc/cpuinfo"
        onLoaded: {
            const data = text();
            if (root.cpuName === "") {
                const m = data.match(/^model name\s*:\s*(.+)$/m);
                if (m)
                    root.cpuName = root._cleanCpuName(m[1]);
            }
            const re = /^cpu MHz\s*:\s*([\d.]+)/gm;
            let sum = 0, count = 0, m;
            while ((m = re.exec(data)) !== null) {
                sum += parseFloat(m[1]);
                count++;
            }
            if (count > 0)
                root.cpuFreq = sum / count / 1000;
        }
    }

    FileView {
        id: loadavgFile
        path: "/proc/loadavg"
        onLoaded: root.loadAvg = parseFloat(text().split(" ")[0]) || 0
    }

    // ========================================================================
    // MEMORY
    // ========================================================================

    FileView {
        id: meminfoFile
        path: "/proc/meminfo"
        onLoaded: {
            const data = text();
            const kb = key => {
                const m = data.match(new RegExp("^" + key + ":\\s*(\\d+)", "m"));
                return m ? parseInt(m[1]) * 1024 : 0;
            };

            const total = kb("MemTotal");
            if (total <= 0)
                return;

            root.memTotal = total;
            root.memUsed = total - kb("MemAvailable");
            root.memUsage = Math.round(root.memUsed / total * 100);
            root.swapTotal = kb("SwapTotal");
            root.swapUsed = root.swapTotal - kb("SwapFree");
            root.memHistory = root._push(root.memHistory, root.memUsage);
        }
    }

    // ========================================================================
    // DISK
    // ========================================================================

    Process {
        id: updateDisk
        command: ["df", "-B1", "--output=source,target,size,used", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "squashfs"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Keep "/" plus "/home" when it lives on another device
                const rows = text.trim().split("\n").slice(1).map(l => l.trim().split(/\s+/));
                const rootFs = rows.find(r => r[1] === "/");
                const home = rows.find(r => r[1] === "/home");
                const result = [];

                for (const r of [rootFs, home]) {
                    if (!r || (r === home && rootFs && home[0] === rootFs[0]))
                        continue;
                    const total = parseFloat(r[2]);
                    const used = parseFloat(r[3]);
                    if (total > 0)
                        result.push({ mount: r[1], used, total, usage: Math.round(used / total * 100) });
                }
                root.disks = result;
            }
        }
    }

    // ========================================================================
    // NETWORK
    // ========================================================================

    FileView {
        id: netFile
        path: "/proc/net/dev"
        onLoaded: {
            const now = Date.now();
            let rx = 0, tx = 0, busiest = "", busiestBytes = -1;

            for (const line of text().split("\n").slice(2)) {
                const sep = line.indexOf(":");
                if (sep < 0)
                    continue;
                const name = line.slice(0, sep).trim();
                if (/^(lo|docker|veth|br-|virbr|vnet)/.test(name))
                    continue;
                const f = line.slice(sep + 1).trim().split(/\s+/);
                const r = parseFloat(f[0]) || 0;
                const t = parseFloat(f[8]) || 0;
                rx += r;
                tx += t;
                if (r + t > busiestBytes) {
                    busiestBytes = r + t;
                    busiest = name;
                }
            }

            root.netInterface = busiest;

            if (internal.prevRx >= 0) {
                const secs = Math.max(0.001, (now - internal.prevNetTime) / 1000);
                const dRx = Math.max(0, rx - internal.prevRx);
                const dTx = Math.max(0, tx - internal.prevTx);
                root.netDown = dRx / secs;
                root.netUp = dTx / secs;
                root.netDownTotal += dRx;
                root.netUpTotal += dTx;
                root.netDownHistory = root._push(root.netDownHistory, root.netDown);
                root.netUpHistory = root._push(root.netUpHistory, root.netUp);
            }

            internal.prevRx = rx;
            internal.prevTx = tx;
            internal.prevNetTime = now;
        }
    }

    // ========================================================================
    // UPTIME
    // ========================================================================

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: {
            const total = parseInt(text());
            if (isNaN(total))
                return;

            const days = Math.floor(total / 86400);
            const hours = Math.floor((total % 86400) / 3600);
            const minutes = Math.floor((total % 3600) / 60);

            if (days > 0)
                root.uptime = days + "d " + hours + "h";
            else if (hours > 0)
                root.uptime = hours + "h " + minutes + "m";
            else
                root.uptime = minutes + "m";
        }
    }

    // ========================================================================
    // NVIDIA
    // ========================================================================

    // Reading runtime_status doesn't wake the card; nvidia-smi would, so we only
    // query it when the dGPU is already awake.
    FileView {
        id: nvidiaPowerFile
        path: internal.nvidiaPciPath !== "" ? internal.nvidiaPciPath + "/power/runtime_status" : ""
        onLoaded: {
            const status = text().trim();
            root.gpuSleeping = status === "suspended" || status === "suspending";
            if (root.gpuSleeping) {
                root.gpuUsage = 0;
                root.gpuHistory = root._push(root.gpuHistory, 0);
            } else if (!updateNvidia.running) {
                updateNvidia.running = true;
            }
        }
        onLoadFailed: {
            if (!updateNvidia.running)
                updateNvidia.running = true;
        }
    }

    Process {
        id: updateNvidia
        command: ["nvidia-smi", "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw", "--format=csv,noheader,nounits"]
        stdout: SplitParser {
            onRead: data => {
                const f = data.split(",").map(s => s.trim());
                if (f.length < 6)
                    return;

                root.gpuName = f[0].replace(/^NVIDIA\s+/, "").replace(/^GeForce\s+/, "");
                const usage = parseInt(f[1]);
                const temp = parseInt(f[2]);
                const power = parseFloat(f[5]);

                if (!isNaN(usage)) {
                    root.gpuUsage = usage;
                    root.gpuHistory = root._push(root.gpuHistory, usage);
                }
                if (!isNaN(temp))
                    root.gpuTemp = temp;
                root.gpuMemUsed = (parseFloat(f[3]) || 0) * 1048576;
                root.gpuMemTotal = (parseFloat(f[4]) || 0) * 1048576;
                root.gpuPower = isNaN(power) ? -1 : power;
            }
        }
    }

    // ========================================================================
    // AMD
    // ========================================================================

    FileView {
        id: amdBusyFile
        path: internal.amdBusyPath
        onLoaded: {
            const usage = parseInt(text());
            if (isNaN(usage))
                return;
            root.gpuUsage = usage;
            root.gpuHistory = root._push(root.gpuHistory, usage);
        }
    }

    FileView {
        id: amdTempFile
        path: internal.amdTempPath
        onLoaded: root.gpuTemp = Math.round((parseInt(text()) || 0) / 1000)
    }

    FileView {
        id: amdVramUsedFile
        path: internal.amdVramUsedPath
        onLoaded: root.gpuMemUsed = parseFloat(text()) || 0
    }

    FileView {
        id: amdVramTotalFile
        path: internal.amdVramTotalPath
        onLoaded: root.gpuMemTotal = parseFloat(text()) || 0
    }

    // ========================================================================
    // INTEL (no utilization counter without root; frequency is the best proxy)
    // ========================================================================

    FileView {
        id: intelFreqFile
        path: internal.intelFreqPath
    }

    FileView {
        id: intelFreqMaxFile
        path: internal.intelFreqMaxPath
        onLoaded: {
            const cur = parseInt(intelFreqFile.text());
            const max = parseInt(text());
            if (isNaN(cur) || !(max > 0))
                return;
            const usage = Math.round(cur / max * 100);
            root.gpuUsage = usage;
            root.gpuHistory = root._push(root.gpuHistory, usage);
        }
    }
}
