import QtQuick
import Quickshell.Io

// HTTP GET through curl in a child process. XMLHttpRequest would load Qt's
// network stack into the shell (a QNetworkAccessManager thread, TLS) and
// keep it for the whole session, about 9 MB more RSS for a few requests a
// day.
//
//   HttpGet { id: http }
//   http.get(url, { "Header": "value" }, (status, body) => { ... })
//
// status is the HTTP code, or 0 when there was no answer (no connection,
// DNS, timeout). Each get() runs its own curl, so requests can overlap and
// every callback is called once
QtObject {
    id: root

    // Seconds for the whole request
    property int timeout: 20

    function get(url: string, headers: var, onDone: var): void {
        const args = ["curl", "-s", "-L", "--compressed", "--max-time", String(timeout), "-w", "\n%{http_code}"];
        for (const name in headers ?? {})
            args.push("-H", name + ": " + headers[name]);
        args.push(url);
        request.createObject(root, {
            command: args,
            onDone: onDone
        });
    }

    readonly property Component request: Component {
        Process {
            id: proc

            property var onDone: null

            running: true

            stdout: StdioCollector {
                id: out
            }

            onExited: {
                // curl prints the status code after the body ("000" without
                // an answer)
                const text = out.text;
                const cut = text.lastIndexOf("\n");
                const status = parseInt(text.slice(cut + 1)) || 0;
                const done = proc.onDone;
                proc.destroy();
                if (typeof done === "function")
                    done(status, cut >= 0 ? text.slice(0, cut) : "");
            }
        }
    }
}
