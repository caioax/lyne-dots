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
        title: "Daemon"

        SettingRow {
            id: daemonRow

            readonly property string state: PowerProfileService.state
            readonly property string detail: PowerProfileService.detail
            readonly property string rival: PowerProfileService.rival
            readonly property var rivalText: ({
                    "auto-cpufreq": "auto-cpufreq is installed too and fights it over the CPU: remove one of them",
                    "tlp": "TLP is installed too and fights it: tlp-pd is TLP's own daemon",
                    "tuned": "TuneD is installed too and fights it: tuned-ppd is TuneD's own daemon"
                })

            label: "Power profiles daemon"
            description: {
                switch (state) {
                case "ok":
                case "stopped":
                    {
                        const daemon = detail === "unknown" ? "A daemon" : detail;
                        const status = state === "ok" ? daemon + " switches the profiles below" : daemon + " is installed but isn't running: Enable starts it now and at every boot";
                        return rival === "" ? status : status + ". " + (rivalText[rival] ?? rival + " is installed too and may fight it");
                    }
                case "missing":
                    return "None installed. Install adds " + (detail === "tlp-pd" ? "tlp-pd, TLP's own daemon" : detail === "tuned-ppd" ? "tuned-ppd, TuneD's own daemon" : detail) + (BatteryService.hasBattery ? "" : " (mostly useful on laptops)");
                case "conflict":
                    return detail === "auto-cpufreq" ? "auto-cpufreq manages the CPU and fights power profile daemons: remove it (auto-cpufreq --remove) to use profiles" : "TLP and TuneD are both installed and conflict: keep one of them";
                default:
                    return "Checking…";
                }
            }
            descriptionColor: rival !== "" || state === "conflict" || state === "stopped" ? Config.warningColor : Config.subtextColor

            // md-check_circle / md-alert_circle
            leading: Text {
                text: daemonRow.state === "ok" ? "\u{f05e0}" : "\u{f0028}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: daemonRow.state === "ok" ? (daemonRow.rival !== "" ? Config.warningColor : Config.successColor) : Config.subtextColor
            }

            // md-download / md-play
            ActionButton {
                visible: daemonRow.state === "missing" || daemonRow.state === "stopped"
                icon: daemonRow.state === "missing" ? "\u{f01da}" : "\u{f040a}"
                text: PowerProfileService.installing ? "Waiting…" : daemonRow.state === "missing" ? "Install" : "Enable"
                opacity: PowerProfileService.installing ? 0.6 : 1
                onClicked: PowerProfileService.install()
            }

            // md-refresh
            ActionButton {
                visible: daemonRow.state === "conflict" || daemonRow.state === "ok" && daemonRow.rival !== ""
                icon: "\u{f0450}"
                text: "Check again"
                onClicked: PowerProfileService.check()
            }
        }
    }

    SettingsGroup {
        title: "Profile"
        visible: PowerProfileService.available

        SelectRow {
            label: "Profile"
            description: "Power saver lowers the CPU's speed and power draw, performance lets it run at full speed"
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
}
