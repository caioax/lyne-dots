.pragma library

// Parsing of nmcli's terse output for NetworkService. `nmcli -g` separates
// fields with ":" and escapes the ones inside values as "\:" (and "\" as
// "\\"); fields with no value come out as empty lines.

// Fields of one line, unescaped
function fields(line) {
    const result = [];
    let current = "";
    for (let i = 0; i < line.length; i++) {
        const c = line[i];
        if (c === "\\" && i + 1 < line.length) {
            current += line[++i];
        } else if (c === ":") {
            result.push(current);
            current = "";
        } else {
            current += c;
        }
    }
    result.push(current);
    return result;
}

// The connected wired device from `nmcli -g DEVICE,TYPE,STATE,CONNECTION
// device`: { device, connection }, or null. "connected (externally)" counts
// (set up outside NetworkManager); "connecting (...)" and "unavailable" (no
// cable) don't
function wiredConnection(text) {
    for (const line of text.split("\n")) {
        const [device, type, state, connection] = fields(line);
        if (type !== "ethernet")
            continue;
        if (state === "connected" || (state ?? "").startsWith("connected ("))
            return {
                device: device,
                connection: connection ?? ""
            };
    }
    return null;
}

// `nmcli -g IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,CAPABILITIES.SPEED device show
// <device>`: { ip, gateway, dns, speed } (speed in Mb/s, 0 when unknown).
// Only the first address and DNS server
function deviceDetails(text) {
    const lines = text.split("\n");
    const first = value => fields(value ?? "").join(":").split(" | ")[0];
    return {
        ip: first(lines[0]).split("/")[0],
        gateway: first(lines[1]),
        dns: first(lines[2]),
        speed: parseInt(lines[3] ?? "") || 0
    };
}

// "1 Gb/s", "2.5 Gb/s", "100 Mb/s"; "" when unknown
function speedLabel(mbps) {
    if (!(mbps > 0))
        return "";
    if (mbps >= 1000)
        return `${Math.round(mbps / 100) / 10} Gb/s`;
    return `${mbps} Mb/s`;
}
