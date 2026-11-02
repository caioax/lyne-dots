.pragma library

// Steps that turn the list `from` into `to` (strings, each one once) with
// the fewest changes, for a ListModel that should keep the items both lists
// share (a Repeater over a plain array recreates every delegate on each
// change). Each step is one of
//   { op: "remove", index }
//   { op: "insert", index, value }
//   { op: "move", from, to }
// applied in order, on the list as the steps before left it.
function diff(from, to) {
    const steps = [];
    const keep = new Set(to);
    const cur = from.slice();
    for (let i = cur.length - 1; i >= 0; i--) {
        if (!keep.has(cur[i])) {
            steps.push({ op: "remove", index: i });
            cur.splice(i, 1);
        }
    }
    for (let j = 0; j < to.length; j++) {
        if (cur[j] === to[j])
            continue;
        const at = cur.indexOf(to[j], j + 1);
        if (at >= 0) {
            steps.push({ op: "move", from: at, to: j });
            cur.splice(at, 1);
            cur.splice(j, 0, to[j]);
        } else {
            steps.push({ op: "insert", index: j, value: to[j] });
            cur.splice(j, 0, to[j]);
        }
    }
    return steps;
}

// Applies diff(from, to) to a ListModel whose rows hold the value in `role`
function apply(model, role, to) {
    const from = [];
    for (let i = 0; i < model.count; i++)
        from.push(model.get(i)[role]);
    for (const s of diff(from, to)) {
        if (s.op === "remove") {
            model.remove(s.index, 1);
        } else if (s.op === "move") {
            model.move(s.from, s.to, 1);
        } else {
            const row = {};
            row[role] = s.value;
            model.insert(s.index, row);
        }
    }
}
