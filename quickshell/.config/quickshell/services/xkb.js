.pragma library

// Keyboard layouts for Settings › Hyprland › Keyboard (KeyboardService).
// The names come from xkeyboard-config's rules/evdev.lst (the rules Hyprland
// uses): "! model", "! layout", "! variant" ("name  layout: description")
// and "! option" sections ("grp" group headers, then "grp:toggle" options).
// Hyprland keeps several layouts as comma lists that go together:
//   kb_layout "us,br"  kb_variant "alt-intl,abnt2"
// An unknown layout isn't an error there: the keyboard silently falls back to
// plain US without options, so everything is checked against the lists.

// XKB keeps at most 4 layouts at a time
const MAX_LAYOUTS = 4;

// -> { models: [{ name, description }], layouts: [...],
//      variants: { layout: [{ name, description }] },
//      groups: [{ name, description, options: [{ name, description }] }] }
function parseLst(text) {
    const db = {
        models: [],
        layouts: [],
        variants: {},
        groups: []
    };
    const groupsByName = {};
    let section = "";
    for (const raw of String(text ?? "").split("\n")) {
        if (raw.startsWith("!")) {
            section = raw.slice(1).trim();
            continue;
        }
        const m = raw.match(/^\s+(\S+)\s+(.*\S)\s*$/);
        if (!m)
            continue;
        const name = m[1];
        const description = m[2];
        if (section === "model") {
            db.models.push({
                name,
                description
            });
        } else if (section === "layout") {
            db.layouts.push({
                name,
                description
            });
        } else if (section === "variant") {
            const v = description.match(/^([^:\s]+):\s*(.*)$/);
            if (!v)
                continue;
            (db.variants[v[1]] = db.variants[v[1]] ?? []).push({
                name,
                description: v[2]
            });
        } else if (section === "option") {
            const colon = name.indexOf(":");
            if (colon < 0) {
                // Its options may have come first
                const group = groupsByName[name];
                if (group) {
                    group.description = description;
                } else {
                    groupsByName[name] = {
                        name,
                        description,
                        options: []
                    };
                    db.groups.push(groupsByName[name]);
                }
            } else {
                const groupName = name.slice(0, colon);
                let group = groupsByName[groupName];
                if (!group) {
                    group = groupsByName[groupName] = {
                        name: groupName,
                        description: groupName,
                        options: []
                    };
                    db.groups.push(group);
                }
                group.options.push({
                    name,
                    description
                });
            }
        }
    }
    return db;
}

function _split(text) {
    return String(text ?? "").split(",").map(s => s.trim());
}

// kb_layout / kb_variant -> [{ layout, variant }] (empty layouts dropped)
function parseLayouts(layoutText, variantText) {
    const layouts = _split(layoutText);
    const variants = _split(variantText);
    const out = [];
    layouts.forEach((layout, i) => {
        if (layout !== "")
            out.push({
                layout,
                variant: variants[i] ?? ""
            });
    });
    return out;
}

// [{ layout, variant }] -> { layout: "us,br", variant: "alt-intl,abnt2" }
// (variant "" when none has one)
function joinLayouts(list) {
    const layouts = list.map(l => l.layout);
    const variants = list.map(l => l.variant ?? "");
    return {
        layout: layouts.join(","),
        variant: variants.some(v => v !== "") ? variants.join(",") : ""
    };
}

function findLayout(db, name) {
    return db.layouts.find(l => l.name === name) ?? null;
}

function findVariant(db, layout, variant) {
    return (db.variants[layout] ?? []).find(v => v.name === variant) ?? null;
}

function isValid(db, entry) {
    return findLayout(db, entry.layout) !== null && (!entry.variant || findVariant(db, entry.layout, entry.variant) !== null);
}

// "English (US, alt. intl.)"; the raw names when unknown
function describe(db, entry) {
    if (entry.variant) {
        const v = findVariant(db, entry.layout, entry.variant);
        return v ? v.description : entry.layout + " (" + entry.variant + ")";
    }
    return findLayout(db, entry.layout)?.description ?? entry.layout;
}

// "US", "BR", "US·INTL"-like short tag for badges: the layout in capitals
function shortName(entry) {
    return String(entry.layout ?? "").toUpperCase().slice(0, 3);
}

// Every layout and variant as one searchable list, for the picker:
// [{ layout, variant, description }], each layout followed by its variants
function allEntries(db) {
    const out = [];
    for (const l of db.layouts) {
        out.push({
            layout: l.name,
            variant: "",
            description: l.description
        });
        for (const v of db.variants[l.name] ?? [])
            out.push({
                layout: l.name,
                variant: v.name,
                description: v.description
            });
    }
    return out;
}

// Words of `query` all found in the entry's description or names
function matches(entry, query) {
    const words = String(query ?? "").toLowerCase().split(/\s+/).filter(w => w !== "");
    if (words.length === 0)
        return true;
    const hay = (entry.description + " " + entry.layout + " " + (entry.variant ?? "") + " " + (entry.name ?? "")).toLowerCase();
    return words.every(w => hay.includes(w));
}

// ============================================================================
// OPTIONS
// ============================================================================

function parseOptions(text) {
    return String(text ?? "").split(",").map(s => s.trim()).filter(s => s !== "");
}

function groupOf(option) {
    const colon = option.indexOf(":");
    return colon < 0 ? option : option.slice(0, colon);
}

// Groups where only one option makes sense at a time
const SINGLE_GROUPS = ["caps", "compose", "grp", "lv3", "altwin", "ctrl"];

// Options with `option` switched on or off; in a single-choice group it
// replaces the group's other option
function toggleOption(options, option, on) {
    let list = options.filter(o => o !== option);
    if (on) {
        if (SINGLE_GROUPS.includes(groupOf(option)))
            list = list.filter(o => groupOf(o) !== groupOf(option));
        list.push(option);
    }
    return list;
}

// The option of `group` in the list ("" for none)
function optionIn(options, group) {
    return options.find(o => groupOf(o) === group) ?? "";
}

// Sets the group's option ("" removes it)
function setGroupOption(options, group, option) {
    const list = options.filter(o => groupOf(o) !== group);
    if (option)
        list.push(option);
    return list;
}

function findOption(db, option) {
    const group = db.groups.find(g => g.name === groupOf(option));
    return group ? group.options.find(o => o.name === option) ?? null : null;
}

// Options the lists don't know are dropped before they reach Hyprland
function validOptions(db, options) {
    return options.filter(o => findOption(db, o) !== null);
}
