const test = require("node:test");
const assert = require("node:assert/strict");
const { load, fixture } = require("./load");

const I = load("services/input.js");

test("touchpadNames: only the touchpad interface, not the chip's or a keyboard's -mouse", () => {
    assert.deepEqual(I.touchpadNames(fixture("hyprctl-devices.json")), ["syna7db5:01-06cb:cd41-touchpad"]);
    assert.deepEqual(I.touchpadNames(JSON.parse(fixture("hyprctl-devices.json"))), ["syna7db5:01-06cb:cd41-touchpad"]);
});

test("touchpadNames: no touchpad, no mice, bad output", () => {
    assert.deepEqual(I.touchpadNames('{"mice":[{"name":"wl_pointer"}],"keyboards":[]}'), []);
    assert.deepEqual(I.touchpadNames("{}"), []);
    assert.deepEqual(I.touchpadNames("not json"), []);
    assert.deepEqual(I.touchpadNames(null), []);
});

test("mergeNames: saved first, then new ones, no repeats or blanks", () => {
    assert.deepEqual(I.mergeNames(["a-touchpad"], ["b-touchpad", "a-touchpad"]), ["a-touchpad", "b-touchpad"]);
    assert.deepEqual(I.mergeNames(undefined, ["a-touchpad", ""]), ["a-touchpad"]);
    assert.deepEqual(I.mergeNames(["a-touchpad"], []), ["a-touchpad"]);
});
