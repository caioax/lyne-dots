const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

// Two Shortcuts with the same sequence in one window are ambiguous: Qt fires
// neither (Ctrl+F stopped focusing the Settings search on the Wallpaper page,
// which had its own). Pages and rows live in the Settings window, so none of
// them may bind a key the window binds.
const SETTINGS = path.join(__dirname, "../../quickshell/.config/quickshell/modules/settings");
const WINDOW = path.join(SETTINGS, "SettingsWindow.qml");

function qmlFiles(dir) {
    return fs.readdirSync(dir, { withFileTypes: true }).flatMap(e => {
        const p = path.join(dir, e.name);
        if (e.isDirectory())
            return qmlFiles(p);
        return e.name.endsWith(".qml") ? [p] : [];
    });
}

// The body of each `Shortcut { … }` (handlers inside have braces of their own)
function shortcutBodies(text) {
    const bodies = [];
    for (const m of text.matchAll(/\bShortcut\s*\{/g)) {
        let depth = 1;
        let i = m.index + m[0].length;
        const start = i;
        for (; i < text.length && depth > 0; i++)
            depth += text[i] === "{" ? 1 : text[i] === "}" ? -1 : 0;
        bodies.push(text.slice(start, i - 1));
    }
    return bodies;
}

// The string sequences of every Shortcut in a file (its own properties, not
// those of nested objects), lowercased
function sequences(text) {
    const found = [];
    for (const body of shortcutBodies(text)) {
        const one = body.match(/\bsequence:\s*"([^"]+)"/);
        if (one)
            found.push(one[1]);
        const many = body.match(/\bsequences:\s*\[([^\]]*)\]/);
        if (many)
            found.push(...[...many[1].matchAll(/"([^"]+)"/g)].map(s => s[1]));
    }
    return found.map(s => s.toLowerCase());
}

test("the window's shortcuts are found", () => {
    const own = sequences(fs.readFileSync(WINDOW, "utf8"));
    for (const s of ["escape", "ctrl+f", "/", "ctrl+tab"])
        assert.ok(own.includes(s), `SettingsWindow.qml binds ${s}`);
});

test("no page or row binds a key the Settings window binds", () => {
    const own = new Set(sequences(fs.readFileSync(WINDOW, "utf8")));
    const clashes = [];
    for (const file of qmlFiles(SETTINGS)) {
        if (file === WINDOW)
            continue;
        for (const s of sequences(fs.readFileSync(file, "utf8")))
            if (own.has(s))
                clashes.push(`${path.relative(SETTINGS, file)}: ${s}`);
    }
    assert.deepEqual(clashes, []);
});
