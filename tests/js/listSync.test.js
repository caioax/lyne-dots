const test = require("node:test");
const assert = require("node:assert/strict");
const { load } = require("./load");

const L = load("services/listSync.js");

// A stand-in for QML's ListModel, enough for apply()
function model(values) {
    const rows = values.map(v => ({ path: v }));
    const log = [];
    return {
        rows,
        log,
        get count() {
            return rows.length;
        },
        get: i => rows[i],
        remove: (i, n) => {
            log.push("remove");
            rows.splice(i, n);
        },
        insert: (i, row) => {
            log.push("insert");
            rows.splice(i, 0, row);
        },
        move: (from, to, n) => {
            log.push("move");
            rows.splice(to, 0, ...rows.splice(from, n));
        }
    };
}

function run(from, to) {
    const m = model(from);
    const kept = new Map(m.rows.map(r => [r.path, r]));
    L.apply(m, "path", to);
    assert.deepEqual(m.rows.map(r => r.path), to);
    return { m, kept };
}

test("same list: no steps", () => {
    assert.deepEqual(L.diff(["a", "b"], ["a", "b"]), []);
});

test("deleting one keeps the others' rows", () => {
    const { m, kept } = run(["a", "b", "c", "d"], ["a", "c", "d"]);
    assert.deepEqual(m.log, ["remove"]);
    for (const r of m.rows)
        assert.equal(r, kept.get(r.path));
});

test("adding inserts at the sorted place", () => {
    const { m } = run(["a", "c"], ["a", "b", "c", "d"]);
    assert.deepEqual(m.log, ["insert", "insert"]);
});

test("a filter that hides and shows rows", () => {
    run(["a", "b", "c", "d", "e"], ["b", "d"]);
    run(["b", "d"], ["a", "b", "c", "d", "e"]);
});

test("reordered rows move instead of being recreated", () => {
    const { m } = run(["a", "b", "c"], ["c", "a", "b"]);
    assert.deepEqual(m.log, ["move"]);
});

test("empty lists", () => {
    run([], ["a"]);
    run(["a"], []);
    run([], []);
});
