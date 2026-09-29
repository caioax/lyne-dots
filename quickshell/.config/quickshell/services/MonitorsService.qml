pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "monitors.js" as Lib

// Monitor rules edited in Settings › Hyprland › Monitors. state.json keeps
// them (monitors.rules, see monitors.js) and ~/.config/hypr/monitors.lua is
// generated from them. Applying first tries the rules live with `hyprctl
// eval` (the file stays as it was) and asks to keep them: keeping saves and
// writes the file, reverting (or no answer within trialSeconds) reloads the
// config, which brings the saved file back. A detached watcher reverts too,
// so a crash of the shell can't leave a black screen behind.
Singleton {
    id: root

    readonly property string script: Qt.resolvedUrl("../scripts/monitors.sh").toString().replace("file://", "")
    readonly property string filePath: Quickshell.env("HOME") + "/.config/hypr/monitors.lua"
    readonly property int trialSeconds: 15

    // hyprctl monitors all -j, without the FALLBACK and virtual outputs
    property var monitors: []
    property bool ready: false

    readonly property var savedRules: StateService.get("monitors.rules", [])
    readonly property string fileText: _fileText
    property string _fileText: ""
    // monitors.lua was written by this service (else by nwg-displays or by
    // hand: its rules can be imported)
    readonly property bool fileManaged: Lib.isManaged(_fileText)
    readonly property var fileRules: Lib.upgradeSelectors(Lib.importLua(_fileText), monitors)
    // What the editor starts from: the saved rules, or the file's before
    // anything was saved here
    readonly property var storedRules: savedRules.length > 0 || fileManaged ? savedRules : fileRules

    // Ports the lid logic turned off (conf/workspaces.lua): shown as off,
    // never edited or saved as disabled
    readonly property var lidOffNames: WorkspacesService.monitors.filter(m => m.lidOff === true).map(m => m.name)

    // Trial in progress: the rules being tried, what gets saved on keep
    property bool trialActive: false
    property int trialRemaining: 0
    property var _pendingRules: []
    // Ports connected when the trial started: a hotplug ends it
    property string _trialPorts: ""
    // Saved rules before a write, restored if it fails
    property var _previousRules: []
    property string _token: ""

    property bool busy: false
    // Last error (eval or write), for the settings page
    property string error: ""

    signal applied
    signal kept
    signal reverted

    function modes(monitor): var {
        return Lib.modes(monitor);
    }

    function scaleSteps(width: int, height: int): var {
        return Lib.scaleSteps(width, height);
    }

    function validScales(width: int, height: int): var {
        return Lib.validScales(width, height);
    }

    function selectorFor(monitor): string {
        return Lib.selectorFor(monitor, monitors);
    }

    // A rule per connected monitor describing what it shows now, on top of
    // its stored rule (VRR mode, color settings and turned-off values)
    function currentRules(): var {
        return monitors.map(m => {
            const stored = Lib.ruleFor(storedRules, m, monitors);
            if (lidOffNames.includes(m.name)) {
                const rule = stored ? JSON.parse(JSON.stringify(stored)) : {
                    mode: "preferred",
                    position: "auto",
                    scale: "auto",
                    transform: 0,
                    mirror: ""
                };
                rule.output = Lib.selectorFor(m, monitors);
                rule.name = m.name;
                rule.label = Lib.labelFor(m);
                rule.disabled = false;
                return rule;
            }
            return Lib.ruleFromLive(m, monitors, stored);
        });
    }

    // Why a set of rules can't be applied ("" = it can)
    function problemWith(rules): string {
        if (!rules.some(r => !r.disabled && !r.mirror && !lidOffNames.includes(r.name)))
            return "At least one monitor has to stay on";
        return "";
    }

    // Tries `rules` (one per connected monitor) live
    function apply(rules) {
        const problem = problemWith(rules);
        if (problem !== "" || busy)
            return problem;
        error = "";
        // The lid keeps its monitors off until it opens: not tried now
        const live = rules.filter(r => !lidOffNames.includes(r.name));
        _pendingRules = Lib.mergeRules(storedRules, rules, monitors);
        _trialPorts = _ports(monitors);
        _token = Date.now().toString(36);
        busy = true;
        trialProc.command = ["hyprctl", "eval", Lib.trialLua(live)];
        trialProc.running = true;
        return "";
    }

    function keep() {
        if (!trialActive)
            return;
        _stopTrial();
        _write(_pendingRules);
        kept();
    }

    // `reason` (reverted on its own) goes into a notification
    function revert(reason: string) {
        if (!trialActive)
            return;
        _stopTrial();
        Quickshell.execDetached(["bash", script, "revert"]);
        refreshSoon.restart();
        if (reason)
            _notify(reason);
        reverted();
    }

    // A config reload not started here (the laptop lid, another setting
    // saved to hypr/) already dropped the trial's rules: only end it
    function _endedByReload() {
        _stopTrial();
        // Stops the watcher (it would reload once more)
        Quickshell.execDetached(["bash", script, "keep"]);
        refreshSoon.restart();
        _notify("Hyprland reloaded its config (e.g. the laptop lid), which brought the saved monitor settings back");
        reverted();
    }

    function _notify(body: string) {
        Quickshell.execDetached(["notify-send", "-a", "Settings", "-i", "preferences-desktop-display", "Display settings reverted", body]);
    }

    function _ports(list): string {
        return list.map(m => m.name).sort().join(" ");
    }

    // Takes over a monitors.lua written by another tool: its rules become
    // the saved ones, and the file is rewritten from them
    function importFile() {
        _write(fileRules);
    }

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    function _stopTrial() {
        trialActive = false;
        countdown.stop();
    }

    function _write(rules) {
        _previousRules = savedRules;
        StateService.set("monitors.rules", rules);
        busy = true;
        writeProc.command = ["bash", script, "write", Lib.fileContent(rules)];
        writeProc.running = true;
    }

    Component.onCompleted: refresh()

    FileView {
        id: file
        path: root.filePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._fileText = text()
        onLoadFailed: root._fileText = ""
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // Keeping and reverting end the trial before they reload
            if (event.name === "configreloaded" && root.trialActive)
                root._endedByReload();
            else if (["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].includes(event.name))
                root.refreshSoon.restart();
        }
    }

    property Timer refreshSoon: Timer {
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.trialRemaining -= 1;
            if (root.trialRemaining <= 0)
                root.revert("They weren't kept within " + root.trialSeconds + " seconds");
        }
    }

    Process {
        id: listProc
        command: ["hyprctl", "monitors", "all", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text).filter(m => !Lib.ignored(m));
                    root.ready = true;
                    // Turned off monitors stay listed: only a plug or unplug
                    // changes the ports, and the trial's rules don't cover it
                    if (root.trialActive && root._ports(root.monitors) !== root._trialPorts)
                        root.revert("A monitor was connected or disconnected during the trial");
                } catch (e) {
                    console.warn("[Monitors] can't read hyprctl monitors:", e);
                }
            }
        }
    }

    Process {
        id: trialProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                const out = text.trim();
                if (out !== "ok") {
                    root.error = out || "hyprctl eval failed";
                    console.warn("[Monitors]", root.error);
                    // Part of it may have applied: back to the saved file
                    Quickshell.execDetached(["bash", root.script, "revert"]);
                    return;
                }
                // Reverts on its own unless kept, also if the shell dies
                Quickshell.execDetached(["setsid", "-f", "bash", root.script, "watch", root._token, String(root.trialSeconds + 3)]);
                root.trialRemaining = root.trialSeconds;
                root.trialActive = true;
                countdown.restart();
                root.refreshSoon.restart();
                root.applied();
            }
        }
    }

    Process {
        id: writeProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                const out = text.trim();
                if (out !== "ok") {
                    root.error = out || "writing monitors.lua failed";
                    console.warn("[Monitors]", root.error);
                    StateService.set("monitors.rules", root._previousRules);
                    // The trial's rules are still live: back to the saved file
                    Quickshell.execDetached(["bash", root.script, "revert"]);
                }
                root.refreshSoon.restart();
            }
        }
    }
}
