const test = require("node:test");
const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const { load, fixture } = require("./load");

const M = load("services/monitors.js");

// `hyprctl monitors all -j`, trimmed (made-up external monitor)
const monitors = JSON.parse(fixture("monitors.json"));
const [ext, laptop] = monitors;

const hasLua = (() => {
    try {
        execFileSync("lua", ["-v"], { stdio: "ignore" });
        return true;
    } catch (e) {
        return false;
    }
})();

test("parseMode / modeString / modes: deduplicated, biggest and fastest first", () => {
    assert.deepEqual(M.parseMode("1920x1080@179.96Hz"), { width: 1920, height: 1080, refresh: 179.96 });
    assert.deepEqual(M.parseMode("2560x1440"), { width: 2560, height: 1440, refresh: 0 });
    assert.equal(M.parseMode("preferred"), null);
    assert.equal(M.modeString(1920, 1080, 60), "1920x1080@60");
    assert.deepEqual(M.modes(ext).map(m => M.modeString(m.width, m.height, m.refresh)), ["2560x1440@74.97", "1920x1080@179.96", "1920x1080@143.98", "1920x1080@60"]);
    assert.equal(M.modes(laptop).length, 2);
});

test("scales: only those giving a whole logical size", () => {
    assert.equal(M.scaleValid(1920, 1080, 1.25), true);
    assert.equal(M.scaleValid(1920, 1080, 1.75), false);
    assert.deepEqual(M.scaleSteps(1920, 1080), [1, 1.25, 1.5, 2, 2.5, 3]);
    assert.deepEqual(M.scaleSteps(2560, 1440), [1, 1.25, 2, 2.5]);
    // 1920 / (200 / 120) = 1152 is whole; 1.7 isn't valid itself
    assert.equal(M.nearestScale(1920, 1080, 1.7), 1.66667);
    assert.deepEqual(M.validScales(0, 0), [1]);
});

test("logicalSize swaps on 90° / 270°", () => {
    assert.deepEqual(M.logicalSize(1920, 1080, 1.5, 0), { width: 1280, height: 720 });
    assert.deepEqual(M.logicalSize(1920, 1080, 1, 1), { width: 1080, height: 1920 });
    assert.deepEqual(M.logicalSize(1920, 1080, 1, 7), { width: 1080, height: 1920 });
});

test("labels and selectors: built-in panels, alike monitors fall back to the port", () => {
    assert.equal(M.labelFor(laptop), "Built-in display");
    assert.equal(M.labelFor(ext), "ULTRAWIDE");
    assert.equal(M.selectorFor(ext, monitors), "desc:Example Corp ULTRAWIDE 0001");
    const twin = { ...ext, name: "DP-2" };
    assert.equal(M.selectorFor(ext, [ext, twin]), "HDMI-A-1");
    assert.equal(M.selectorFor({ name: "DP-3", description: "" }, []), "DP-3");
    assert.equal(M.ignored({ name: "FALLBACK" }), true);
    assert.equal(M.ignored({ name: "HEADLESS-2" }), true);
});

test("ruleFor: by selector first, then by port", () => {
    const byDesc = { output: "desc:Example Corp ULTRAWIDE 0001" };
    const byPort = { output: "HDMI-A-1" };
    assert.equal(M.ruleFor([byPort, byDesc], ext, monitors), byDesc);
    assert.equal(M.ruleFor([byPort], ext, monitors), byPort);
    assert.equal(M.ruleFor([], ext, monitors), null);
});

test("ruleFromLive reads what the monitor shows, keeping stored-only values", () => {
    const rule = M.ruleFromLive(laptop, monitors, { output: "eDP-1", cm: "hdr", vrr: 2 });
    assert.equal(rule.output, "desc:AU Optronics 0xB39E");
    assert.equal(rule.mode, "1920x1080@144.03");
    assert.equal(rule.position, "1920x0");
    assert.equal(rule.scale, 1.25);
    assert.equal(rule.vrr, 2);
    assert.equal(rule.bitdepth, 10);
    assert.equal(rule.cm, "hdr");
    const mirror = M.ruleFromLive({ ...laptop, mirrorOf: "0" }, monitors, null);
    assert.equal(mirror.mirror, "desc:Example Corp ULTRAWIDE 0001");
    const off = M.ruleFromLive({ ...ext, disabled: true }, monitors, null);
    assert.deepEqual([off.disabled, off.mode, off.scale], [true, "preferred", "auto"]);
});

test("ruleToLua: disabled writes only that; explicit writes every field", () => {
    assert.equal(M.ruleToLua({ output: "DP-1", disabled: true, mode: "1920x1080@60" }), 'hl.monitor({ output = "DP-1", disabled = true })');
    assert.equal(M.ruleToLua({ output: "DP-1", mode: "1920x1080@60", position: "0x0", scale: 1.25 }), 'hl.monitor({ output = "DP-1", mode = "1920x1080@60", position = "0x0", scale = 1.25 })');
    const explicit = M.ruleToLua({ output: "DP-1" }, true);
    for (const key of ["disabled = false", "transform = 0", 'mirror = ""', "vrr = -1", "bitdepth = 8", 'cm = "srgb"', "sdrbrightness = 1", "sdrsaturation = 1"])
        assert.ok(explicit.includes(key), key);
    // SDR values only count with an HDR color mode
    assert.ok(!M.ruleToLua({ output: "DP-1", cm: "srgb", sdrbrightness: 1.4 }).includes("sdrbrightness"));
    assert.ok(M.ruleToLua({ output: "DP-1", cm: "hdr", sdrbrightness: 1.4 }).includes("sdrbrightness = 1.4"));
    assert.ok(M.ruleToLua({ output: 'desc:Odd "name"' }).includes('output = "desc:Odd \\"name\\""'));
});

test("fileContent is managed and importLua reads it back", () => {
    const rules = [
        { output: "desc:Example Corp ULTRAWIDE 0001", mode: "1920x1080@179.96", position: "0x0", scale: 1, transform: 0, mirror: "" },
        { output: "eDP-1", mode: "preferred", position: "1920x0", scale: 1.25, transform: 1, mirror: "", vrr: 1, bitdepth: 10 }
    ];
    const text = M.fileContent(rules);
    assert.equal(M.isManaged(text), true);
    assert.equal(M.isManaged("-- something else\n" + text), false);
    const back = M.importLua(text);
    assert.equal(back.length, 2);
    assert.deepEqual(back[0], { output: rules[0].output, name: "", disabled: false, mode: rules[0].mode, position: "0x0", scale: 1, transform: 0, mirror: "" });
    assert.deepEqual([back[1].name, back[1].scale, back[1].transform, back[1].vrr, back[1].bitdepth], ["eDP-1", 1.25, 1, 1, 10]);
});

test("fileContent runs in Lua and calls hl.monitor once per rule", { skip: !hasLua && "lua not installed" }, () => {
    const rules = [
        { output: 'desc:Odd "name"', mode: "1920x1080@60", position: "0x0", scale: 1.5 },
        { output: "eDP-1", disabled: true }
    ];
    const stub = `local calls = {}
hl = { monitor = function(t) calls[#calls + 1] = t end }
${M.fileContent(rules)}
for _, t in ipairs(calls) do print(t.output, tostring(t.disabled), tostring(t.scale)) end
print(lyne_monitors_file)`;
    const out = execFileSync("lua", ["-"], { input: stub, encoding: "utf8" }).trimEnd().split("\n");
    assert.deepEqual(out.slice(0, 3), ["\tnil\tauto", 'desc:Odd "name"\tnil\t1.5', "eDP-1\ttrue\tnil"]);
    assert.match(out[3], /^[0-9a-f]+$/);
});

test("importLua: a later call for the same output merges and moves last; catch-all skipped", () => {
    const rules = M.importLua(`hl.monitor({ output = "", mode = "preferred" })
-- hl.monitor({ output = "DP-9" })
hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", position = "2560x0" })
hl.monitor({ output = "DP-1", transform = 1, disabled = false })`);
    assert.deepEqual(rules.map(r => r.output), ["HDMI-A-1", "DP-1"]);
    assert.deepEqual([rules[1].mode, rules[1].transform, rules[1].scale], ["2560x1440@144", 1, 1]);
    assert.equal(rules[0].scale, "auto");
});

test("upgradeSelectors / mergeRules keep rules of monitors not connected", () => {
    const stored = [{ output: "HDMI-A-1", mode: "1920x1080@60" }, { output: "desc:Away 1234", mode: "preferred" }];
    const up = M.upgradeSelectors(stored, monitors);
    assert.equal(up[0].output, "desc:Example Corp ULTRAWIDE 0001");
    assert.equal(up[0].label, "ULTRAWIDE");
    assert.equal(stored[0].output, "HDMI-A-1", "input untouched");
    const connected = [{ output: "desc:Example Corp ULTRAWIDE 0001" }, { output: "desc:AU Optronics 0xB39E" }];
    const merged = M.mergeRules(stored, connected, monitors);
    // The old port rule for HDMI-A-1 goes (that port has a monitor with its own rule)
    assert.deepEqual(merged.map(r => r.output), [...connected.map(r => r.output), "desc:Away 1234"]);
});

test("layout: rects, overlap, snap, touches, normalize, resize, placeRight", () => {
    const rules = [
        { name: "HDMI-A-1", mode: "1920x1080@60", position: "0x0", scale: 1 },
        { name: "eDP-1", mode: "", position: "1920x0", scale: 1.25 },
        { name: "DP-1", disabled: true }
    ];
    const list = M.rects(rules, monitors, []);
    assert.deepEqual(list, [{ x: 0, y: 0, width: 1920, height: 1080 }, { x: 1920, y: 0, width: 1536, height: 864 }, null]);
    assert.deepEqual(M.rects(rules, monitors, ["eDP-1"])[1], null);
    assert.equal(M.overlaps(list, 1, 1900, 0), true);
    assert.equal(M.overlaps(list, 1, 1920, 0), false);
    assert.deepEqual(M.snap(list, 1, 1935, 12, 30), { x: 1920, y: 0, overlap: false });
    // Snapping would overlap: dropped where it was let go, still overlapping
    assert.deepEqual(M.snap(list, 1, 100, 100, 30), { x: 100, y: 100, overlap: true });
    assert.equal(M.touches(list, 1), true);
    assert.equal(M.touches([list[0], { x: 3000, y: 0, width: 10, height: 10 }], 1), false);
    assert.deepEqual(M.normalized([{ x: -100, y: 50, width: 1, height: 1 }, null])[0], { x: 0, y: 0, width: 1, height: 1 });
    assert.deepEqual(M.resized(list, 0, 2560, 1440)[1], { x: 2560, y: 0, width: 1536, height: 864 });
    assert.deepEqual(M.placeRight(list), { x: 3456, y: 0 });
});

test("mirroring: targets, mirrors of a rule, problems", () => {
    const rules = [
        { output: "A", name: "A", label: "Left" },
        { output: "B", name: "B", label: "Right", mirror: "A" },
        { output: "C", name: "C", label: "Off", disabled: true }
    ];
    assert.deepEqual(M.mirrorTargets(rules, 2, []), [0]);
    assert.deepEqual(M.mirroredBy(rules, 0), [1]);
    assert.equal(M.mirrorProblem(rules, []), "");
    assert.equal(M.mirrorProblem(rules, ["A"]), "Right mirrors Left, which is off");
    assert.equal(M.mirrorProblem([{ output: "B", label: "Right", mirror: "Z" }], []), "Right mirrors a monitor that isn't connected");
    assert.equal(M.mirrorProblem([{ output: "B", label: "Right", mirror: "B" }], []), "Right can't mirror itself");
    assert.equal(M.mirrorProblem([...rules.slice(0, 2), { output: "D", label: "Third", mirror: "B" }], []), "Third mirrors Right, which mirrors another one");
});
