import QtQuick
import Quickshell.Io

// Which commands are installed: check(commands) runs `command -v` on the
// first word of each (a leading "~/" is the home folder) and merges the
// answers into `installed`, keyed as the commands spell them. A check asked
// for while one runs waits for it (QueuedProcess)
QueuedProcess {
    id: root

    // binary -> installed (unknown until checked)
    property var installed: ({})

    function binaryOf(command: string): string {
        return (command ?? "").trim().split(/\s+/)[0] ?? "";
    }

    function isMissing(command: string): bool {
        const bin = binaryOf(command);
        return bin !== "" && installed[bin] === false;
    }

    function check(commands: var): void {
        const bins = [...new Set(commands.map(c => binaryOf(c)).filter(b => b !== ""))];
        if (bins.length > 0)
            run(["sh", "-c", 'for b in "$@"; do p="$b"; case "$p" in "~/"*) p="$HOME/${p#\\~/}";; esac; if command -v "$p" >/dev/null 2>&1; then echo "1 $b"; else echo "0 $b"; fi; done', "sh", ...bins]);
    }

    stdout: StdioCollector {
        onStreamFinished: {
            const next = Object.assign({}, root.installed);
            for (const line of text.split("\n")) {
                if (line.length > 2)
                    next[line.slice(2)] = line[0] === "1";
            }
            root.installed = next;
        }
    }
}
