.pragma library

// Pure helpers of the I18n singleton (services/I18n.qml), shared with
// tools/i18n.js and tested in node (tests/js/i18n.test.js)

// Plural rules per language (CLDR, integers): how many forms a translation
// of a trn() string has, and which one a count takes. Languages missing
// here use English's
const PLURALS = {
    en: {
        forms: 2,
        index: n => n === 1 ? 0 : 1
    },
    // Only 1 takes the singular: "0 dispositivos" reads better in Brazilian
    // Portuguese than CLDR's "0 dispositivo" (its rule is i = 0..1)
    pt: {
        forms: 2,
        index: n => n === 1 ? 0 : 1
    },
    fr: {
        forms: 2,
        index: n => Math.floor(Math.abs(n)) <= 1 ? 0 : 1
    },
    ru: {
        forms: 3,
        index: n => slavic(n)
    },
    uk: {
        forms: 3,
        index: n => slavic(n)
    },
    pl: {
        forms: 3,
        index: n => n === 1 ? 0 : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14) ? 1 : 2
    },
    cs: {
        forms: 3,
        index: n => n === 1 ? 0 : n >= 2 && n <= 4 ? 1 : 2
    },
    ja: {
        forms: 1,
        index: () => 0
    },
    ko: {
        forms: 1,
        index: () => 0
    },
    zh: {
        forms: 1,
        index: () => 0
    }
};

function slavic(n) {
    if (n % 10 === 1 && n % 100 !== 11)
        return 0;
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14))
        return 1;
    return 2;
}

// "pt_BR.UTF-8", "pt-BR", "pt_BR@euro" -> "pt_BR"; "" for C/POSIX
function normalize(code) {
    const c = String(code ?? "").split(/[.@]/)[0].replace("-", "_");
    if (c === "" || c === "C" || c === "POSIX")
        return "";
    const parts = c.split("_");
    return parts.length > 1 ? parts[0].toLowerCase() + "_" + parts[1].toUpperCase() : parts[0].toLowerCase();
}

// "pt_BR" -> "pt"
function languageOf(code) {
    return normalize(code).split("_")[0];
}

function pluralRule(code) {
    return PLURALS[languageOf(code)] ?? PLURALS.en;
}

function pluralForms(code) {
    return pluralRule(code).forms;
}

function pluralIndex(code, n) {
    return Math.min(pluralRule(code).index(Math.abs(Number(n))), pluralRule(code).forms - 1);
}

// The language to show among `available` (codes, "en" included) for the
// wanted ones in order (a setting, or LANGUAGE/LC_ALL/LC_MESSAGES/LANG;
// LANGUAGE may be a "pt_BR:pt:en" list): the exact code first, then the
// same language in another region, English when nothing matches
function resolve(wanted, available) {
    const list = [].concat(wanted).reduce((all, w) => all.concat(String(w ?? "").split(":")), []).map(normalize).filter(w => w !== "");
    for (const w of list) {
        const exact = available.find(a => normalize(a) === w);
        if (exact)
            return exact;
        const same = available.find(a => languageOf(a) === languageOf(w));
        if (same)
            return same;
    }
    return "en";
}

// %1..%9 replaced by args (missing ones stay as they are)
function format(text, args) {
    return String(text).replace(/%([1-9])/g, (m, i) => args && args[i - 1] !== undefined ? String(args[i - 1]) : m);
}

// Placeholders of a string, sorted: ["%1", "%n"]
function placeholders(text) {
    const found = String(text).match(/%[1-9n]/g) ?? [];
    return found.filter((p, i) => found.indexOf(p) === i).sort();
}

// A translation from a language file: plain keys, "_context": { ctx: {...} }.
// Untranslated ("" or missing) = null, the caller shows the English
function lookup(strings, text, context) {
    const table = context ? strings?._context?.[context] : strings;
    const value = table ? table[text] : undefined;
    if (value === undefined || value === "" || (Array.isArray(value) && value.every(v => v === "")))
        return null;
    return value;
}

// Development pseudo-language: accented letters, ~40% longer and bracketed,
// so untranslated strings, clipped labels and concatenations stand out.
// Placeholders and rich text tags stay as they are
const PSEUDO_MAP = {
    a: "á",
    b: "ƀ",
    c: "ç",
    d: "ð",
    e: "é",
    f: "ƒ",
    g: "ĝ",
    h: "ĥ",
    i: "í",
    j: "ĵ",
    k: "ķ",
    l: "ĺ",
    m: "ɱ",
    n: "ñ",
    o: "ö",
    p: "þ",
    q: "ʠ",
    r: "ŕ",
    s: "š",
    t: "ţ",
    u: "ü",
    v: "ṽ",
    w: "ŵ",
    x: "ẋ",
    y: "ý",
    z: "ž",
    A: "Á",
    B: "Ɓ",
    C: "Ç",
    D: "Ð",
    E: "É",
    F: "Ƒ",
    G: "Ĝ",
    H: "Ĥ",
    I: "Í",
    J: "Ĵ",
    K: "Ķ",
    L: "Ĺ",
    M: "Ṁ",
    N: "Ñ",
    O: "Ö",
    P: "Þ",
    Q: "Ǫ",
    R: "Ŕ",
    S: "Š",
    T: "Ţ",
    U: "Ü",
    V: "Ṽ",
    W: "Ŵ",
    X: "Ẋ",
    Y: "Ý",
    Z: "Ž"
};

function pseudo(text) {
    const s = String(text);
    if (s.trim() === "")
        return s;
    const body = s.split(/(%[1-9n]|<[^>]*>|&\w+;)/).map((part, i) => i % 2 === 1 ? part : part.replace(/[A-Za-z]/g, ch => PSEUDO_MAP[ch])).join("");
    const letters = s.replace(/%[1-9n]|<[^>]*>/g, "").length;
    return "[" + body + " " + "~".repeat(Math.max(1, Math.round(letters * 0.4))) + "]";
}
