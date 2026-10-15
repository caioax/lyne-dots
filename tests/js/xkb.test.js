const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const { load, fixture } = require("./load");

const X = load("services/xkb.js");

// Lines copied from xkeyboard-config's rules/evdev.lst
const db = X.parseLst(fixture("evdev-excerpt.lst"));

test("parseLst: models, layouts, variants by layout, option groups", () => {
    assert.deepEqual(db.models.map(m => m.name), ["pc104", "pc105"]);
    assert.deepEqual(db.layouts.map(l => l.name), ["gb", "us", "de", "br", "ba"]);
    assert.deepEqual(db.variants.us.map(v => v.name), ["intl", "alt-intl"]);
    // A variant named like a layout ("us" of Bosnian) belongs to its layout
    assert.deepEqual(db.variants.ba, [{ name: "us", description: "Bosnian (US)" }]);
    const grp = db.groups.find(g => g.name === "grp");
    assert.equal(grp.description, "Switching to another layout");
    assert.deepEqual(grp.options.map(o => o.name), ["grp:alt_shift_toggle", "grp:win_space_toggle"]);
    // An option whose group has no header line gets a group named after it
    assert.equal(db.groups.find(g => g.name === "compose").description, "compose");
});

test("parseLst: a group header after its options keeps them", () => {
    const d = X.parseLst("! option\n  caps:escape   Esc\n  caps          Caps Lock behavior\n");
    assert.equal(d.groups.length, 1);
    assert.equal(d.groups[0].description, "Caps Lock behavior");
    assert.equal(d.groups[0].options.length, 1);
});

test("parseLst reads the real evdev.lst when it's there", { skip: !fs.existsSync("/usr/share/X11/xkb/rules/evdev.lst") }, () => {
    const real = X.parseLst(fs.readFileSync("/usr/share/X11/xkb/rules/evdev.lst", "utf8"));
    assert.ok(real.layouts.length > 50);
    assert.ok(X.findVariant(real, "us", "alt-intl"));
    assert.ok(X.findOption(real, "grp:alt_shift_toggle"));
});

test("parseLayouts / joinLayouts round trip", () => {
    const list = X.parseLayouts("us, br,", "alt-intl,");
    assert.deepEqual(list, [{ layout: "us", variant: "alt-intl" }, { layout: "br", variant: "" }]);
    assert.deepEqual(X.joinLayouts(list), { layout: "us,br", variant: "alt-intl," });
    assert.deepEqual(X.joinLayouts([{ layout: "us", variant: "" }, { layout: "br" }]), { layout: "us,br", variant: "" });
});

test("acceptable: listed entries, or ones already saved (abnt2 isn't listed)", () => {
    assert.equal(X.isValid(db, { layout: "br", variant: "abnt2" }), false);
    assert.equal(X.acceptable(db, [{ layout: "br", variant: "abnt2" }], []), false);
    assert.equal(X.acceptable(db, [{ layout: "br", variant: "abnt2" }], [{ layout: "br", variant: "abnt2" }]), true);
    assert.equal(X.acceptable(db, [{ layout: "us", variant: "intl" }, { layout: "de", variant: "" }], []), true);
    assert.equal(X.acceptable(db, [{ layout: "xx", variant: "" }], []), false);
});

test("systemLayouts from localectl: X11 first, else the console keymap", () => {
    const x11 = "System Locale: LANG=en_US.UTF-8\n    VC Keymap: us\n   X11 Layout: us,br\n  X11 Variant: alt-intl,abnt2\n";
    // abnt2 isn't listed: falls back to the plain layout
    assert.deepEqual(X.systemLayouts(db, x11), [{ layout: "us", variant: "alt-intl" }, { layout: "br", variant: "" }]);
    const vc = "    VC Keymap: br-thinkpad\n   X11 Layout: n/a\n";
    assert.deepEqual(X.systemLayouts(db, vc), [{ layout: "br", variant: "thinkpad" }]);
    assert.deepEqual(X.systemLayouts(db, "    VC Keymap: uk\n"), [{ layout: "gb", variant: "" }]);
    assert.deepEqual(X.systemLayouts(db, "   X11 Layout: us,br,de,gb,ba\n"), X.parseLayouts("us,br,de,gb", ""));
});

test("describe: listed names, unlisted variants spelled into the layout's", () => {
    assert.equal(X.describe(db, { layout: "us", variant: "alt-intl" }), "English (US, alt. intl.)");
    assert.equal(X.describe(db, { layout: "br", variant: "abnt2" }), "Portuguese (Brazil, abnt2)");
    assert.equal(X.describe(db, { layout: "de", variant: "neo" }), "German (neo)");
    assert.equal(X.describe(db, { layout: "xx", variant: "y" }), "xx (y)");
    assert.equal(X.describe(db, { layout: "xx", variant: "" }), "xx");
    assert.equal(X.shortName({ layout: "brazil" }), "BRA");
});

test("allEntries + matches: every word must be found", () => {
    const all = X.allEntries(db);
    assert.equal(all.length, db.layouts.length + 8);
    assert.deepEqual(all.filter(e => X.matches(e, "brazil think")).map(e => e.variant), ["thinkpad"]);
    assert.equal(all.filter(e => X.matches(e, "")).length, all.length);
});

test("options: single-choice groups replace, others add", () => {
    let opts = X.parseOptions("grp:alt_shift_toggle, terminate:ctrl_alt_bksp");
    opts = X.toggleOption(opts, "grp:win_space_toggle", true);
    assert.deepEqual(opts, ["terminate:ctrl_alt_bksp", "grp:win_space_toggle"]);
    opts = X.toggleOption(opts, "terminate:ctrl_alt_bksp", false);
    assert.deepEqual(opts, ["grp:win_space_toggle"]);
    assert.equal(X.optionIn(opts, "grp"), "grp:win_space_toggle");
    assert.deepEqual(X.setGroupOption(opts, "grp", ""), []);
    assert.deepEqual(X.validOptions(db, ["caps:escape", "caps:nonsense", "foo"]), ["caps:escape"]);
});

test("keyboardGroups: interfaces folded, non-typing devices marked", () => {
    const k = (name, extra) => ({ name, layout: "us", variant: "alt-intl", active_keymap: "English (US, alt. intl.)", main: false, ...extra });
    const groups = X.keyboardGroups([
        k("-------akko-keyboard-1"),
        k("-------akko-keyboard", { main: true, layout: "br", variant: "" }),
        k("power-button"),
        k("power-button-1"),
        k("at-translated-set-2-keyboard"),
        k("qcy-melobuds-pro-(avrcp)")
    ]);
    assert.deepEqual(groups.map(g => g.name), ["-------akko-keyboard", "power-button", "at-translated-set-2-keyboard", "qcy-melobuds-pro-(avrcp)"]);
    const akko = groups[0];
    assert.equal(akko.label, "Akko keyboard");
    assert.equal(akko.main, true);
    assert.equal(akko.layout, "br");
    assert.deepEqual(akko.names, ["-------akko-keyboard-1", "-------akko-keyboard"]);
    assert.deepEqual(groups.map(g => g.typing), [true, false, true, false]);
    assert.equal(groups[2].label, "Built-in keyboard");
});
