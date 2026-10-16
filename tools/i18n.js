#!/usr/bin/env node
// =============================================================================
// i18n.js - The shell's translation files, kept in sync with its code
// =============================================================================
// Reads every I18n.tr/trn/trc/noop call in the shell (quickshell/.config/
// quickshell) and keeps i18n/<code>.json and i18n/languages.json in step.
//
// Usage: node tools/i18n.js extract          add new strings ("" = to
//                                            translate), drop the gone ones
//        node tools/i18n.js check            what the tests run: literal
//                                            arguments, files up to date,
//                                            placeholders, complete languages
//        node tools/i18n.js add <code> <name> start a language (pt_PT
//                                            "Português (Portugal)")
//        node tools/i18n.js stats            translated share per language
//        node tools/i18n.js lint [--update]  UI strings still outside
//                                            I18n, per file, against
//                                            tests/js/i18n-bare-baseline.txt
//
// LYNE_I18N_SHELL points it at another copy of the shell (the tests do).
// =============================================================================

"use strict";

const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const REPO = path.resolve(__dirname, "..");
const SHELL = process.env.LYNE_I18N_SHELL || path.join(REPO, "quickshell/.config/quickshell");
const BASELINE = process.env.LYNE_I18N_BASELINE || path.join(REPO, "tests/js/i18n-bare-baseline.txt");

// Languages that must be fully translated (the tests fail otherwise);
// others may be partial (English shows for the rest)
const COMPLETE = ["pt_BR"];

// The I18n helpers the shell uses (plural rules, placeholders)
function loadLib(shell) {
    const file = path.join(shell, "services/i18n.js");
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma\b.*$/m, "");
    return vm.compileFunction(`${source}\nreturn { pluralForms, placeholders };`, [], {
        filename: file
    })();
}

// =============================================================================
// Reading the source
// =============================================================================

const CALLS = {
    tr: ["text"],
    trc: ["context", "text"],
    trn: ["singular", "plural"],
    noop: ["text"]
};

const ESCAPES = {
    n: "\n",
    t: "\t",
    r: "\r",
    b: "\b",
    f: "\f",
    v: "\v",
    0: "\0"
};

// Reads a string literal starting at text[i] (a quote); returns its value
// and the index after it
function readLiteral(text, i) {
    const quote = text[i];
    let value = "";
    let j = i + 1;
    while (j < text.length && text[j] !== quote) {
        if (text[j] === "\\") {
            const next = text[j + 1];
            if (next === "u") {
                const m = text.slice(j).match(/^\\u(?:\{([0-9a-fA-F]+)\}|([0-9a-fA-F]{4}))/);
                if (m) {
                    value += String.fromCodePoint(parseInt(m[1] ?? m[2], 16));
                    j += m[0].length;
                    continue;
                }
            }
            if (next === "x") {
                value += String.fromCharCode(parseInt(text.substr(j + 2, 2), 16));
                j += 4;
                continue;
            }
            value += ESCAPES[next] ?? next;
            j += 2;
            continue;
        }
        // Quotes end at the line (a stray one in a regex), templates don't
        if (text[j] === "\n" && quote !== "`")
            break;
        value += text[j];
        j++;
    }
    return {
        value,
        end: j + 1
    };
}

// Walks a QML/JS file outside comments: every string literal (with the
// callee of the call it sits in, "" when none) and every I18n call
// (`root.` too inside the I18n singleton itself)
function scan(text, self) {
    const literals = [];
    const calls = [];
    const parens = [];
    const lineAt = i => text.slice(0, i).split("\n").length;
    const ident = /[\w$]/;
    const prefix = self ? /(?:I18n|root)\.(tr|trn|trc|noop)\s*\($/ : /I18n\.(tr|trn|trc|noop)\s*\($/;
    let i = 0;
    while (i < text.length) {
        const ch = text[i];
        const two = text.substr(i, 2);
        if (two === "//") {
            const nl = text.indexOf("\n", i);
            i = nl < 0 ? text.length : nl;
            continue;
        }
        if (two === "/*") {
            const end = text.indexOf("*/", i + 2);
            i = end < 0 ? text.length : end + 2;
            continue;
        }
        if (ch === '"' || ch === "'" || ch === "`") {
            const lit = readLiteral(text, i);
            literals.push({
                value: lit.value,
                start: i,
                end: lit.end,
                callee: parens.length ? parens[parens.length - 1] : "",
                template: ch === "`"
            });
            i = lit.end;
            continue;
        }
        if (ch === "(") {
            const before = text.slice(Math.max(0, i - 40), i + 1);
            const call = before.match(prefix);
            const callee = before.slice(0, -1).match(/([\w$]+)\s*$/);
            parens.push(call ? "I18n." + call[1] : callee && ident.test(text[i - 1] ?? "") ? callee[1] : "");
            if (call)
                calls.push(readCall(text, i + 1, call[1], lineAt(i)));
        } else if (ch === ")") {
            parens.pop();
        }
        i++;
    }
    return {
        literals,
        calls
    };
}

// The literal arguments of an I18n call whose "(" is just before `i`
function readCall(text, i, fn, line) {
    const names = CALLS[fn];
    const args = [];
    let j = i;
    const skip = () => {
        while (j < text.length && /\s/.test(text[j]))
            j++;
    };
    for (let k = 0; k < names.length; k++) {
        skip();
        if (text[j] !== '"' && text[j] !== "'")
            return {
                fn,
                line,
                error: `I18n.${fn}: the ${names[k]} must be a string literal`
            };
        const lit = readLiteral(text, j);
        args.push(lit.value);
        j = lit.end;
        skip();
        const last = k === names.length - 1;
        const ok = last ? (fn === "trn" ? text[j] === "," : text[j] === "," || text[j] === ")") : text[j] === ",";
        if (!ok)
            return {
                fn,
                line,
                error: `I18n.${fn}: the ${names[k]} must be a single string literal (no +, use %1 and arguments)`
            };
        j++;
    }
    return {
        fn,
        line,
        args
    };
}

function sourceFiles(shell) {
    const out = [];
    const walk = dir => {
        for (const e of fs.readdirSync(dir, {
                withFileTypes: true
            }).sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0)) {
            const p = path.join(dir, e.name);
            // Linked folders count too (a sandbox copy of the shell)
            const isDir = e.isDirectory() || (e.isSymbolicLink() && fs.statSync(p, {
                throwIfNoEntry: false
            })?.isDirectory());
            if (isDir) {
                if (e.name !== "i18n" && !e.name.startsWith("."))
                    walk(p);
            } else if (/\.(qml|js)$/.test(e.name)) {
                out.push(p);
            }
        }
    };
    walk(shell);
    return out;
}

// Every translatable string in the code, in source order:
// { strings: Map(key -> entry), contexts: Map(ctx -> Map(key -> entry)), errors }
function extract(shell = SHELL) {
    const strings = new Map();
    const contexts = new Map();
    const errors = [];
    for (const file of sourceFiles(shell)) {
        const rel = path.relative(shell, file);
        const self = rel === path.join("services", "I18n.qml");
        const {
            calls
        } = scan(fs.readFileSync(file, "utf8"), self);
        for (const c of calls) {
            const where = `${rel}:${c.line}`;
            if (c.error) {
                errors.push(`${where}: ${c.error}`);
                continue;
            }
            let table = strings;
            let key = c.args[0];
            let entry = {
                kind: "text",
                source: key
            };
            if (c.fn === "trc") {
                if (!contexts.has(c.args[0]))
                    contexts.set(c.args[0], new Map());
                table = contexts.get(c.args[0]);
                key = c.args[1];
                entry.source = key;
            } else if (c.fn === "trn") {
                entry = {
                    kind: "plural",
                    source: c.args[1],
                    singular: c.args[0],
                    plural: c.args[1]
                };
            }
            if (key === "") {
                errors.push(`${where}: empty string`);
                continue;
            }
            const seen = table.get(key);
            if (!seen) {
                table.set(key, Object.assign(entry, {
                    refs: [where]
                }));
            } else if (seen.kind !== entry.kind || seen.plural !== entry.plural) {
                errors.push(`${where}: "${key}" is used both as a plain and a plural string (or with two plurals); first at ${seen.refs[0]}`);
            } else {
                seen.refs.push(where);
            }
        }
    }
    return {
        strings,
        contexts,
        errors
    };
}

// =============================================================================
// Language files
// =============================================================================

function i18nDir(shell) {
    return path.join(shell, "i18n");
}

function languageCodes(shell) {
    const dir = i18nDir(shell);
    if (!fs.existsSync(dir))
        return [];
    return fs.readdirSync(dir).filter(f => /^[a-z]{2,3}(_[A-Z]{2})?\.json$/.test(f)).map(f => f.slice(0, -5)).sort();
}

function readJson(file) {
    return JSON.parse(fs.readFileSync(file, "utf8"));
}

function emptyValue(entry, forms) {
    return entry.kind === "plural" ? new Array(forms).fill("") : "";
}

// What the file of `code` should hold: its translations, for exactly the
// strings of the code, in source order
function rebuild(code, old, found, lib) {
    const forms = lib.pluralForms(code);
    const keep = (entry, value) => {
        if (entry.kind === "plural")
            return Array.isArray(value) ? value : emptyValue(entry, forms);
        return typeof value === "string" ? value : "";
    };
    const out = {
        _meta: Object.assign({
            name: code
        }, old._meta ?? {})
    };
    for (const [key, entry] of found.strings)
        out[key] = keep(entry, old[key]);
    if (found.contexts.size > 0) {
        out._context = {};
        for (const [ctx, table] of found.contexts) {
            out._context[ctx] = {};
            for (const [key, entry] of table)
                out._context[ctx][key] = keep(entry, old._context?.[ctx]?.[key]);
        }
    }
    return out;
}

function serialize(obj) {
    return JSON.stringify(obj, null, 4) + "\n";
}

// i18n/languages.json: what the shell's language list shows without
// reading every file (translated = share of the strings, in %)
function languagesIndex(shell) {
    const shares = stats(shell);
    return languageCodes(shell).map(code => {
        const s = shares.find(x => x.code === code);
        return {
            code,
            name: s.name,
            translated: Math.floor(s.done * 100 / Math.max(1, s.total))
        };
    });
}

function writeAll(shell, found, lib) {
    const dir = i18nDir(shell);
    fs.mkdirSync(dir, {
        recursive: true
    });
    const changed = [];
    for (const code of languageCodes(shell)) {
        const file = path.join(dir, code + ".json");
        const before = fs.readFileSync(file, "utf8");
        const after = serialize(rebuild(code, JSON.parse(before), found, lib));
        if (after !== before) {
            fs.writeFileSync(file, after);
            changed.push(code + ".json");
        }
    }
    const index = path.join(dir, "languages.json");
    const text = serialize(languagesIndex(shell));
    if (!fs.existsSync(index) || fs.readFileSync(index, "utf8") !== text) {
        fs.writeFileSync(index, text);
        changed.push("languages.json");
    }
    return changed;
}

// =============================================================================
// Checks
// =============================================================================

// Problems with the translations of `code` (an array of messages)
function checkLanguage(code, data, found, lib) {
    const problems = [];
    const forms = lib.pluralForms(code);
    const complete = COMPLETE.includes(code);
    if (typeof data._meta?.name !== "string" || data._meta.name === "" || data._meta.name === code)
        problems.push(`${code}: _meta.name must be the language's own name ("Português (Brasil)")`);
    const same = (a, b) => a.length === b.length && a.every((x, i) => x === b[i]);
    const one = (label, entry, value) => {
        // Missing (an outdated file) reads as untranslated
        if (value === undefined)
            value = emptyValue(entry, forms);
        if (entry.kind === "plural") {
            if (!Array.isArray(value) || value.length !== forms) {
                problems.push(`${code}: "${label}" needs ${forms} plural form(s)`);
                return;
            }
            if (value.every(v => v === "")) {
                if (complete)
                    problems.push(`${code}: "${label}" isn't translated`);
                return;
            }
            const want = lib.placeholders(entry.plural).filter(p => p !== "%n");
            value.forEach((v, i) => {
                if (v === "")
                    problems.push(`${code}: "${label}" plural form ${i + 1} is empty`);
                else if (!same(lib.placeholders(v).filter(p => p !== "%n"), want))
                    problems.push(`${code}: "${label}" form ${i + 1} has ${lib.placeholders(v).join(" ") || "no placeholders"}, the English ${want.join(" ") || "none"}`);
            });
            return;
        }
        if (typeof value !== "string") {
            problems.push(`${code}: "${label}" must be a string`);
            return;
        }
        if (value === "") {
            if (complete)
                problems.push(`${code}: "${label}" isn't translated`);
            return;
        }
        const want = lib.placeholders(entry.source);
        if (!same(lib.placeholders(value), want))
            problems.push(`${code}: "${label}" has ${lib.placeholders(value).join(" ") || "no placeholders"}, the English ${want.join(" ") || "none"}`);
    };
    for (const [key, entry] of found.strings)
        one(key, entry, data[key]);
    for (const [ctx, table] of found.contexts) {
        for (const [key, entry] of table)
            one(`${ctx} | ${key}`, entry, data._context?.[ctx]?.[key]);
    }
    return problems;
}

function check(shell = SHELL) {
    const lib = loadLib(shell);
    const found = extract(shell);
    const problems = [...found.errors];
    const dir = i18nDir(shell);
    for (const code of languageCodes(shell)) {
        const file = path.join(dir, code + ".json");
        let text;
        let data;
        try {
            text = fs.readFileSync(file, "utf8");
            data = JSON.parse(text);
        } catch (e) {
            problems.push(`${code}.json: ${e.message}`);
            continue;
        }
        if (serialize(rebuild(code, data, found, lib)) !== text)
            problems.push(`${code}.json is out of date with the code (new, gone or reordered strings): node tools/i18n.js extract`);
        problems.push(...checkLanguage(code, data, found, lib));
    }
    for (const code of COMPLETE) {
        if (!languageCodes(shell).includes(code))
            problems.push(`${code}.json is missing`);
    }
    const index = path.join(dir, "languages.json");
    if (!fs.existsSync(index) || fs.readFileSync(index, "utf8") !== serialize(languagesIndex(shell)))
        problems.push("languages.json is out of date: node tools/i18n.js extract");
    return {
        problems,
        found
    };
}

function stats(shell = SHELL) {
    const found = extract(shell);
    const total = found.strings.size + [...found.contexts.values()].reduce((n, t) => n + t.size, 0);
    return languageCodes(shell).map(code => {
        const data = readJson(path.join(i18nDir(shell), code + ".json"));
        let done = 0;
        const count = v => {
            if (Array.isArray(v) ? v.some(x => x !== "") : typeof v === "string" && v !== "")
                done++;
        };
        for (const key of found.strings.keys())
            count(data[key]);
        for (const [ctx, table] of found.contexts) {
            for (const key of table.keys())
                count(data._context?.[ctx]?.[key]);
        }
        return {
            code,
            name: data._meta?.name ?? code,
            done,
            total
        };
    });
}

// =============================================================================
// Bare strings: UI text not yet going through I18n
// =============================================================================

// Properties whose value is shown to the user
const UI_PROPS = "text|label|title|description|placeholder|placeholderText|tooltip|toolTip|tooltipText|tip|badge|subtitle|hint|message|summary|body|detail|emptyText|heading|caption";
const UI_LINE = new RegExp(`^\\s*(?:(?:[\\w.]+\\.)?(?:${UI_PROPS})\\s*:|return\\b)`);

// Looks like words for people: letters, and a space or a capital first
function prose(value) {
    return /[A-Za-z]{2,}/.test(value) && (/\s/.test(value.trim()) || /^[A-Z][a-z]/.test(value) || /…$/.test(value));
}

// Bare strings per file: lines with a UI property (or a return) holding a
// literal that reads like prose outside any I18n call (or any other call:
// paths, env names, state keys). `// i18n-ignore` on the line skips it
function bareStrings(shell = SHELL) {
    const counts = {};
    for (const file of sourceFiles(shell)) {
        if (!file.endsWith(".qml"))
            continue;
        const rel = path.relative(shell, file);
        const text = fs.readFileSync(file, "utf8");
        const lines = text.split("\n");
        const starts = [];
        let pos = 0;
        for (const l of lines) {
            starts.push(pos);
            pos += l.length + 1;
        }
        const lineOf = i => {
            let lo = 0;
            let hi = starts.length - 1;
            while (lo < hi) {
                const mid = (lo + hi + 1) >> 1;
                if (starts[mid] <= i)
                    lo = mid;
                else
                    hi = mid - 1;
            }
            return lo;
        };
        const hits = new Set();
        for (const lit of scan(text, false).literals) {
            if (lit.template || (lit.callee !== "" && lit.callee !== "arg"))
                continue;
            if (!prose(lit.value))
                continue;
            const n = lineOf(lit.start);
            const line = lines[n];
            if (!UI_LINE.test(line) || line.includes("i18n-ignore"))
                continue;
            hits.add(n);
        }
        if (hits.size > 0)
            counts[rel] = hits.size;
    }
    return counts;
}

function readBaseline(file = BASELINE) {
    const out = {};
    if (!fs.existsSync(file))
        return out;
    for (const line of fs.readFileSync(file, "utf8").split("\n")) {
        const m = line.match(/^(\d+)\s+(.+)$/);
        if (m)
            out[m[2]] = Number(m[1]);
    }
    return out;
}

function writeBaseline(counts, file = BASELINE) {
    const files = Object.keys(counts).sort();
    const total = files.reduce((n, f) => n + counts[f], 0);
    const body = files.map(f => `${counts[f]} ${f}`).join("\n");
    fs.writeFileSync(file, `# UI strings not yet going through I18n, per file (${total} lines): node tools/i18n.js lint --update\n${body}\n`);
}

// Files whose count grew (or are new), and the ones that shrank
function compareBaseline(counts, baseline) {
    const grew = [];
    const shrank = [];
    for (const [f, n] of Object.entries(counts)) {
        if (n > (baseline[f] ?? 0))
            grew.push(`${f}: ${n} (baseline ${baseline[f] ?? 0})`);
    }
    for (const [f, n] of Object.entries(baseline)) {
        if ((counts[f] ?? 0) < n)
            shrank.push(`${f}: ${counts[f] ?? 0} (baseline ${n})`);
    }
    return {
        grew,
        shrank
    };
}

// =============================================================================

function main(argv) {
    const [cmd, ...rest] = argv;
    const lib = () => loadLib(SHELL);
    switch (cmd) {
    case "extract": {
        const found = extract();
        found.errors.forEach(e => console.error(e));
        // Never empty the files because the code wasn't found
        if (found.strings.size + found.contexts.size === 0) {
            console.error(`no I18n calls found in ${SHELL}: nothing written`);
            return 1;
        }
        const changed = writeAll(SHELL, found, lib());
        const n = found.strings.size + [...found.contexts.values()].reduce((s, t) => s + t.size, 0);
        console.log(`${n} strings; ${changed.length ? "updated " + changed.join(", ") : "files already up to date"}`);
        return found.errors.length ? 1 : 0;
    }
    case "check": {
        const {
            problems
        } = check();
        problems.forEach(p => console.error(p));
        if (problems.length === 0)
            console.log("translations: ok");
        return problems.length ? 1 : 0;
    }
    case "add": {
        const [code, name] = rest;
        if (!/^[a-z]{2,3}(_[A-Z]{2})?$/.test(code ?? "") || !name) {
            console.error('usage: node tools/i18n.js add <code like pt_BR> "<its own name>"');
            return 2;
        }
        const file = path.join(i18nDir(SHELL), code + ".json");
        if (fs.existsSync(file)) {
            console.error(`${code}.json already exists`);
            return 1;
        }
        fs.mkdirSync(i18nDir(SHELL), {
            recursive: true
        });
        fs.writeFileSync(file, serialize({
            _meta: {
                name
            }
        }));
        writeAll(SHELL, extract(), lib());
        console.log(`created i18n/${code}.json: translate its "" values`);
        return 0;
    }
    case "stats":
        for (const s of stats())
            console.log(`${s.code.padEnd(6)} ${String(Math.round(s.done * 100 / Math.max(1, s.total))).padStart(3)}%  ${s.done}/${s.total}  ${s.name}`);
        return 0;
    case "lint": {
        const counts = bareStrings();
        const total = Object.values(counts).reduce((a, b) => a + b, 0);
        if (rest[0] === "--update") {
            writeBaseline(counts);
            console.log(`baseline: ${total} lines in ${Object.keys(counts).length} files`);
            return 0;
        }
        const {
            grew,
            shrank
        } = compareBaseline(counts, readBaseline());
        console.log(`bare strings: ${total} lines in ${Object.keys(counts).length} files`);
        if (shrank.length)
            console.log(`${shrank.length} file(s) have fewer: node tools/i18n.js lint --update shrinks the baseline`);
        if (grew.length) {
            console.error("new bare strings (wrap them in I18n.tr, or // i18n-ignore when it isn't UI text):");
            grew.forEach(g => console.error("  " + g));
            return 1;
        }
        return 0;
    }
    default:
        console.error("usage: node tools/i18n.js extract|check|add|stats|lint [--update]");
        return 2;
    }
}

if (require.main === module)
    process.exit(main(process.argv.slice(2)));

module.exports = {
    scan,
    extract,
    check,
    checkLanguage,
    rebuild,
    serialize,
    stats,
    bareStrings,
    compareBaseline,
    readBaseline,
    loadLib,
    COMPLETE
};
