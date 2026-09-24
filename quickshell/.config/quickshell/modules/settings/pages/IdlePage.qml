pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

ColumnLayout {
    id: root

    // Seconds; 0 = never (the monitor is disabled)
    readonly property var timeouts: [60, 120, 300, 600, 900, 1800, 3600, 0]

    readonly property bool lockEnabled: IdleService.lockTimeout > 0
    readonly property bool screenOffEnabled: IdleService.dpmsEnabled && IdleService.dpmsTimeout > 0

    // Why the idle actions are (not) running right now
    readonly property string status: {
        if (!lockEnabled && !screenOffEnabled)
            return "Nothing happens when idle";
        if (IdleService.caffeineEnabled)
            return "Paused by caffeine";
        if (IdleService.mediaPlaying)
            return "Paused while media is playing";
        if (IdleService.systemInhibited)
            return "Paused by an app (systemd inhibitor)";
        return "Active";
    }
    readonly property bool active: status === "Active"

    function formatTimeout(seconds: int): string {
        if (seconds === 0)
            return "Never";
        if (seconds < 3600)
            return seconds / 60 + " min";
        return seconds / 3600 + " h";
    }

    spacing: Config.spacing * 3

    SettingsGroup {
        title: "Status"

        SettingRow {
            id: statusRow

            label: root.status
            description: {
                if (!root.lockEnabled && !root.screenOffEnabled)
                    return "Automatic lock and screen off are disabled";
                const parts = [];
                if (root.lockEnabled)
                    parts.push("locks after " + root.formatTimeout(IdleService.lockTimeout));
                if (root.screenOffEnabled)
                    parts.push("screen off after " + root.formatTimeout(IdleService.dpmsTimeout));
                const summary = parts.join(", ") + " of inactivity";
                return summary.charAt(0).toUpperCase() + summary.slice(1);
            }

            // Status dot
            Rectangle {
                implicitWidth: Config.spacing
                implicitHeight: Config.spacing
                radius: width / 2
                color: root.active ? Config.successColor : Config.warningColor
            }

            // md-lock
            ActionButton {
                icon: "\u{f033e}"
                text: "Lock now"
                baseColor: statusRow.controlColor
                onClicked: IdleService.lock()
            }
        }
    }

    SettingsGroup {
        title: "Stay awake"

        ToggleRow {
            label: "Caffeine"
            description: "Keep the screen on and never lock automatically"
            path: "idle.caffeine"
            resettable: false
        }

        ToggleRow {
            label: "Pause while media plays"
            description: "Videos and music in any player count as activity"
            path: "idle.mediaInhibit"
        }
    }

    SettingsGroup {
        title: "Screen lock"

        StepperRow {
            label: "Lock after"
            description: "Time without input before the screen locks"
            path: "idle.lockTimeout"
            values: root.timeouts
            format: v => root.formatTimeout(v)
        }
    }

    SettingsGroup {
        title: "Screen off"

        ToggleRow {
            id: dpmsToggle
            label: "Turn screens off"
            description: "Screens wake up again on any input"
            path: "idle.dpmsEnabled"
        }

        StepperRow {
            enabled: dpmsToggle.checked
            label: "Turn off after"
            description: "Time without input before the screens go dark"
            path: "idle.dpmsTimeout"
            values: root.timeouts
            format: v => root.formatTimeout(v)
        }
    }
}
