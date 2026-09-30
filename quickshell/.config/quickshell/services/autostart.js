.pragma library

// XDG autostart entries for Settings › System › Autostart (AutostartService).
// ~/.config/autostart/*.desktop and /etc/xdg/autostart/*.desktop are started
// by systemd's xdg-autostart-generator in uwsm sessions: a user file hides
// the system file with the same name, and an entry is skipped when it's
// Hidden, has X-systemd-skip, or its OnlyShowIn / NotShowIn leave the
// current desktop out. Turning a system entry off writes a small user file
// with Hidden=true and X-Lyne-Override=true (removed to turn it back on).

// Keys of the [Desktop Entry] group; localized keys (Name[pt]) are ignored
function parseDesktop(text) {
    const out = {};
    let inEntry = false;
    for (const raw of String(text ?? "").split("\n")) {
        const line = raw.trim();
        if (line === "" || line.startsWith("#"))
            continue;
        if (line.startsWith("[")) {
            inEntry = line === "[Desktop Entry]";
            continue;
        }
        if (!inEntry)
            continue;
        const eq = line.indexOf("=");
        if (eq <= 0)
            continue;
        const key = line.slice(0, eq).trim();
        if (key.includes("[") || key in out)
            continue;
        out[key] = line.slice(eq + 1).trim();
    }
    return out;
}

function _list(value) {
    return String(value ?? "").split(";").map(s => s.trim()).filter(s => s !== "");
}

function _bool(value) {
    return String(value ?? "").trim().toLowerCase() === "true";
}

function basename(path) {
    return String(path).split("/").pop();
}

// Why an enabled entry doesn't start on `desktops` (XDG_CURRENT_DESKTOP,
// "A:B" allowed): "" when it starts
function skipReason(keys, desktops) {
    const current = String(desktops ?? "").split(":").filter(d => d !== "");
    const only = _list(keys.OnlyShowIn);
    if (only.length > 0 && !only.some(d => current.includes(d)))
        return "desktop";
    const not = _list(keys.NotShowIn);
    if (not.some(d => current.includes(d)))
        return "desktop";
    if (_bool(keys["X-systemd-skip"]))
        return "skip";
    if (keys.Type && keys.Type !== "Application")
        return "type";
    return "";
}

// Desktops an entry is meant for, for "only starts on KDE" texts
function meantFor(keys) {
    const only = _list(keys.OnlyShowIn);
    return only.join(", ");
}

// user / system: [{ path, text }]. Returns one entry per file name:
// { id, path, userPath, systemPath, source: "user" | "system", override,
//   name, exec, icon, enabled, reason, meantFor }
// `override` = our Hidden file over a system entry (name/exec/icon then
// come from the system file)
function entries(user, system, desktops) {
    const byId = {};
    for (const f of system ?? []) {
        const id = basename(f.path);
        if (!id.endsWith(".desktop") || byId[id])
            continue;
        byId[id] = {
            id,
            system: parseDesktop(f.text),
            systemPath: f.path
        };
    }
    for (const f of user ?? []) {
        const id = basename(f.path);
        if (!id.endsWith(".desktop"))
            continue;
        byId[id] = Object.assign(byId[id] ?? {
            id
        }, {
            user: parseDesktop(f.text),
            userPath: f.path
        });
    }

    return Object.keys(byId).sort().map(id => {
        const e = byId[id];
        const keys = e.user ?? e.system;
        const override = e.user !== undefined && _bool(e.user["X-Lyne-Override"]);
        // What it would run: our override only hides the system file
        const shown = override && e.system ? e.system : keys;
        const enabled = !_bool(keys.Hidden);
        return {
            id,
            path: e.userPath ?? e.systemPath,
            userPath: e.userPath ?? "",
            systemPath: e.systemPath ?? "",
            source: e.user ? "user" : "system",
            override,
            name: shown.Name || id.replace(/\.desktop$/, ""),
            exec: shown.Exec ?? "",
            icon: shown.Icon ?? "",
            enabled,
            reason: skipReason(shown, desktops),
            meantFor: meantFor(shown)
        };
    });
}

// `systemctl --user show 'app-*@autostart.service' -p Id,SourcePath,
// ActiveState,SubState,Result` -> { "<source path>": { unit, active, sub,
// result } }
function parseUnits(text) {
    const out = {};
    for (const block of String(text ?? "").split(/\n\s*\n/)) {
        const props = {};
        for (const line of block.split("\n")) {
            const eq = line.indexOf("=");
            if (eq > 0)
                props[line.slice(0, eq)] = line.slice(eq + 1);
        }
        if (props.SourcePath)
            out[props.SourcePath] = {
                unit: props.Id ?? "",
                active: props.ActiveState ?? "",
                sub: props.SubState ?? "",
                result: props.Result ?? ""
            };
    }
    return out;
}

// "running" | "exited" | "failed" | "" (not started, or not known)
function unitStatus(unit) {
    if (!unit)
        return "";
    if (unit.active === "active" || unit.active === "activating")
        return "running";
    if (unit.active === "failed" || (unit.result !== "" && unit.result !== "success" && unit.result !== "exec-condition"))
        return "failed";
    if (unit.active === "inactive" && unit.result === "success" && unit.sub === "dead")
        return "exited";
    return "";
}

// `list` output of scripts/autostart.sh: records "\x1e<scope>\t<path>\n<text>"
// -> { user: [{ path, text }], system: [...], units: "<systemctl text>",
//      target: "active" | ... }
function parseList(text) {
    const out = {
        user: [],
        system: [],
        units: "",
        target: ""
    };
    for (const record of String(text ?? "").split("\x1e")) {
        const nl = record.indexOf("\n");
        if (nl < 0)
            continue;
        const head = record.slice(0, nl);
        const body = record.slice(nl + 1);
        const tab = head.indexOf("\t");
        const scope = tab < 0 ? head : head.slice(0, tab);
        const path = tab < 0 ? "" : head.slice(tab + 1);
        if (scope === "user" || scope === "system")
            out[scope].push({
                path,
                text: body
            });
        else if (scope === "units")
            out.units = body;
        else if (scope === "target")
            out.target = body.trim();
    }
    return out;
}

// ============================================================================
// RUNNING APPS
// ============================================================================

const _interpreters = ["sh", "bash", "zsh", "dash", "fish", "python", "python3", "perl", "node"];

// What a command runs: basename of the last command of "a && b" / "a; b",
// "" for nothing
function programOf(command) {
    const parts = String(command ?? "").split(/&&|;|\|\|/);
    const last = (parts[parts.length - 1] ?? "").trim().split(/\s+/);
    let i = 0;
    // env VAR=x prog, VAR=x prog
    while (i < last.length && (last[i] === "env" || /^[A-Za-z_][A-Za-z0-9_]*=/.test(last[i])))
        i++;
    if (i < last.length && _interpreters.includes(basename(last[i])) && last[i + 1] && !last[i + 1].startsWith("-"))
        i++;
    return i < last.length ? basename(last[i]) : "";
}

// `ps -eo args=` lines -> set of program basenames (scripts run by an
// interpreter count as the script)
function runningPrograms(psText) {
    const out = {};
    for (const line of String(psText ?? "").split("\n")) {
        const words = line.trim().split(/\s+/);
        if (words[0] === "")
            continue;
        const first = basename(words[0]);
        out[first] = true;
        if (_interpreters.includes(first)) {
            const script = words.slice(1).find(w => !w.startsWith("-"));
            if (script)
                out[basename(script)] = true;
        }
    }
    return out;
}

function isRunning(command, running) {
    const program = programOf(command);
    return program !== "" && running[program] === true;
}
