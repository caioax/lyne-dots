pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config
import "powerRules.js" as Rules

// Power profiles (power saver, balanced, performance) through Quickshell's
// PowerProfiles, served by power-profiles-daemon, tuned-ppd or tlp-pd.
// scripts/power-profiles.sh (lyne's power-profiles.sh lib) says which daemon
// is there or what installing one takes. PowerProfiles tries to start the
// daemon once, when first read, and keeps that answer until Quickshell
// restarts (its singleton outlives reloads), so it's only read once the
// daemon is known to be there. Automatic profiles (low battery, unplugged:
// powerRules.js) start a few seconds after the daemon and battery are there,
// so UPower filling in its values at login isn't taken for an unplug.
// `qs ipc call powerprofile get|set|cycle`
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
                label: I18n.tr("Power saver"),
                description: I18n.tr("Quieter and cooler, longer battery"),
                icon: "\u{f032a}" // md-leaf
            },
            "balanced": {
                label: I18n.tr("Balanced"),
                description: I18n.tr("Fast when needed, saves when idle"),
                icon: "\u{f05d1}" // md-scale_balance
            },
            "performance": {
                label: I18n.tr("Performance"),
                description: I18n.tr("Full speed, more heat and power"),
                icon: "\u{f04c5}" // md-speedometer
            }
        })

    readonly property bool hasPerformance: available && PowerProfiles.hasPerformanceProfile
    readonly property var profiles: profileIds.filter(id => id !== "performance" || hasPerformance)
    // "" without a daemon
    readonly property string profile: available ? idOf(PowerProfiles.profile) : ""

    // Why performance is held back ("" when it isn't)
    readonly property string degradation: {
        if (!available)
            return "";
        switch (PowerProfiles.degradationReason) {
        case PerformanceDegradationReason.LapDetected:
            return I18n.tr("On your lap: the laptop keeps cool, so performance is limited");
        case PerformanceDegradationReason.HighTemperature:
            return I18n.tr("Running hot: performance is limited until it cools down");
        default:
            return "";
        }
    }

    // Apps holding a profile while they run: [{ app, profile }]. Picking a
    // profile by hand releases them
    readonly property var holds: {
        if (!available)
            return [];
        const out = [];
        const list = PowerProfiles.holds;
        for (let i = 0; i < list.length; i++)
            out.push({
                app: list[i].applicationId,
                profile: idOf(list[i].profile)
            });
        return out;
    }

    // Quick Settings tile (Settings › System › Power profiles)
    readonly property bool showTile: StateService.get("powerProfiles.quickSettings", true)

    function idOf(value: int): string {
        switch (value) {
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

    function description(id: string): string {
        return profileInfo[id]?.description ?? "";
    }

    // Saver green, balanced accent, performance warm
    function tone(id: string): color {
        return id === "power-saver" ? Config.successColor : id === "performance" ? Config.warningColor : Config.accentColor;
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

    // ========== AUTOMATIC ==========
    // tlp-pd switches on unplug by itself (its "smart" mode)
    readonly property bool daemonSwitchesOnUnplug: detail === "tlp-pd"
    readonly property var rules: ({
            lowBattery: StateService.get("powerProfiles.lowBattery", true),
            level: StateService.get("powerProfiles.lowBatteryLevel", 20),
            onUnplug: !daemonSwitchesOnUnplug && StateService.get("powerProfiles.onUnplug", false)
        })
    readonly property bool onBattery: UPower.onBattery
    readonly property int percentage: BatteryService.percentage
    // The rule that switched to power saver ("lowBattery", "unplugged" or "")
    readonly property string autoReason: autoState.reason
    readonly property bool rulesReady: available && BatteryService.hasBattery

    // Power as the rules last saw it (null until they start)
    property var _was: null

    onRulesReadyChanged: {
        _was = null;
        if (rulesReady)
            settle.restart();
    }
    onOnBatteryChanged: _powerChanged()
    onPercentageChanged: _powerChanged()
    onProfileChanged: {
        // "" while the daemon isn't read yet (also right after a reload)
        if (profile === "")
            return;
        const auto = Rules.profileChanged(_auto(), profile);
        autoState.reason = auto.reason;
        autoState.previous = auto.previous;
    }

    function _auto(): var {
        return {
            reason: autoState.reason,
            previous: autoState.previous
        };
    }

    function _powerChanged(): void {
        if (_was === null || !rulesReady)
            return;
        const now = {
            onBattery: onBattery,
            percentage: percentage
        };
        const result = Rules.powerChanged(rules, _was, now, profile, holds.length > 0, _auto());
        _was = now;
        autoState.reason = result.auto.reason;
        autoState.previous = result.auto.previous;
        if (result.switchTo === "")
            return;
        setProfile(result.switchTo);
        if (result.switchTo === "power-saver") {
            const back = label(result.auto.previous);
            const body = result.auto.reason === "lowBattery" ? `Battery at ${percentage}%. ${back} comes back when you plug in` : `Running on battery. ${back} comes back when you plug in`;
            Quickshell.execDetached(["notify-send", "-a", "Power profile", "-i", "battery-caution", "Power saver on", body]);
        }
    }

    Timer {
        id: settle
        interval: 5000
        onTriggered: root._was = {
            onBattery: root.onBattery,
            percentage: root.percentage
        }
    }

    // Kept across reloads
    PersistentProperties {
        id: autoState
        reloadableId: "powerProfileAuto"

        property string reason: ""
        property string previous: ""
    }

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
