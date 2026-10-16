// The shell's translations: services/i18n.js (plural rules, language
// resolution, formatting, pseudo-language), tools/i18n.js (extractor,
// checks, bare-string lint) on small throwaway shells, and the real files:
// complete pt_BR, nothing extra, placeholders matching, literal arguments,
// no new bare strings

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {
    load
} = require("./load");

const lib = load("services/i18n.js");
const tool = require("../../tools/i18n.js");

const SHELL = process.env.LYNE_TEST_SHELL || path.resolve(__dirname, "../../quickshell/.config/quickshell");

// A shell with only the given files (and the real services/i18n.js)
function fakeShell(t, files) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "lyne-i18n-"));
    t.after(() => fs.rmSync(dir, {
        recursive: true,
        force: true
    }));
    fs.mkdirSync(path.join(dir, "services"));
    fs.copyFileSync(path.join(SHELL, "services/i18n.js"), path.join(dir, "services/i18n.js"));
    for (const [name, text] of Object.entries(files)) {
        fs.mkdirSync(path.dirname(path.join(dir, name)), {
            recursive: true
        });
        fs.writeFileSync(path.join(dir, name), typeof text === "string" ? text : tool.serialize(text));
    }
    return dir;
}

test("locale codes normalize from LANG forms", () => {
    assert.equal(lib.normalize("pt_BR.UTF-8"), "pt_BR");
    assert.equal(lib.normalize("pt-br"), "pt_BR");
    assert.equal(lib.normalize("de_DE@euro"), "de_DE");
    assert.equal(lib.normalize("C"), "");
    assert.equal(lib.normalize("POSIX"), "");
    assert.equal(lib.normalize(undefined), "");
    assert.equal(lib.languageOf("pt_BR"), "pt");
});

test("resolve: exact code, then the same language, then English", () => {
    const available = ["en", "pt_BR"];
    assert.equal(lib.resolve("pt_BR.UTF-8", available), "pt_BR");
    assert.equal(lib.resolve("pt_PT.UTF-8", available), "pt_BR");
    assert.equal(lib.resolve("de_DE.UTF-8", available), "en");
    assert.equal(lib.resolve("C", available), "en");
    // LANGUAGE, LC_ALL, LC_MESSAGES, LANG in order; LANGUAGE as a list
    assert.equal(lib.resolve(["", "", "", "pt_BR.UTF-8"], available), "pt_BR");
    assert.equal(lib.resolve(["de:pt_BR:en", "", "", "en_US.UTF-8"], available), "pt_BR");
    assert.equal(lib.resolve(["en_US", "", "", "pt_BR.UTF-8"], available), "en");
});

test("plural rules: Portuguese 0 and 1 singular, English 1 only, Russian three forms", () => {
    assert.deepEqual([0, 1, 2, 5].map(n => lib.pluralIndex("en", n)), [1, 0, 1, 1]);
    assert.deepEqual([0, 1, 2, 5].map(n => lib.pluralIndex("pt_BR", n)), [0, 0, 1, 1]);
    assert.deepEqual([1, 2, 5, 11, 21, 22, 25].map(n => lib.pluralIndex("ru", n)), [0, 1, 2, 2, 0, 1, 2]);
    assert.equal(lib.pluralForms("ja"), 1);
    assert.equal(lib.pluralIndex("ja", 7), 0);
    // Unknown languages follow English
    assert.equal(lib.pluralForms("xx"), 2);
    assert.equal(lib.pluralIndex("xx", 1), 0);
});

test("format fills %1..%9 and leaves the rest", () => {
    assert.equal(lib.format("Open %1 on %2", ["Zen", "HDMI-A-1"]), "Open Zen on HDMI-A-1");
    assert.equal(lib.format("%2 before %1", ["a", "b"]), "b before a");
    assert.equal(lib.format("%1 and %3", ["a"]), "a and %3");
    assert.equal(lib.format("100%", []), "100%");
    assert.deepEqual(lib.placeholders("%2 %n %1 %1"), ["%1", "%2", "%n"]);
});

test("lookup: untranslated is null, contexts apart", () => {
    const strings = {
        Lock: "Bloquear",
        Empty: "",
        "%n file": ["%n arquivo", "%n arquivos"],
        Blank: ["", ""],
        _context: {
            "keyboard key": {
                Lock: "Lock"
            }
        }
    };
    assert.equal(lib.lookup(strings, "Lock", ""), "Bloquear");
    assert.equal(lib.lookup(strings, "Lock", "keyboard key"), "Lock");
    assert.equal(lib.lookup(strings, "Empty", ""), null);
    assert.equal(lib.lookup(strings, "Missing", ""), null);
    assert.equal(lib.lookup(strings, "Missing", "nowhere"), null);
    assert.equal(lib.lookup(strings, "Blank", ""), null);
    assert.deepEqual(lib.lookup(strings, "%n file", ""), ["%n arquivo", "%n arquivos"]);
});

test("pseudo-language: accented, ~40% longer, placeholders and tags kept", () => {
    const p = lib.pseudo("Open %1 in <b>Settings</b>");
    assert.match(p, /^\[.*\]$/);
    assert.ok(p.includes("%1") && p.includes("<b>") && p.includes("</b>"));
    assert.ok(!/[a-z]{2}/.test(p.replace(/%1|<\/?b>/g, "")), p);
    const plain = "Choose picture";
    assert.ok(lib.pseudo(plain).length >= plain.length * 1.4, lib.pseudo(plain));
    assert.equal(lib.pseudo("  "), "  ");
});

test("extractor: literal calls, contexts, plurals; comments and templates skipped", t => {
    const dir = fakeShell(t, {
        "modules/A.qml": [
            "Text {",
            "    // I18n.tr(\"In a comment\")",
            "    text: I18n.tr(\"Open %1\", name)",
            "    label: I18n.trc('power menu', \"Lock\")",
            "    description: I18n.trn(\"%n update\", \"%n updates\", count)",
            "    property var cmd: [\"sh\", \"-c\", `echo \"(\"",
            "        and more ' quotes`]",
            "    readonly property var page: { label: I18n.noop(\"Theme\") }",
            "    title: I18n.tr(\"Open %1\", other)",
            "}"
        ].join("\n")
    });
    const found = tool.extract(dir);
    assert.deepEqual(found.errors, []);
    assert.deepEqual([...found.strings.keys()], ["Open %1", "%n update", "Theme"]);
    assert.equal(found.strings.get("Open %1").refs.length, 2);
    assert.equal(found.strings.get("%n update").plural, "%n updates");
    assert.deepEqual([...found.contexts.get("power menu").keys()], ["Lock"]);
});

test("extractor: folders linked into the shell are read (a sandbox copy)", t => {
    const real = fakeShell(t, {
        "modules/A.qml": "text: I18n.tr(\"Linked\")"
    });
    const copy = fakeShell(t, {});
    fs.symlinkSync(path.join(real, "modules"), path.join(copy, "modules"));
    assert.deepEqual([...tool.extract(copy).strings.keys()], ["Linked"]);
});

test("lexer: regex literals with quotes, parens or // inside don't derail it", () => {
    const text = [
        "const a = s.replace(/%(.)/g, f).replace(/\\//g, \"-\");",
        "const b = /\"[^\"]*\"/.test(x) ? 1 : 2 / 3;",
        "text: I18n.tr(\"After the regexes\")",
        "label: \"Bare text\""
    ].join("\n");
    const {
        calls,
        literals
    } = tool.scan(text, false);
    assert.deepEqual(calls.map(c => c.args), [["After the regexes"]]);
    const bare = literals.find(l => l.value === "Bare text");
    assert.equal(bare.callee, "");
});

test("extractor: keybind groups and descriptions from keybinds.lua, not the built ones", t => {
    const dir = fakeShell(t, {
        "A.qml": "text: I18n.tr(\"Apps\")",
        "lua/keybinds.lua": [
            "bind(\"terminal\",     \"Apps\", \"Terminal\",     mainMod .. \" + return\", open(\"terminal\"))",
            "    bind(\"workspace-\" .. i, \"Workspaces\", \"Go to workspace \" .. i, keys, fn)",
            "-- bind(\"commented\", \"Nope\", \"Nope\")"
        ].join("\n")
    });
    process.env.LYNE_I18N_LUA = path.join(dir, "lua");
    t.after(() => delete process.env.LYNE_I18N_LUA);
    const found = tool.extract(dir);
    assert.deepEqual(found.errors, []);
    assert.deepEqual([...found.strings.keys()], ["Apps", "Terminal"]);
    assert.equal(found.strings.get("Apps").refs.length, 2);
});

test("extractor: non-literal and concatenated arguments are errors", t => {
    const dir = fakeShell(t, {
        "A.qml": [
            "text: I18n.tr(name)",
            "text: I18n.tr(\"Hello \" + name)",
            "text: I18n.trn(\"%n file\", \"%n files\")",
            "text: I18n.trc(ctx, \"Lock\")",
            "text: I18n.tr(\"\")",
            "text: root.tr(\"Only in I18n.qml\")"
        ].join("\n"),
        "services/I18n.qml": "label: root.tr(\"Automatic\")"
    });
    const found = tool.extract(dir);
    assert.equal(found.errors.length, 5, found.errors.join("\n"));
    assert.match(found.errors[0], /A\.qml:1: .*must be a string literal/);
    assert.match(found.errors[1], /A\.qml:2: .*single string literal/);
    assert.deepEqual([...found.strings.keys()], ["Automatic"]);
});

test("extractor: one English string can't be plain and plural at once", t => {
    const dir = fakeShell(t, {
        "A.qml": "text: I18n.tr(\"%n file\")\ntext: I18n.trn(\"%n file\", \"%n files\", n)"
    });
    assert.match(tool.extract(dir).errors.join("\n"), /both as a plain and a plural/);
});

test("check: complete language, placeholders, plural forms, files up to date", t => {
    const qml = "text: I18n.tr(\"Open %1\", a)\ntext: I18n.trn(\"%n update\", \"%n updates\", n)\ntext: I18n.trc(\"menu\", \"Lock\")";
    const good = {
        _meta: {
            name: "Português (Brasil)"
        },
        "Open %1": "Abrir %1",
        "%n update": ["%n atualização", "%n atualizações"],
        _context: {
            menu: {
                Lock: "Bloquear"
            }
        }
    };
    const index = [{
        code: "pt_BR",
        name: "Português (Brasil)",
        translated: 100
    }];
    const ok = fakeShell(t, {
        "A.qml": qml,
        "i18n/pt_BR.json": good,
        "i18n/languages.json": index
    });
    assert.deepEqual(tool.check(ok).problems, []);

    const bad = fakeShell(t, {
        "A.qml": qml,
        "i18n/pt_BR.json": Object.assign({}, good, {
            "Open %1": "Abrir",
            "%n update": ["%n atualização"],
            _context: {
                menu: {
                    Lock: ""
                }
            }
        }),
        "i18n/languages.json": index
    });
    const problems = tool.check(bad).problems.join("\n");
    assert.match(problems, /"Open %1" has no placeholders, the English %1/);
    assert.match(problems, /"%n update" needs 2 plural form/);
    assert.match(problems, /"menu \| Lock" isn't translated/);

    // A string gone from the code, a new one, a stale index
    const stale = fakeShell(t, {
        "A.qml": qml + "\ntext: I18n.tr(\"New\")",
        "i18n/pt_BR.json": Object.assign({}, good, {
            Gone: "Sumiu"
        }),
        "i18n/languages.json": []
    });
    const staleProblems = tool.check(stale).problems.join("\n");
    assert.match(staleProblems, /pt_BR\.json is out of date/);
    assert.match(staleProblems, /"New" isn't translated/);
    assert.match(staleProblems, /languages\.json is out of date/);
});

test("check: other languages may be partial, pt_BR may not be missing", t => {
    const dir = fakeShell(t, {
        "A.qml": "text: I18n.tr(\"Open\")\ntext: I18n.tr(\"Close\")",
        "i18n/de.json": {
            _meta: {
                name: "Deutsch"
            },
            Open: "Öffnen",
            Close: ""
        },
        "i18n/languages.json": [{
            code: "de",
            name: "Deutsch",
            translated: 50
        }]
    });
    assert.deepEqual(tool.check(dir).problems, ["pt_BR.json is missing"]);
    assert.deepEqual(tool.stats(dir).map(s => [s.code, s.done, s.total]), [["de", 1, 2]]);
});

test("bare strings: UI properties with prose outside I18n, per file", t => {
    const dir = fakeShell(t, {
        "A.qml": [
            "Item {",
            "    text: \"Choose picture\"",
            "    label: I18n.tr(\"Choose picture\")",
            "    label: Quickshell.env(\"USER\")",
            "    text: \"\\u{f0004}\"",
            "    description: ok ? \"Custom picture\" : \"No picture\"",
            "    title: \"Brand name\" // i18n-ignore",
            "    property string path: \"Not UI text\"",
            "    font.family: \"JetBrains Mono\"",
            "    text: \"%1 left\".arg(n)",
            "}"
        ].join("\n")
    });
    assert.deepEqual(tool.bareStrings(dir), {
        "A.qml": 3
    });
    const cmp = tool.compareBaseline({
        "A.qml": 3,
        "B.qml": 1
    }, {
        "A.qml": 4,
        "C.qml": 2
    });
    assert.deepEqual(cmp.grew, ["B.qml: 1 (baseline 0)"]);
    assert.deepEqual(cmp.shrank, ["A.qml: 3 (baseline 4)", "C.qml: 0 (baseline 2)"]);
});

test("the shell's translations pass the check (pt_BR complete, nothing extra, placeholders, literal arguments)", () => {
    const {
        problems
    } = tool.check(SHELL);
    assert.deepEqual(problems, [], "fix them, or run node tools/i18n.js extract");
});

test("no new bare UI strings (tests/js/i18n-bare-baseline.txt)", () => {
    const {
        grew
    } = tool.compareBaseline(tool.bareStrings(SHELL), tool.readBaseline());
    assert.deepEqual(grew, [], "wrap them in I18n.tr (or // i18n-ignore when it isn't UI text)");
});
