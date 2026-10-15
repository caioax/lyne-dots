// Loads a QML JavaScript library (".pragma library", no Qt) in node and
// returns its top-level functions and variables. The pragma line is blanked,
// not removed, so line numbers in errors match the file. The code runs in
// this realm, so its arrays and objects compare with assert.deepStrictEqual.

const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

// LYNE_TEST_SHELL points the tests at another copy of the shell's config
const SHELL = process.env.LYNE_TEST_SHELL || path.resolve(__dirname, "../../quickshell/.config/quickshell");

function load(relative) {
    const file = path.join(SHELL, relative);
    const source = fs.readFileSync(file, "utf8").replace(/^\.(pragma|import)\b.*$/gm, "");
    const names = new Set();
    for (const m of source.matchAll(/^(?:function\s+([A-Za-z_$][\w$]*)|(?:var|const|let)\s+([A-Za-z_$][\w$]*))/gm))
        names.add(m[1] ?? m[2]);
    const exports = [...names].map(n => `${n}: ${n}`).join(", ");
    return vm.compileFunction(`${source}\nreturn { ${exports} };`, [], {
        filename: file
    })();
}

module.exports = {
    load,
    fixture: name => fs.readFileSync(path.join(__dirname, "fixtures", name), "utf8")
};
