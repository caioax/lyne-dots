const test = require("node:test");
const assert = require("node:assert/strict");
const { load } = require("./load");

const R = load("services/videoRules.js");

const defaults = { covered: true, locked: true, battery: false };
const now = (extra) => Object.assign({ screens: ["eDP-1", "HDMI-A-1"], coveredScreens: [], locked: false, onBattery: false }, extra);

test("nothing covering it: plays", () => {
    assert.equal(R.shouldPause(defaults, now()), false);
});

test("one screen covered of two: keeps playing on the free one", () => {
    assert.equal(R.shouldPause(defaults, now({ coveredScreens: ["HDMI-A-1"] })), false);
});

test("every screen covered: pauses, unless that rule is off", () => {
    const all = now({ coveredScreens: ["HDMI-A-1", "eDP-1"] });
    assert.equal(R.shouldPause(defaults, all), true);
    assert.equal(R.shouldPause({ ...defaults, covered: false }, all), false);
});

test("a single screen covered: pauses", () => {
    assert.equal(R.shouldPause(defaults, now({ screens: ["eDP-1"], coveredScreens: ["eDP-1"] })), true);
});

test("no screens known yet: plays", () => {
    assert.equal(R.shouldPause(defaults, now({ screens: [], coveredScreens: [] })), false);
});

test("locked: pauses, unless that rule is off", () => {
    assert.equal(R.shouldPause(defaults, now({ locked: true })), true);
    assert.equal(R.shouldPause({ ...defaults, locked: false }, now({ locked: true })), false);
});

test("on battery: plays by default, pauses with that rule on", () => {
    assert.equal(R.shouldPause(defaults, now({ onBattery: true })), false);
    assert.equal(R.shouldPause({ ...defaults, battery: true }, now({ onBattery: true })), true);
    assert.equal(R.shouldPause({ ...defaults, battery: true }, now()), false);
});

test("pause on battery unset: on with a battery, off without one", () => {
    assert.equal(R.batteryRule(null, true), true);
    assert.equal(R.batteryRule(null, false), false);
    assert.equal(R.batteryRule(undefined, true), true);
});

test("pause on battery chosen: the choice, battery or not", () => {
    assert.equal(R.batteryRule(false, true), false);
    assert.equal(R.batteryRule(true, false), true);
});
