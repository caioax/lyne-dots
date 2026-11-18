const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

// A Hyprland bind that calls hl.dsp.global("quickshell:<name>") does nothing
// unless the shell has a GlobalShortcut with that name, and nothing reports
// the mismatch.
const ROOT = path.join(__dirname, "../..");
const SHELL = path.join(ROOT, "quickshell/.config/quickshell");
const HYPR = path.join(ROOT, "hyprland/.config/hypr");

function files(dir, ext) {
    return fs.readdirSync(dir, { withFileTypes: true }).flatMap(e => {
        const p = path.join(dir, e.name);
        if (e.isDirectory())
            return files(p, ext);
        return e.name.endsWith(ext) ? [p] : [];
    });
}

function shortcutNames() {
    const names = new Set();
    for (const file of files(SHELL, ".qml")) {
        const text = fs.readFileSync(file, "utf8");
        for (const m of text.matchAll(/GlobalShortcut\s*\{[^}]*?\bname:\s*"([^"]+)"/gs))
            names.add(m[1]);
    }
    return names;
}

function boundGlobals() {
    const used = [];
    for (const file of files(HYPR, ".lua")) {
        const text = fs.readFileSync(file, "utf8");
        for (const m of text.matchAll(/hl\.dsp\.global\("quickshell:([^"]+)"\)/g))
            used.push({ name: m[1], file: path.relative(ROOT, file) });
    }
    return used;
}

test("every quickshell: global a bind calls has a GlobalShortcut", () => {
    const names = shortcutNames();
    const used = boundGlobals();
    assert.ok(used.length > 0);
    const missing = used.filter(u => !names.has(u.name)).map(u => `${u.name} (${u.file})`);
    assert.deepEqual(missing, []);
});

test("the notification history bind is there, with no keys by default", () => {
    const text = fs.readFileSync(path.join(HYPR, "conf/keybinds.lua"), "utf8");
    const line = text.split("\n").find(l => /^bind\("notifications",/.test(l));
    assert.ok(line, "no notifications bind");
    assert.match(line, /"Notifications",\s*"",\s*hl\.dsp\.global\("quickshell:notifications"\)/);
});
