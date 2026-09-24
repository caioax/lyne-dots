pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import "../rows/"
import "../../../components/"

// Dotfiles version and updates, plus system information. Everything is read
// once when the page opens (and on demand), nothing polls
ColumnLayout {
    id: root

    readonly property string repoUrl: "https://github.com/caioax/lyne-dots"
    readonly property string dotsDir: Quickshell.env("HOME") + "/.lyne-dots"
    readonly property int heroIconSize: Config.fontSizeIconLarge * 2

    // key -> value from the scripts below
    property var info: ({})
    property var git: ({})
    property bool checking: false
    property bool confirmingUpdate: false

    readonly property int behind: git.behind !== undefined && git.behind !== "" ? parseInt(git.behind) : -1
    readonly property int dirty: parseInt(git.dirty ?? "0")

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
        if (gitProc.running)
            return;
        checking = true;
        gitProc.running = true;
    }

    function runUpdate() {
        if (dirty > 0 && !confirmingUpdate) {
            confirmingUpdate = true;
            confirmTimer.restart();
            return;
        }
        confirmingUpdate = false;
        // In a terminal, so the output (and any sudo prompt from migrations) is visible
        Quickshell.execDetached(["kitty", "--title", "lyne update", "--hold", "lyne", "update"]);
    }

    function copyInfo() {
        const lines = [`lyne-dots ${git.branch} @ ${git.commit} (${git.date})`];
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

    // Fetches first so "behind" is current; without network it still reports
    // the local state
    Process {
        id: gitProc
        command: ["bash", "-c", `
            cd "${root.dotsDir}" || exit 1
            echo "branch=$(git rev-parse --abbrev-ref HEAD)"
            echo "commit=$(git log -1 --format=%h)"
            echo "date=$(git log -1 --format=%cd --date=short)"
            echo "dirty=$(git status --porcelain | wc -l)"
            timeout 15 git fetch --quiet 2>/dev/null && echo "fetched=1"
            echo "behind=$(git rev-list --count HEAD..@{u} 2>/dev/null)"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                root.git = root.parse(text);
                root.checking = false;
            }
        }
    }

    Timer {
        id: confirmTimer
        interval: 4000
        onTriggered: root.confirmingUpdate = false
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
        color: Config.surface0Color

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

                // md-arch
                Text {
                    anchors.centerIn: parent
                    text: "\u{f08c7}"
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeIconLarge
                    color: Config.accentColor
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

                // md-source_branch
                Text {
                    Layout.fillWidth: true
                visible: root.git.commit !== undefined
                    text: "\u{f062c} " + root.git.branch + " · " + root.git.commit + " · " + root.git.date
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
        }
    }

    // ================= UPDATES =================
    SettingsGroup {
        title: "Updates"

        SettingRow {
            id: updateRow

            label: {
                if (root.checking)
                    return "Checking for updates…";
                if (root.git.fetched !== "1")
                    return root.behind > 0 ? root.behind + " updates available" : "Couldn't reach GitHub";
                if (root.behind > 0)
                    return root.behind + (root.behind === 1 ? " update" : " updates") + " available";
                return root.behind === 0 ? "Up to date" : "No upstream branch";
            }
            description: {
                if (root.dirty > 0)
                    return root.dirty + " uncommitted " + (root.dirty === 1 ? "change" : "changes") + " in ~/.lyne-dots. Updating runs git reset --hard and discards them";
                return "Pulls the latest dotfiles, syncs state.json and runs pending migrations";
            }

            leading: Text {
                // md-alert / md-download / md-check_circle
                text: root.dirty > 0 ? "\u{f0026}" : root.behind > 0 ? "\u{f01da}" : "\u{f05e0}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIcon
                color: root.dirty > 0 ? Config.warningColor : root.behind > 0 ? Config.accentColor : Config.successColor
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
                text: root.confirmingUpdate ? "Discard & update" : "Update"
                baseColor: root.confirmingUpdate ? Config.errorColor : root.behind > 0 ? Config.accentColor : updateRow.controlColor
                hoverColor: root.confirmingUpdate ? Qt.lighter(Config.errorColor, 1.1) : root.behind > 0 ? Qt.lighter(Config.accentColor, 1.1) : Config.surface3Color
                textColor: root.confirmingUpdate || root.behind > 0 ? Config.textReverseColor : Config.textColor
                onClicked: root.runUpdate()
            }
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
