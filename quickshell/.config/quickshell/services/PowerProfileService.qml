pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Power profiles (power saver, balanced, performance) through Quickshell's
// PowerProfiles, served by power-profiles-daemon, tuned-ppd or tlp-pd.
// scripts/power-profiles.sh (lyne's power-profiles.sh lib) says which daemon
// is there or what installing one takes. PowerProfiles tries to start the
// daemon once, when first read, and keeps that answer until Quickshell
// restarts (its singleton outlives reloads), so it's only read once the
// daemon is known to be there. `qs ipc call powerprofile get|set|cycle`
Singleton {
    id: root

    readonly property string script: Qt.resolvedUrl("../scripts/power-profiles.sh").toString().replace("file://", "")

    // ok (on the bus), stopped (installed, not on the bus), missing (none
    // installed) or conflict (something blocks the install); "" until the
    // first check
    property string state: ""
    // ok/stopped: the daemon package ("unknown" when no package says);
    // missing: what Install adds; conflict: what blocks it
    property string detail: ""
    // ok/stopped: a tool that fights the daemon (auto-cpufreq, tlp, tuned)
    property string rival: ""
    readonly property bool available: state === "ok"
    property bool installing: false

    // Profile ids as the daemons name them, in the order cycle() walks
    readonly property var profileIds: ["power-saver", "balanced", "performance"]
    readonly property var profileInfo: ({
            "power-saver": {
                label: "Power saver",
                icon: "\u{f032a}" // md-leaf
            },
            "balanced": {
                label: "Balanced",
                icon: "\u{f05d1}" // md-scale_balance
            },
            "performance": {
                label: "Performance",
                icon: "\u{f04c5}" // md-speedometer
            }
        })

    readonly property bool hasPerformance: available && PowerProfiles.hasPerformanceProfile
    readonly property var profiles: profileIds.filter(id => id !== "performance" || hasPerformance)
    // "" without a daemon
    readonly property string profile: {
        if (!available)
            return "";
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            return "power-saver";
        case PowerProfile.Performance:
            return "performance";
        default:
            return "balanced";
        }
    }

    function label(id: string): string {
        return profileInfo[id]?.label ?? "";
    }

    function icon(id: string): string {
        return profileInfo[id]?.icon ?? "";
    }

    function setProfile(id: string): void {
        if (!available || !profiles.includes(id))
            return;
        PowerProfiles.profile = id === "power-saver" ? PowerProfile.PowerSaver : id === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
    }

    function cycle(): void {
        if (profiles.length > 0)
            setProfile(profiles[(profiles.indexOf(profile) + 1) % profiles.length]);
    }

    function check(): void {
        if (!stateProc.running)
            stateProc.running = true;
    }

    // Installs (or enables) the daemon in a terminal, as it asks for sudo
    function install(): void {
        if (installing)
            return;
        installing = true;
        installProc.command = AppsService.terminalArgv(["bash", "-c", `"$0" install; echo; read -rsn1 -p "Press any key to close"`, root.script]);
        installProc.running = true;
    }

    Component.onCompleted: check()

    Process {
        id: stateProc
        command: [root.script, "state"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [state, detail, rival] = text.trim().split(" ");
                root.state = state ?? "";
                root.detail = detail ?? "";
                root.rival = rival ?? "";
            }
        }
    }

    Process {
        id: installProc
        onExited: {
            root.installing = false;
            root.check();
        }
    }

    IpcHandler {
        target: "powerprofile"

        // power-saver, balanced or performance ("" without a daemon)
        function get(): string {
            return root.profile;
        }

        function set(profile: string): void {
            root.setProfile(profile);
        }

        function cycle(): void {
            root.cycle();
        }
    }
}
