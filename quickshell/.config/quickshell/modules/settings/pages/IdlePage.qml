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
            return I18n.tr("Nothing happens when idle");
        if (IdleService.caffeineEnabled)
            return I18n.tr("Paused by caffeine");
        if (IdleService.mediaPlaying)
            return I18n.tr("Paused while media is playing");
        if (IdleService.systemInhibited)
            return I18n.tr("Paused by an app (systemd inhibitor)");
        return I18n.tr("Active");
    }
    readonly property bool active: status === I18n.tr("Active")

    function formatTimeout(seconds: int): string {
        if (seconds === 0)
            return I18n.tr("Never");
        if (seconds < 3600)
            return I18n.tr("%1 min", I18n.number(seconds / 60, 0));
        return I18n.tr("%1 h", I18n.number(seconds / 3600, seconds % 3600 === 0 ? 0 : 1));
    }

    spacing: Config.spacing * 3

    SettingsGroup {
        title: I18n.tr("Status")

        SettingRow {
            id: statusRow

            label: root.status
            description: {
                if (!root.lockEnabled && !root.screenOffEnabled)
                    return I18n.tr("Automatic lock and screen off are disabled");
                const lock = root.formatTimeout(IdleService.lockTimeout);
                const off = root.formatTimeout(IdleService.dpmsTimeout);
                if (root.lockEnabled && root.screenOffEnabled)
                    return I18n.tr("Locks after %1, screen off after %2 of inactivity", lock, off);
                return root.lockEnabled ? I18n.tr("Locks after %1 of inactivity", lock) : I18n.tr("Screen off after %1 of inactivity", off);
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
                text: I18n.tr("Lock now")
                baseColor: statusRow.controlColor
                onClicked: IdleService.lock()
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("Stay awake")

        ToggleRow {
            label: I18n.tr("Caffeine")
            description: I18n.tr("Keep the screen on and never lock automatically")
            path: "idle.caffeine"
            resettable: false
        }

        ToggleRow {
            label: I18n.tr("Pause while media plays")
            description: I18n.tr("Videos and music in any player count as activity")
            path: "idle.mediaInhibit"
        }
    }

    SettingsGroup {
        title: I18n.tr("Screen lock")

        StepperRow {
            label: I18n.tr("Lock after")
            description: I18n.tr("Time without input before the screen locks")
            path: "idle.lockTimeout"
            values: root.timeouts
            format: v => root.formatTimeout(v)
        }
    }

    SettingsGroup {
        title: I18n.tr("Screen off")

        ToggleRow {
            id: dpmsToggle
            label: I18n.tr("Turn screens off")
            description: I18n.tr("Screens wake up again on any input")
            path: "idle.dpmsEnabled"
        }

        StepperRow {
            enabled: dpmsToggle.checked
            label: I18n.tr("Turn off after")
            description: I18n.tr("Time without input before the screens go dark")
            path: "idle.dpmsTimeout"
            values: root.timeouts
            format: v => root.formatTimeout(v)
        }
    }
}
