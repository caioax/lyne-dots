pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// The power profiles daemon (installed, or what installing one takes) and
// the profile (PowerProfileService)
ColumnLayout {
    spacing: Config.spacing * 3

    // The daemon may have been installed or removed since
    Component.onCompleted: PowerProfileService.check()

    SettingsGroup {
        title: I18n.tr("Daemon")

        SettingRow {
            id: daemonRow

            readonly property string daemonState: PowerProfileService.state
            readonly property string detail: PowerProfileService.detail
            readonly property string rival: PowerProfileService.rival
            readonly property var rivalText: ({
                    "auto-cpufreq": I18n.tr("auto-cpufreq is installed too and fights it over the CPU: remove one of them"),
                    "tlp": I18n.tr("TLP is installed too and fights it: tlp-pd is TLP's own daemon"),
                    "tuned": I18n.tr("TuneD is installed too and fights it: tuned-ppd is TuneD's own daemon")
                })

            label: I18n.tr("Power profiles daemon")
            description: {
                switch (daemonState) {
                case "ok":
                case "stopped":
                    {
                        const daemon = detail === "unknown" ? I18n.tr("A daemon") : detail;
                        const status = daemonState === "ok" ? I18n.tr("%1 switches the profiles below", daemon) : I18n.tr("%1 is installed but isn't running: Enable starts it now and at every boot", daemon);
                        return rival === "" ? status : status + ". " + (rivalText[rival] ?? I18n.tr("%1 is installed too and may fight it", rival));
                    }
                case "missing":
                    {
                        const what = detail === "tlp-pd" ? I18n.tr("tlp-pd, TLP's own daemon") : detail === "tuned-ppd" ? I18n.tr("tuned-ppd, TuneD's own daemon") : detail;
                        return BatteryService.hasBattery ? I18n.tr("None installed. Install adds %1", what) : I18n.tr("None installed. Install adds %1 (mostly useful on laptops)", what);
                    }
                case "conflict":
                    return detail === "auto-cpufreq" ? I18n.tr("auto-cpufreq manages the CPU and fights power profile daemons: remove it (auto-cpufreq --remove) to use profiles") : I18n.tr("TLP and TuneD are both installed and conflict: keep one of them");
                default:
                    return I18n.tr("Checking…");
                }
            }
            descriptionColor: rival !== "" || daemonState === "conflict" || daemonState === "stopped" ? Config.warningColor : Config.subtextColor

            // md-check_circle / md-alert_circle
            leading: Text {
                text: daemonRow.daemonState === "ok" ? "\u{f05e0}" : "\u{f0028}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: daemonRow.daemonState === "ok" ? (daemonRow.rival !== "" ? Config.warningColor : Config.successColor) : Config.subtextColor
            }

            // md-download / md-play
            ActionButton {
                visible: daemonRow.daemonState === "missing" || daemonRow.daemonState === "stopped"
                icon: daemonRow.daemonState === "missing" ? "\u{f01da}" : "\u{f040a}"
                text: PowerProfileService.installing ? I18n.tr("Waiting…") : daemonRow.daemonState === "missing" ? I18n.tr("Install") : I18n.tr("Enable")
                opacity: PowerProfileService.installing ? 0.6 : 1
                onClicked: PowerProfileService.install()
            }

            // md-refresh
            ActionButton {
                visible: daemonRow.daemonState === "conflict" || daemonRow.daemonState === "ok" && daemonRow.rival !== ""
                icon: "\u{f0450}"
                text: I18n.tr("Check again")
                onClicked: PowerProfileService.check()
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("Profile")
        visible: PowerProfileService.available

        SelectRow {
            label: I18n.tr("Profile")
            description: I18n.tr("Power saver lowers the CPU's speed and power draw, performance lets it run at full speed")
            segmentWidth: Config.fontSizeNormal * 8
            options: PowerProfileService.profiles.map(id => ({
                        label: PowerProfileService.label(id),
                        icon: PowerProfileService.icon(id),
                        value: id
                    }))
            value: PowerProfileService.profile
            onSelected: value => PowerProfileService.setProfile(value)
        }
    }

    // Power saver by itself (PowerProfileService, powerRules.js)
    SettingsGroup {
        title: I18n.tr("Automatic")
        visible: PowerProfileService.available && BatteryService.hasBattery

        ToggleRow {
            label: I18n.tr("Low battery")
            description: I18n.tr("Power saver when the battery drops below the level, and back to the profile from before when you plug in. Picking a profile by hand keeps it")
            path: "powerProfiles.lowBattery"
        }

        StepperRow {
            label: I18n.tr("Level")
            description: I18n.tr("Battery level that turns power saver on")
            enabled: PowerProfileService.rules.lowBattery
            path: "powerProfiles.lowBatteryLevel"
            values: [10, 15, 20, 25, 30]
            format: v => v + "%"
        }

        ToggleRow {
            label: I18n.tr("On battery")
            description: PowerProfileService.daemonSwitchesOnUnplug ? I18n.tr("tlp-pd already switches profiles when you unplug (its smart mode)") : I18n.tr("Power saver while unplugged, and back to the profile from before when you plug in")
            enabled: !PowerProfileService.daemonSwitchesOnUnplug
            path: "powerProfiles.onUnplug"
        }
    }

    SettingsGroup {
        title: I18n.tr("Quick Settings")
        visible: PowerProfileService.available

        ToggleRow {
            label: I18n.tr("Tile")
            description: I18n.tr("A Power profile tile: a click switches to the next profile, ⋮ opens the profiles. The profile button at the top of Quick Settings stays")
            path: "powerProfiles.quickSettings"
        }
    }
}
