pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// GPUs and the order Hyprland uses them in, for Settings › Hyprland ›
// Graphics. scripts/gpus.sh reads them (lyne's gpus.sh, gpu-order.sh and
// nvidia.sh libs). The order lives in state.json (gpus.order: PCI
// addresses, first renders, [] = automatic) and is written to
// hypr/local/gpus.lua, which sets AQ_DRM_DEVICES when Hyprland starts: it
// applies at the next login. The udev links and the NVIDIA driver need
// sudo, so they run in a terminal (lyne gpu links, lyne nvidia install)
Singleton {
    id: root

    readonly property string script: Qt.resolvedUrl("../scripts/gpus.sh").toString().replace("file://", "")

    property var data: ({})
    property bool loading: false
    property bool loaded: false

    readonly property var gpus: data.gpus ?? []
    readonly property bool multi: data.multi ?? false
    readonly property bool hybrid: data.hybrid ?? false
    readonly property var nvidia: data.nvidia ?? null
    readonly property string rules: data.rules ?? "none"
    readonly property var duplicates: data.duplicates ?? []
    readonly property var otherAq: data.otherAq ?? []
    // What the running Hyprland uses (from its log; empty without one)
    readonly property var running: data.running ?? []
    readonly property bool runningExplicit: data.runningExplicit ?? false

    readonly property var savedOrder: StateService.get("gpus.order", [])
    // GPUs that can be ordered (virtual ones get no link)
    readonly property var linked: gpus.filter(g => g.link !== "")
    readonly property var igpu: linked.find(g => g.kind === "integrated") ?? null
    readonly property var dgpu: linked.find(g => g.kind === "dedicated") ?? null

    // The saved order as presets: which kind renders, and the other one used
    readonly property string renderer: savedOrder.length === 0 ? "auto" : (gpuAt(savedOrder[0])?.kind === "integrated" ? "igpu" : "dgpu")
    readonly property bool useOther: savedOrder.length !== 1
    // The GPUs that go dark at the next login with monitors plugged in
    readonly property var darkened: savedOrder.length === 0 ? [] : linked.filter(g => !savedOrder.includes(g.pci) && connected(g).length > 0)

    // The next login differs from now. Automatic = no explicit list
    readonly property bool pending: loaded && running.length > 0 && (savedOrder.length === 0 ? runningExplicit : (!runningExplicit || savedOrder.join(" ") !== running.join(" ")))
    // All links present, as the rules were written
    readonly property bool linksReady: rules === "ok" && linked.every(g => g.present)

    function gpuAt(pci: string): var {
        return gpus.find(g => g.pci === pci) ?? null;
    }

    function label(gpu: var): string {
        return gpu ? gpu.brand + " " + gpu.name : "";
    }

    function connected(gpu: var): var {
        return (gpu?.outputs ?? []).filter(o => o.connected).map(o => o.name);
    }

    // "integrated", "dedicated, Turing"
    function kindLabel(gpu: var): string {
        if (!gpu)
            return "";
        const arch = gpu.arch === "ada" ? "Ada Lovelace" : gpu.arch.charAt(0).toUpperCase() + gpu.arch.slice(1);
        return gpu.kind + (gpu.arch !== "" ? ", " + arch : "");
    }

    // "Intel renders, NVIDIA also used"
    function orderLabel(order: var): string {
        if (order.length === 0)
            return "Automatic (the GPU with the built-in screen renders)";
        const names = order.map(pci => gpuAt(pci)?.brand ?? pci);
        return names[0] + " renders" + (names.length > 1 ? ", " + names.slice(1).join(", ") + " also used" : " alone");
    }

    function refresh() {
        if (!jsonProc.running) {
            loading = true;
            jsonProc.running = true;
        }
    }

    function setOrder(order: var) {
        StateService.set("gpus.order", order);
        writeProc.command = [script, "write", ...order];
        writeProc.running = true;
    }

    // Hybrid presets: renderer igpu | dgpu | auto, and whether the other
    // GPUs stay in use (monitors plugged into them)
    function setPreset(which: string, other: bool) {
        if (which === "auto" || !igpu || !dgpu) {
            setOrder([]);
            return;
        }
        const first = which === "igpu" ? igpu : dgpu;
        const rest = linked.filter(g => g.pci !== first.pci).map(g => g.pci);
        setOrder(other ? [first.pci, ...rest] : [first.pci]);
    }

    // List mode (no integrated GPU): the order shown, saved GPUs first
    readonly property var listOrder: {
        const base = savedOrder.length > 0 ? savedOrder : (running.length > 0 ? running : linked.map(g => g.pci));
        const known = base.filter(pci => gpuAt(pci));
        return known.concat(linked.map(g => g.pci).filter(pci => !known.includes(pci)));
    }

    function move(pci: string, delta: int) {
        const order = listOrder.slice();
        const i = order.indexOf(pci);
        const j = i + delta;
        if (i < 0 || j < 0 || j >= order.length)
            return;
        order.splice(j, 0, order.splice(i, 1)[0]);
        const used = savedOrder.length > 0 ? savedOrder : order;
        setOrder(order.filter(p => used.includes(p)));
    }

    function setUsed(pci: string, used: bool) {
        const current = savedOrder.length > 0 ? savedOrder : listOrder;
        const next = listOrder.filter(p => p === pci ? used : current.includes(p));
        // Never an empty list: that means automatic
        if (next.length > 0)
            setOrder(next);
    }

    // sudo things run in the default terminal; the page refreshes after
    function inTerminal(command: string) {
        Quickshell.execDetached(AppsService.terminalArgv(["bash", "-c", command + '; echo; read -rsn1 -p "Press any key to close"']));
        refreshAfter.restart();
    }

    function logout() {
        PowerService.logout();
    }

    // gpus.lua written for another order (a failed write, state synced by
    // lyne update...): write it again
    function _syncLua() {
        if (!multi)
            return;
        const want = savedOrder.length === 0 ? "automatic" : savedOrder.join(" ");
        if ((data.luaOrder ?? "") !== want && !writeProc.running) {
            writeProc.command = [script, "write", ...savedOrder];
            writeProc.running = true;
        }
    }

    // Terminal commands take a while: look again a few times
    Timer {
        id: refreshAfter
        interval: 5000
        repeat: true
        property int left: 24
        onRunningChanged: if (running)
            left = 24
        onTriggered: {
            root.refresh();
            if (--left <= 0)
                stop();
        }
    }

    Process {
        id: jsonProc
        command: [root.script, "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.data = JSON.parse(text);
                    root.loaded = true;
                    root._syncLua();
                } catch (e) {
                    console.error("[GpuService] gpus.sh json:", e);
                }
                root.loading = false;
            }
        }
        onExited: code => {
            if (code !== 0)
                root.loading = false;
        }
    }

    Process {
        id: writeProc
        onExited: code => {
            if (code !== 0)
                console.error("[GpuService] gpus.sh write failed:", code);
            root.refresh();
        }
    }
}
