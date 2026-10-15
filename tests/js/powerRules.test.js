const test = require("node:test");
const assert = require("node:assert/strict");
const { load } = require("./load");

const R = load("services/powerRules.js");

const rules = { lowBattery: true, level: 20, onUnplug: false };
const none = { reason: "", previous: "" };
const power = (onBattery, percentage) => ({ onBattery, percentage });

test("crossing below the level on battery switches to power saver", () => {
    const r = R.powerChanged(rules, power(true, 20), power(true, 19), "balanced", false, none);
    assert.equal(r.switchTo, "power-saver");
    assert.deepEqual(r.auto, { reason: "lowBattery", previous: "balanced" });
});

test("staying below the level doesn't switch again (a hand pick stays)", () => {
    const r = R.powerChanged(rules, power(true, 18), power(true, 17), "balanced", false, none);
    assert.equal(r.switchTo, "");
});

test("unplugging already below the level switches", () => {
    const r = R.powerChanged(rules, power(false, 15), power(true, 15), "performance", false, none);
    assert.equal(r.switchTo, "power-saver");
    assert.equal(r.auto.reason, "lowBattery");
    assert.equal(r.auto.previous, "performance");
});

test("unplugging above the level does nothing unless onUnplug", () => {
    assert.equal(R.powerChanged(rules, power(false, 80), power(true, 80), "balanced", false, none).switchTo, "");
    const r = R.powerChanged({ ...rules, onUnplug: true }, power(false, 80), power(true, 80), "balanced", false, none);
    assert.equal(r.switchTo, "power-saver");
    assert.deepEqual(r.auto, { reason: "unplugged", previous: "balanced" });
});

test("lowBattery off ignores the level", () => {
    const r = R.powerChanged({ ...rules, lowBattery: false }, power(true, 20), power(true, 5), "balanced", false, none);
    assert.equal(r.switchTo, "");
});

test("no rule acts while an app holds a profile", () => {
    const r = R.powerChanged(rules, power(true, 20), power(true, 19), "performance", true, none);
    assert.equal(r.switchTo, "");
});

test("already on power saver: nothing to do, auto kept", () => {
    const auto = { reason: "lowBattery", previous: "balanced" };
    const r = R.powerChanged(rules, power(true, 20), power(true, 19), "power-saver", false, auto);
    assert.equal(r.switchTo, "");
    assert.deepEqual(r.auto, auto);
});

test("plugging in goes back to the profile from before", () => {
    const auto = { reason: "lowBattery", previous: "performance" };
    const r = R.powerChanged(rules, power(true, 15), power(false, 15), "power-saver", false, auto);
    assert.equal(r.switchTo, "performance");
    assert.deepEqual(r.auto, none);
});

test("plugging in after a hand pick leaves the profile alone", () => {
    const auto = { reason: "lowBattery", previous: "performance" };
    assert.equal(R.powerChanged(rules, power(true, 15), power(false, 15), "balanced", false, auto).switchTo, "");
    // Power saver picked by hand (no rule switched): stays too
    assert.equal(R.powerChanged(rules, power(true, 15), power(false, 15), "power-saver", false, none).switchTo, "");
});

test("a profile picked by hand ends the rule; power saver keeps it", () => {
    const auto = { reason: "unplugged", previous: "balanced" };
    assert.deepEqual(R.profileChanged(auto, "performance"), none);
    assert.deepEqual(R.profileChanged(auto, "power-saver"), auto);
    assert.deepEqual(R.profileChanged(none, "balanced"), none);
});
