pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Dotfiles version and updates, plus system information. Everything is read
// once when the page opens (and on demand), nothing polls
ColumnLayout {
    id: root

    readonly property string repoUrl: "https://github.com/caioax/lyne-dots"
    readonly property string dotsDir: Quickshell.env("HOME") + "/.lyne-dots"
    readonly property int heroIconSize: Config.fontSizeIconLarge * 2

    // key -> value from infoProc
    property var info: ({})

    // `lyne update status --json`, from UpdateService
    readonly property var git: UpdateService.status
    readonly property bool checking: UpdateService.checking
    readonly property int behind: UpdateService.behind
    readonly property int dirty: UpdateService.dirty
    readonly property string channel: UpdateService.channel
    readonly property bool followsChannel: UpdateService.followsChannel

    // "Intel Corporation TigerLake-H GT1 [UHD Graphics] (rev 01)" -> "Intel UHD Graphics"
    function shortGpu(line: string): string {
        const vendor = line.split(" ")[0];
        const model = line.match(/\[([^\]]+)\]/);
        return model ? vendor + " " + model[1] : line.replace(/\s*\(rev [^)]*\)/, "");
    }

    // "2 hours, 55 minutes" from the seconds in /proc/uptime
    function formatUptime(seconds: real): string {
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor(seconds % 86400 / 3600);
        const minutes = Math.floor(seconds % 3600 / 60);
        const parts = [];
        if (days > 0)
            parts.push(I18n.trn("%n day", "%n days", days));
        if (hours > 0)
            parts.push(I18n.trn("%n hour", "%n hours", hours));
        if (minutes > 0 || parts.length === 0)
            parts.push(I18n.trn("%n minute", "%n minutes", minutes));
        return parts.join(", ");
    }

    readonly property var systemRows: [
        {
            label: "OS",
            value: info.os
        },
        {
            label: I18n.tr("Device"),
            value: info.model
        },
        {
            label: I18n.tr("Hostname"),
            value: info.host
        },
        {
            label: I18n.tr("Kernel"),
            value: info.kernel
        },
        {
            label: "CPU",
            value: info.cpu
        },
        {
            label: "GPU",
            value: (info.gpu ?? "").split(";").filter(g => g !== "").map(g => shortGpu(g)).join(", ")
        },
        {
            label: I18n.tr("Memory"),
            value: info.memory
        },
        {
            label: I18n.tr("Uptime"),
            value: root.formatUptime(Number(info.uptime ?? 0))
        },
        {
            label: I18n.tr("Packages"),
            value: info.packages ? info.packages + " (pacman)" : ""
        },
        {
            label: I18n.tr("Hyprland"),
            value: info.hyprland
        },
        {
            label: I18n.tr("Quickshell"),
            value: info.quickshell
        }
    ]

    function parse(text: string): var {
        const result = {};
        for (const line of text.split("\n")) {
            const i = line.indexOf("=");
            if (i > 0)
                result[line.slice(0, i)] = line.slice(i + 1).trim();
        }
        return result;
    }

    function checkUpdates() {
        UpdateService.check();
    }

    function runUpdate() {
        UpdateService.runUpdate();
    }

    function copyInfo() {
        const lines = [`lyne-dots ${git.version || "(no release)"} · ${git.branch} @ ${git.commit} (${git.date})`];
        for (const row of systemRows)
            lines.push(`${row.label}: ${row.value ?? ""}`);
        Quickshell.execDetached(["wl-copy", lines.join("\n")]);
        copiedTimer.restart();
    }

    Component.onCompleted: {
        infoProc.running = true;
        checkUpdates();
    }

    spacing: Config.spacing * 3

    Process {
        id: infoProc
        command: ["bash", "-c", `
            . /etc/os-release; echo "os=$PRETTY_NAME"
            echo "kernel=$(uname -r)"
            echo "host=$(cat /etc/hostname 2>/dev/null)"
            echo "model=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)"
            echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')"
            echo "gpu=$(lspci 2>/dev/null | grep -Ei 'vga|3d' | sed 's/.*: //' | paste -sd ';')"
            echo "memory=$(awk '/MemTotal/ {printf "%.1f GiB", $2/1048576}' /proc/meminfo)"
            echo "uptime=$(cut -d. -f1 /proc/uptime)"
            echo "packages=$(pacman -Qq 2>/dev/null | wc -l)"
            echo "hyprland=$(hyprctl version -j 2>/dev/null | jq -r .tag)"
            echo "quickshell=$(qs --version 2>/dev/null | head -1 | awk '{print $2}')"
        `]
        stdout: StdioCollector {
            onStreamFinished: root.info = root.parse(text)
        }
    }

    Timer {
        id: copiedTimer
        interval: 2000
    }

    // ================= HERO =================
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: hero.implicitHeight + Config.padding * 4
        radius: Config.radiusLarge
        color: Config.cardColor

        RowLayout {
            id: hero

            anchors.fill: parent
            anchors.margins: Config.padding * 2
            spacing: Config.spacing * 2

            Rectangle {
                implicitWidth: root.heroIconSize
                implicitHeight: root.heroIconSize
                radius: Config.radiusLarge
                color: Qt.alpha(Config.accentColor, 0.15)

                LyneLogo {
                    anchors.centerIn: parent
                    height: Config.fontSizeIconLarge
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(Config.padding / 3)

                Text {
                    Layout.fillWidth: true
                text: I18n.tr("Lyne")
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconSmall
                    font.bold: true
                    color: Config.textColor
                }

                Text {
                    Layout.fillWidth: true
                text: I18n.tr("Hyprland + Quickshell dotfiles")
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }

                // md-tag (a release) / md-source_branch; "Stable" or the
                // branch it follows
                Text {
                    Layout.fillWidth: true
                visible: root.git.commit !== undefined
                    text: {
                        const g = root.git;
                        const parts = g.version ? ["\u{f04f9} " + g.version, root.followsChannel ? (root.channel === "stable" ? I18n.tr("Stable") : I18n.tr("Latest")) : g.branch] : ["\u{f062c} " + g.branch];
                        return parts.concat([g.commit, g.date]).join(" · ");
                    }
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.accentColor
                }
            }

            // md-github
            ActionButton {
                icon: "\u{f02a4}"
                text: I18n.tr("GitHub")
                onClicked: Qt.openUrlExternally(root.repoUrl)
            }

            // md-heart_outline
            ActionButton {
                icon: "\u{f02d5}"
                text: I18n.tr("Support")
                textColor: Config.errorColor
                onClicked: Qt.openUrlExternally(root.repoUrl + "#support")
            }
        }
    }

    // ================= WELCOME =================
    SettingsGroup {
        title: I18n.tr("Welcome")

        SettingRow {
            id: welcomeRow

            label: I18n.tr("Welcome screen")
            description: I18n.tr("The first choices and the main shortcuts, as on the first login (also lyne welcome)")

            // md-hand_wave_outline
            ActionButton {
                icon: "\u{f1822}"
                text: I18n.tr("Open")
                baseColor: welcomeRow.controlColor
                onClicked: WelcomeService.open()
            }
        }
    }

    // ================= UPDATES =================
    SettingsGroup {
        title: I18n.tr("Updates")

        SettingRow {
            id: updateRow

            label: {
                const g = root.git;
                if (root.checking)
                    return I18n.tr("Checking for updates…");
                if (root.behind > 0) {
                    if (root.followsChannel && root.channel === "stable")
                        return I18n.tr("Update available: %1", g.target);
                    return I18n.trn("%n update available", "%n updates available", root.behind);
                }
                if (!g.fetched)
                    return I18n.tr("Couldn't reach GitHub");
                if (!g.upstream)
                    return I18n.tr("No upstream branch");
                if (!g.target)
                    return I18n.tr("No release yet");
                return I18n.tr("Up to date");
            }
            description: {
                const g = root.git;
                if (root.dirty > 0)
                    return I18n.trn("%n uncommitted change in ~/.lyne-dots. Updating asks whether to stash or discard it", "%n uncommitted changes in ~/.lyne-dots. Updating asks whether to stash or discard them", root.dirty);
                if (!root.followsChannel)
                    return I18n.tr("On the %1 branch: updates follow %2", g.branch, g.upstream);
                if (root.channel === "stable" && !g.target)
                    return I18n.tr("Stable follows releases, and there's none yet");
                if (root.channel === "stable" && root.behind === 0 && (g.version ?? "").includes("+"))
                    return I18n.tr("Newer than the last release (%1): Stable moves on with the next one", g.lastRelease);
                return I18n.tr("Updates the dotfiles, syncs state.json and runs pending migrations");
            }

            leading: Text {
                readonly property bool upToDate: root.git.fetched === true && root.behind === 0

                // md-alert / md-download / md-check_circle / md-cloud_alert
                // (GitHub unreachable or no upstream: the state is unknown)
                text: root.dirty > 0 ? "\u{f0026}" : root.behind > 0 ? "\u{f01da}" : upToDate || root.checking ? "\u{f05e0}" : "\u{f09e0}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: root.dirty > 0 ? Config.warningColor : root.behind > 0 ? Config.accentColor : upToDate || root.checking ? Config.successColor : Config.warningColor
            }

            Spinner {
                running: root.checking
                size: Config.fontSizeIconSmall
                color: Config.subtextColor
            }

            // md-refresh
            ActionButton {
                visible: !root.checking
                icon: "\u{f0450}"
                baseColor: updateRow.controlColor
                onClicked: root.checkUpdates()
            }

            ActionButton {
                icon: "\u{f01da}"
                text: I18n.tr("Update")
                baseColor: root.behind > 0 ? Config.accentColor : updateRow.controlColor
                hoverColor: root.behind > 0 ? Qt.lighter(Config.accentColor, 1.1) : Config.surface3Color
                textColor: root.behind > 0 ? Config.textReverseColor : Config.textColor
                onClicked: root.runUpdate()
            }
        }

        SettingRow {
            id: notesRow

            readonly property string release: (root.git.version ?? "").split("+")[0]

            visible: release !== ""
            label: I18n.tr("What's new in %1", release)
            description: I18n.tr("The notes of the release this is at or past")

            // md-party_popper
            ActionButton {
                icon: "\u{f1056}"
                text: I18n.tr("Open")
                baseColor: notesRow.controlColor
                onClicked: WhatsNewService.open("")
            }
        }

        SelectRow {
            label: I18n.tr("Channel")
            description: root.followsChannel ? I18n.tr("Stable gets the releases; Latest every change as soon as it's on main") : I18n.tr("Not used on the %1 branch, which updates from its upstream", root.git.branch ?? "")
            path: "update.channel"
            enabled: root.followsChannel
            options: [
                {
                    label: I18n.tr("Stable"),
                    value: "stable"
                },
                {
                    label: I18n.tr("Latest"),
                    value: "latest"
                }
            ]
        }

        ToggleRow {
            label: I18n.tr("Notify about updates")
            description: root.channel === "stable" ? I18n.tr("Checks a minute after login, and notifies once per new release") : I18n.tr("Checks a minute after login, and notifies once per new commit")
            path: "update.notify"
            enabled: root.followsChannel
        }
    }

    // ================= SYSTEM =================
    SettingsGroup {
        title: I18n.tr("System")

        Repeater {
            model: root.systemRows

            InfoRow {
                required property var modelData
                label: modelData.label
                value: modelData.value ?? ""
            }
        }

        SettingRow {
            id: copyRow

            label: I18n.tr("Copy system info")
            description: I18n.tr("Handy for bug reports")

            ActionButton {
                icon: copiedTimer.running ? "\u{f012c}" : "\u{f018f}"
                text: copiedTimer.running ? I18n.tr("Copied") : I18n.tr("Copy")
                baseColor: copyRow.controlColor
                onClicked: root.copyInfo()
            }
        }
    }
}
