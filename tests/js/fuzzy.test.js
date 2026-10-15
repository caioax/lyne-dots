const test = require("node:test");
const assert = require("node:assert/strict");
const { load } = require("./load");

const F = load("services/fuzzy.js");

const score = (query, text, fuzzy = true) => F.score(F.normalize(query).text, F.prepare(text), fuzzy);
const rank = (query, texts) => texts.map(t => ({ t, s: score(query, t) })).filter(r => r.s).sort((a, b) => b.s.score - a.s.score).map(r => r.t);

test("normalize drops accents and case and maps back to the original", () => {
    const n = F.normalize("Ação");
    assert.equal(n.text, "acao");
    assert.deepEqual(n.map, [0, 1, 2, 3]);
});

test("word starts: separators and camel case", () => {
    const t = F.prepare("LibreOffice Calc");
    const starts = [...t.text].map((_, i) => t.starts[i] ? i : -1).filter(i => i >= 0);
    assert.deepEqual(starts, [0, 5, 12]);
});

test("tiers: exact > prefix > word start > substring", () => {
    assert.equal(score("firefox", "Firefox").score, 1000);
    assert.ok(score("fire", "Firefox").score >= 850);
    const word = score("off", "LibreOffice").score;
    assert.ok(word < 850 && word >= 650);
    const sub = score("ref", "Firefox").score;
    assert.ok(sub < 650 && sub >= 450);
});

test("acronyms and scattered letters only when fuzzy", () => {
    assert.equal(score("vsc", "Visual Studio Code").score, 600);
    assert.equal(score("vsc", "Visual Studio Code", false), null);
    assert.ok(score("ntwrk", "Advanced Network Configuration"));
    assert.equal(score("ntwrk", "Advanced Network Configuration", false), null);
});

test("too scattered a match is rejected", () => {
    assert.equal(score("aeiou", "Abcdefghijklmnopqrstu"), null);
});

test("positions point at the original text, accents included", () => {
    assert.deepEqual(score("cao", "Configuração").positions, [9, 10, 11]);
});

test("empty query or target never matches", () => {
    assert.equal(score("", "Firefox"), null);
    assert.equal(score("x", ""), null);
});

test("ranking: what people expect first", () => {
    assert.deepEqual(rank("term", ["Thermal", "Kitty Terminal", "Terminal", "Determine"]), ["Terminal", "Kitty Terminal", "Determine", "Thermal"]);
});
