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

    readonly property var systemRows: [
        {
            label: "OS",
            value: info.os
        },
        {
            label: "Device",
            value: info.model
        },
        {
            label: "Hostname",
            value: info.host
        },
        {
            label: "Kernel",
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
            label: "Memory",
            value: info.memory
        },
        {
            label: "Uptime",
            value: info.uptime
        },
        {
            label: "Packages",
            value: info.packages ? info.packages + " (pacman)" : ""
        },
        {
            label: "Hyprland",
            value: info.hyprland
        },
        {
            label: "Quickshell",
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
            echo "uptime=$(uptime -p | sed 's/^up //')"
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
                text: "Lyne"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconSmall
                    font.bold: true
                    color: Config.textColor
                }

                Text {
                    Layout.fillWidth: true
                text: "Hyprland + Quickshell dotfiles"
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
                        const parts = g.version ? ["\u{f04f9} " + g.version, root.followsChannel ? (root.channel === "stable" ? "Stable" : "Latest") : g.branch] : ["\u{f062c} " + g.branch];
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
                text: "GitHub"
                onClicked: Qt.openUrlExternally(root.repoUrl)
            }

            // md-heart_outline
            ActionButton {
                icon: "\u{f02d5}"
                text: "Support"
                textColor: Config.errorColor
                onClicked: Qt.openUrlExternally(root.repoUrl + "#support")
            }
        }
    }

    // ================= WELCOME =================
    SettingsGroup {
        title: "Welcome"

        SettingRow {
            id: welcomeRow

            label: "Welcome screen"
            description: "The first choices and the main shortcuts, as on the first login (also lyne welcome)"

            // md-hand_wave_outline
            ActionButton {
                icon: "\u{f1822}"
                text: "Open"
                baseColor: welcomeRow.controlColor
                onClicked: WelcomeService.open()
            }
        }
    }

    // ================= UPDATES =================
    SettingsGroup {
        title: "Updates"

        SettingRow {
            id: updateRow

            label: {
                const g = root.git;
                if (root.checking)
                    return "Checking for updates…";
                if (root.behind > 0) {
                    if (root.followsChannel && root.channel === "stable")
                        return "Update available: " + g.target;
                    return root.behind + (root.behind === 1 ? " update" : " updates") + " available";
                }
                if (!g.fetched)
                    return "Couldn't reach GitHub";
                if (!g.upstream)
                    return "No upstream branch";
                if (!g.target)
                    return "No release yet";
                return "Up to date";
            }
            description: {
                const g = root.git;
                if (root.dirty > 0)
                    return root.dirty + " uncommitted " + (root.dirty === 1 ? "change" : "changes") + " in ~/.lyne-dots. Updating asks whether to stash or discard them";
                if (!root.followsChannel)
                    return "On the " + g.branch + " branch: updates follow " + g.upstream;
                if (root.channel === "stable" && !g.target)
                    return "Stable follows releases, and there's none yet";
                if (root.channel === "stable" && root.behind === 0 && (g.version ?? "").includes("+"))
                    return "Newer than the last release (" + g.lastRelease + "): Stable moves on with the next one";
                return "Updates the dotfiles, syncs state.json and runs pending migrations";
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
                text: "Update"
                baseColor: root.behind > 0 ? Config.accentColor : updateRow.controlColor
                hoverColor: root.behind > 0 ? Qt.lighter(Config.accentColor, 1.1) : Config.surface3Color
                textColor: root.behind > 0 ? Config.textReverseColor : Config.textColor
                onClicked: root.runUpdate()
            }
        }

        SelectRow {
            label: "Channel"
            description: root.followsChannel ? "Stable gets the releases; Latest every change as soon as it's on main" : "Not used on the " + (root.git.branch ?? "") + " branch, which updates from its upstream"
            path: "update.channel"
            enabled: root.followsChannel
            options: [
                {
                    label: "Stable",
                    value: "stable"
                },
                {
                    label: "Latest",
                    value: "latest"
                }
            ]
        }

        ToggleRow {
            label: "Notify about updates"
            description: "Checks a minute after login, and notifies once per new " + (root.channel === "stable" ? "release" : "commit")
            path: "update.notify"
            enabled: root.followsChannel
        }
    }

    // ================= SYSTEM =================
    SettingsGroup {
        title: "System"

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

            label: "Copy system info"
            description: "Handy for bug reports"

            ActionButton {
                icon: copiedTimer.running ? "\u{f012c}" : "\u{f018f}"
                text: copiedTimer.running ? "Copied" : "Copy"
                baseColor: copyRow.controlColor
                onClicked: root.copyInfo()
            }
        }
    }
}
