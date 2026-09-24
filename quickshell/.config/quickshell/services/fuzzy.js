.pragma library

// Fuzzy matching for search boxes. Targets are prepared once with prepare();
// queries are normalized with normalize().text and scored with score().
// Scores are tiers: exact > prefix > word start > substring > acronym >
// scattered letters (the last two only when `fuzzy` is set)

const separators = /[\s\-_.\/()]/;

// Lowercase, accent-free copy of `text`, plus the index in `text` each of its
// chars came from (so matches can be highlighted in the original)
function normalize(text) {
    let out = "";
    const map = [];
    for (let i = 0; i < text.length; i++) {
        const chars = text[i].normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
        for (let k = 0; k < chars.length; k++) {
            out += chars[k];
            map.push(i);
        }
    }
    return {
        text: out,
        map: map
    };
}

// Word starts: the first char, a char after a separator, or an uppercase
// letter after a lowercase one ("LibreOffice")
function _isWordStart(original, i) {
    if (i === 0)
        return true;
    const prev = original[i - 1];
    const cur = original[i];
    if (separators.test(prev))
        return true;
    return prev === prev.toLowerCase() && prev !== prev.toUpperCase() && cur !== cur.toLowerCase();
}

function prepare(text) {
    const target = normalize(text || "");
    target.starts = [];
    for (let j = 0; j < target.text.length; j++) {
        const i = target.map[j];
        target.starts.push((j === 0 || target.map[j - 1] !== i) && _isWordStart(text, i));
    }
    return target;
}

function _result(score, target, positions) {
    const original = [];
    for (const p of positions) {
        const i = target.map[p];
        if (original[original.length - 1] !== i)
            original.push(i);
    }
    return {
        score: score,
        positions: original
    };
}

function _range(start, length) {
    const list = [];
    for (let i = 0; i < length; i++)
        list.push(start + i);
    return list;
}

// Letters of `q` in order anywhere in the target. Consecutive letters and
// word starts earn points, gaps cost; too scattered a match is rejected.
// Each occurrence of the first letter is tried as the start, since the
// first one found isn't always the best ("ntwrk": advaNced NeTWoRK)
function _scattered(q, target) {
    const s = target.text;
    let best = null;
    for (let start = s.indexOf(q[0]); start !== -1; start = s.indexOf(q[0], start + 1)) {
        const positions = [start];
        let bonus = (target.starts[start] ? 20 : 0) - Math.min(start, 10);
        let from = start + 1;
        for (let k = 1; k < q.length && positions.length === k; k++) {
            const pos = s.indexOf(q[k], from);
            if (pos === -1)
                break;
            const prev = positions[k - 1];
            bonus += pos === prev + 1 ? 15 : -Math.min(pos - prev - 1, 8);
            if (target.starts[pos])
                bonus += 20;
            positions.push(pos);
            from = pos + 1;
        }
        if (positions.length === q.length && (!best || bonus > best.bonus))
            best = {
                bonus: bonus,
                positions: positions
            };
    }
    if (!best || best.bonus < q.length * 5)
        return null;
    return _result(100 + Math.min(best.bonus, 150), target, best.positions);
}

// Score of a normalized query against a prepared target, or null
function score(q, target, fuzzy) {
    const s = target.text;
    if (q === "" || s === "")
        return null;
    if (s === q)
        return _result(1000, target, _range(0, q.length));
    if (s.startsWith(q))
        return _result(900 - Math.min(s.length - q.length, 50), target, _range(0, q.length));

    const first = s.indexOf(q);
    for (let i = first; i !== -1; i = s.indexOf(q, i + 1)) {
        if (target.starts[i])
            return _result(700 - Math.min(i, 50), target, _range(i, q.length));
    }
    if (first !== -1)
        return _result(500 - Math.min(first, 50), target, _range(first, q.length));

    if (!fuzzy)
        return null;

    // Acronym: every letter at the start of a word ("vsc", "gimp")
    const positions = [];
    for (let i = 0; i < s.length && positions.length < q.length; i++) {
        if (target.starts[i] && s[i] === q[positions.length])
            positions.push(i);
    }
    if (positions.length === q.length && q.length > 1)
        return _result(600, target, positions);

    return _scattered(q, target);
}
