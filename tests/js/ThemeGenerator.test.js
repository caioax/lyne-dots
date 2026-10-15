const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { load } = require("./load");

const G = load("services/ThemeGenerator.js");

const THEMES = path.resolve(__dirname, "../../.data/themes");
const near = (a, b, eps, msg) => assert.ok(Math.abs(a - b) <= eps, `${msg ?? ""} ${a} ≉ ${b}`);
const hexRe = /^#[0-9a-f]{6}$/;

test("color math: known values and round trips", () => {
    near(G.hexToOklch("#ffffff").l, 1, 1e-4);
    near(G.hexToOklch("#ffffff").c, 0, 1e-4);
    near(G.hexToOklch("#000000").l, 0, 1e-4);
    // Reference OKLCH of pure red: 0.628 0.258 29.2
    const red = G.hexToOklch("#ff0000");
    near(red.l, 0.628, 1e-3);
    near(red.c, 0.258, 1e-3);
    near(red.h, 29.23, 0.05);
    for (const hex of ["#7aa2f7", "#1a1b26", "#e0af68", "#ffffff", "#000000", "#123456"]) {
        const c = G.hexToOklch(hex);
        assert.equal(G.oklch(c.l, c.c, c.h), hex);
    }
    assert.equal(G.rgbToHex([1, 0.5, -1]), "#ff8000");
});

test("oklch keeps lightness and hue when it has to drop chroma", () => {
    const hex = G.oklch(0.9, 0.4, 140);
    assert.match(hex, hexRe);
    const back = G.hexToOklch(hex);
    near(back.l, 0.9, 0.01);
    near(back.h, 140, 2);
    assert.ok(back.c < 0.4);
    assert.ok(G.maxChroma(0.9, 140) < G.maxChroma(0.7, 140));
});

test("contrast is the WCAG 2 ratio", () => {
    near(G.contrast("#ffffff", "#000000"), 21, 1e-9);
    near(G.contrast("#777777", "#ffffff"), 4.48, 0.01);
    assert.equal(G.contrast("#123456", "#123456"), 1);
});

test("mixOklab: ends are the colors, alpha mixes linearly", () => {
    const a = G.colorToOklab({ r: 1, g: 0, b: 0, a: 1 });
    const b = G.colorToOklab({ r: 0, g: 0, b: 1, a: 0 });
    G.mixOklab(a, b, 0).slice(0, 3).forEach((v, i) => near(v, [1, 0, 0][i], 1e-6));
    G.mixOklab(a, b, 1).slice(0, 3).forEach((v, i) => near(v, [0, 0, 1][i], 1e-6));
    near(G.mixOklab(a, b, 0.25)[3], 0.75, 1e-9);
});

// Accents across the wheel, greys and extremes, both schemes, both tints
const accents = ["#7aa2f7", "#f7768e", "#9ece6a", "#e0af68", "#bb9af7", "#7dcfff", "#ff9e64", "#ffffff", "#000000", "#808080", "#ffff00", "#0000ff"];

test("generate: complete themes whose default contrast checks all pass", () => {
    for (const scheme of ["dark", "light"]) {
        for (const accent of accents) {
            for (const tint of [0, 1]) {
                const theme = G.generate({ name: "T", scheme, accent, tint });
                const where = `${scheme} ${accent} tint ${tint}`;
                assert.equal(theme.variant, scheme);
                for (const [key, hex] of [...Object.entries(theme.palette), ...Object.entries(theme.terminal)])
                    assert.match(hex, hexRe, `${where} ${key}`);
                assert.match(theme.hyprland.activeBorder, /^[0-9a-f]{8}$/);
                const failing = G.checks(theme).filter(c => !c.ok).map(c => `${c.id} ${c.ratio.toFixed(2)}<${c.min}`);
                assert.deepEqual(failing, [], where);
            }
        }
    }
});

test("generate: exactAccent keeps the accent; overrides win and are kept in the seed", () => {
    const theme = G.generate({ scheme: "dark", accent: "#123456", exactAccent: true }, { palette: { error: "#ff0000" }, terminal: { color1: "#00ff00" } });
    assert.equal(theme.palette.accent, "#123456");
    assert.equal(theme.palette.error, "#ff0000");
    assert.equal(theme.terminal.color1, "#00ff00");
    assert.equal(theme.terminal.activeTabBackground, "#123456");
    assert.deepEqual(theme.seed.overrides, { palette: { error: "#ff0000" }, terminal: { color1: "#00ff00" } });
    assert.equal(theme.name, "Custom");
    // Without exactAccent a dark accent is moved into a readable range
    const moved = G.generate({ scheme: "dark", accent: "#123456" });
    assert.ok(G.contrast(moved.palette.accent, moved.palette.background) >= 4.5);
});

test("seedFromTheme: generated themes give their seed back, presets a close one", () => {
    const made = G.generate({ name: "Mine", scheme: "light", accent: "#bb9af7", tint: 0.3 });
    const seed = G.seedFromTheme(made);
    assert.equal(seed.name, "Mine");
    assert.equal(seed.accent, "#bb9af7");
    assert.equal(G.generate(seed).palette.background, made.palette.background);
    for (const file of fs.readdirSync(THEMES).filter(f => f.endsWith(".json"))) {
        const preset = JSON.parse(fs.readFileSync(path.join(THEMES, file), "utf8"));
        const s = G.seedFromTheme(preset);
        assert.equal(s.accent, preset.palette.accent, file);
        assert.equal(s.scheme, preset.variant === "light" ? "light" : "dark", file);
        assert.ok(s.tint >= 0 && s.tint <= 1, file);
        // Rebuilt from its seed: the preset's accent, on the generator's own
        // lightness levels
        assert.equal(G.generate(s).palette.accent, preset.palette.accent, file);
    }
});

test("fixFor: the Fix button makes a failing check pass", () => {
    const theme = G.generate({ scheme: "dark", accent: "#7aa2f7" }, { palette: { subtext: "#3a3b46", accent: "#1d1e2a" }, terminal: { color3: "#22232e" } });
    const failing = G.checks(theme).filter(c => !c.ok);
    assert.deepEqual(failing.map(c => c.id).sort(), ["accent", "ansi", "onAccent", "subtext"]);
    for (const check of failing) {
        const hex = G.fixFor(theme, check);
        const section = check.fixSection === "terminal" ? theme.terminal : theme.palette;
        const fixed = JSON.parse(JSON.stringify(theme));
        (check.fixSection === "terminal" ? fixed.terminal : fixed.palette)[check.fixKey] = hex;
        assert.notEqual(hex, section[check.fixKey]);
        assert.ok(G.checks(fixed).find(c => c.id === check.id).ok, `${check.id} after fix ${hex}`);
    }
});

test("slugify", () => {
    assert.equal(G.slugify("My Theme!"), "my-theme");
    assert.equal(G.slugify("  Café — Noite  "), "cafe-noite");
    assert.equal(G.slugify("***"), "");
});
