.pragma library

// Monitor rules for Settings › Hyprland › Monitors (MonitorsService).
// A rule is what state.json keeps under monitors.rules, one per monitor:
//   { output, name, label, disabled, mode, position, scale, transform,
//     mirror, vrr, bitdepth, cm, sdrbrightness, sdrsaturation }
// `output` is the Hyprland selector: "desc:<description>" when the
// description tells the monitor apart, else its port. `name` is the port it
// was last seen on. The generated ~/.config/hypr/monitors.lua holds one
// hl.monitor() per rule after a catch-all for monitors without one.

var HEADER = "-- Monitors: managed by lyne (Settings › Hyprland › Monitors)";
var CATCH_ALL = 'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })';
var MIN_SCALE = 0.25;
var MAX_SCALE = 4;

// "1920x1080@179.96Hz" (hyprctl) or "1920x1080@179.96" (rules)
function parseMode(text) {
    var m = /^(\d+)x(\d+)(?:@([\d.]+))?/.exec(String(text || ""));
    if (!m)
        return null;
    return {
        width: parseInt(m[1]),
        height: parseInt(m[2]),
        refresh: m[3] !== undefined ? parseFloat(m[3]) : 0
    };
}

function modeString(width, height, refresh) {
    return width + "x" + height + "@" + formatRefresh(refresh);
}

// Two decimals like hyprctl's availableModes (179.96, 60.00 → 60)
function formatRefresh(refresh) {
    return String(Math.round(refresh * 100) / 100);
}

// Available modes of a monitor, deduplicated, biggest and fastest first
function modes(monitor) {
    var seen = {};
    var out = [];
    var list = monitor && monitor.availableModes ? monitor.availableModes : [];
    for (var i = 0; i < list.length; i++) {
        var mode = parseMode(list[i]);
        if (!mode)
            continue;
        var key = modeString(mode.width, mode.height, mode.refresh);
        if (seen[key])
            continue;
        seen[key] = true;
        out.push(mode);
    }
    out.sort(function (a, b) {
        return (b.width * b.height - a.width * a.height) || (b.width - a.width) || (b.refresh - a.refresh);
    });
    return out;
}

// Hyprland rejects a scale whose logical size isn't whole and snaps it to
// the nearest n/120 that gives one (Monitor.cpp); offer only those
function scaleValid(width, height, scale) {
    if (!(scale > 0))
        return false;
    var w = width / scale;
    var h = height / scale;
    return w === Math.round(w) && h === Math.round(h);
}

function validScales(width, height) {
    var out = [];
    if (!(width > 0 && height > 0))
        return [1];
    for (var n = Math.ceil(MIN_SCALE * 120); n <= MAX_SCALE * 120; n++) {
        var scale = n / 120;
        if (scaleValid(width, height, scale))
            out.push(Math.round(scale * 100000) / 100000);
    }
    return out;
}

// The valid scale nearest to `scale` (what Hyprland would pick)
function nearestScale(width, height, scale) {
    var best = 1;
    var bestDistance = Infinity;
    var list = validScales(width, height);
    for (var i = 0; i < list.length; i++) {
        var distance = Math.abs(list[i] - scale);
        if (distance < bestDistance) {
            best = list[i];
            bestDistance = distance;
        }
    }
    return best;
}

// Common steps worth a button: the valid ones among these
var SCALE_STEPS = [1, 1.25, 1.5, 1.75, 2, 2.5, 3];

function scaleSteps(width, height) {
    return SCALE_STEPS.filter(function (s) {
        return scaleValid(width, height, s);
    });
}

function formatScale(scale) {
    return String(Math.round(scale * 100000) / 100000);
}

// Size on the layout: pixels / scale, width and height swapped when rotated
// (odd transforms: 90°, 270° and their flipped versions)
function logicalSize(width, height, scale, transform) {
    var s = scale > 0 ? scale : 1;
    var w = Math.round(width / s);
    var h = Math.round(height / s);
    return (transform % 2 === 1) ? { width: h, height: w } : { width: w, height: h };
}

// Outputs the editor leaves alone: the FALLBACK one Hyprland makes when no
// monitor is left, and virtual ones
function ignored(monitor) {
    return !monitor || monitor.name === "FALLBACK" || /^HEADLESS/.test(monitor.name);
}

function isInternal(name) {
    return /^(eDP|LVDS|DSI)/.test(name || "");
}

// Selector of a connected monitor: its description, unless another
// connected monitor shares it (two alike without a serial) or it has none
function selectorFor(monitor, all) {
    var desc = monitor.description || "";
    if (desc === "")
        return monitor.name;
    for (var i = 0; i < all.length; i++) {
        if (all[i].name !== monitor.name && (all[i].description || "") === desc)
            return monitor.name;
    }
    return "desc:" + desc;
}

// The stored rule for a connected monitor: by its selector, else one saved
// by its port (imported from nwg-displays, or before it had a description)
function ruleFor(rules, monitor, all) {
    var selector = selectorFor(monitor, all);
    for (var i = 0; i < rules.length; i++) {
        if (rules[i].output === selector)
            return rules[i];
    }
    for (var j = 0; j < rules.length; j++) {
        if (rules[j].output === monitor.name)
            return rules[j];
    }
    return null;
}

function _luaString(text) {
    return '"' + String(text).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"';
}

function _number(value) {
    return String(Math.round(Number(value) * 100000) / 100000);
}

// One hl.monitor() line. Disabled rules keep their other values in state
// (turning the monitor back on restores them) but only write `disabled`.
// `explicit` writes every field, defaults included: hl.monitor() from
// hyprctl eval merges into the rule already there for the same output, so a
// value left out (a rotation, a mirror, disabled) would survive the trial
function ruleToLua(rule, explicit) {
    var parts = ["output = " + _luaString(rule.output)];
    if (rule.disabled)
        return "hl.monitor({ " + parts[0] + ", disabled = true })";
    if (explicit)
        parts.push("disabled = false");
    parts.push("mode = " + _luaString(rule.mode || "preferred"));
    parts.push("position = " + _luaString(rule.position || "auto"));
    parts.push("scale = " + (rule.scale === "auto" || rule.scale === undefined ? '"auto"' : _number(rule.scale)));
    if (rule.transform || explicit)
        parts.push("transform = " + Math.round(rule.transform || 0));
    if (rule.mirror || explicit)
        parts.push("mirror = " + _luaString(rule.mirror || ""));
    var vrr = rule.vrr !== undefined && rule.vrr !== null && rule.vrr >= 0 ? Math.round(rule.vrr) : -1;
    if (vrr >= 0 || explicit)
        parts.push("vrr = " + vrr);
    if (rule.bitdepth === 10 || explicit)
        parts.push("bitdepth = " + (rule.bitdepth === 10 ? 10 : 8));
    if (rule.cm || explicit)
        parts.push("cm = " + _luaString(rule.cm || "srgb"));
    var hdr = /^hdr/.test(rule.cm || "");
    var brightness = hdr && rule.sdrbrightness !== undefined ? Number(rule.sdrbrightness) : 1;
    var saturation = hdr && rule.sdrsaturation !== undefined ? Number(rule.sdrsaturation) : 1;
    if (brightness !== 1 || explicit)
        parts.push("sdrbrightness = " + _number(brightness));
    if (saturation !== 1 || explicit)
        parts.push("sdrsaturation = " + _number(saturation));
    return "hl.monitor({ " + parts.join(", ") + " })";
}

// Short hash of the rules, written as a global at the end of the file so
// `lyne monitors` and the service can tell the file really ran
function hash(text) {
    var h = 5381;
    for (var i = 0; i < text.length; i++)
        h = ((h * 33) ^ text.charCodeAt(i)) >>> 0;
    return h.toString(16);
}

function fileContent(rules) {
    var lines = rules.map(function (r) {
        return ruleToLua(r, false);
    });
    var body = lines.join("\n");
    return [HEADER,
        "-- Edit them there: this file is rewritten on Apply. Rules by desc: follow",
        "-- the monitor to any port; later rules win over the catch-all",
        "",
        CATCH_ALL
    ].concat(lines).concat(["", "lyne_monitors_file = " + _luaString(hash(body)), ""]).join("\n");
}

function isManaged(text) {
    return String(text || "").indexOf(HEADER) === 0;
}

// Rules of a monitors.lua written by another tool (nwg-displays): each
// hl.monitor({ key = value, ... }) line with string, number or boolean
// values. Like Hyprland, a later call for the same output merges into the
// earlier one and moves it last
function importLua(text) {
    var raws = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(/^\s+/, "");
        if (line.indexOf("--") === 0)
            continue;
        var call = /hl\.monitor\(\s*\{(.*)\}\s*\)/.exec(line);
        if (!call)
            continue;
        var fields = {};
        var re = /([a-z_]+)\s*=\s*("((?:[^"\\]|\\.)*)"|true|false|-?[\d.]+)/g;
        var m;
        while ((m = re.exec(call[1])) !== null) {
            var value = m[2];
            if (m[3] !== undefined)
                value = m[3].replace(/\\(.)/g, "$1");
            else if (value === "true" || value === "false")
                value = value === "true";
            else
                value = parseFloat(value);
            fields[m[1]] = value;
        }
        if (typeof fields.output !== "string" || fields.output === "")
            continue; // the catch-all
        var merged = {};
        raws = raws.filter(function (r) {
            if (r.output !== fields.output)
                return true;
            merged = r;
            return false;
        });
        for (var key in fields)
            merged[key] = fields[key];
        raws.push(merged);
    }
    return raws.map(function (f) {
        var rule = {
            output: f.output,
            name: f.output.indexOf("desc:") === 0 ? "" : f.output,
            disabled: f.disabled === true,
            mode: typeof f.mode === "string" ? f.mode : "preferred",
            position: typeof f.position === "string" ? f.position : "auto",
            scale: f.scale === undefined || f.scale === "auto" ? "auto" : Number(f.scale),
            transform: Number(f.transform || 0),
            mirror: typeof f.mirror === "string" ? f.mirror : ""
        };
        if (f.vrr !== undefined)
            rule.vrr = Number(f.vrr);
        if (f.bitdepth !== undefined)
            rule.bitdepth = Number(f.bitdepth);
        if (typeof f.cm === "string")
            rule.cm = f.cm;
        if (f.sdrbrightness !== undefined)
            rule.sdrbrightness = Number(f.sdrbrightness);
        if (f.sdrsaturation !== undefined)
            rule.sdrsaturation = Number(f.sdrsaturation);
        return rule;
    });
}

// Rules for port-only entries whose monitor is connected now with a
// description: moved to desc: so they follow the monitor
function upgradeSelectors(rules, monitors) {
    return rules.map(function (rule) {
        if (rule.output.indexOf("desc:") === 0)
            return rule;
        for (var i = 0; i < monitors.length; i++) {
            var m = monitors[i];
            if (m.name === rule.output && !ignored(m)) {
                var selector = selectorFor(m, monitors);
                var copy = JSON.parse(JSON.stringify(rule));
                copy.output = selector;
                copy.name = m.name;
                if (!copy.label)
                    copy.label = m.model || m.description || m.name;
                return copy;
            }
        }
        return rule;
    });
}

// The rule describing what a connected monitor shows now, on top of its
// stored rule (VRR mode, color settings and turned-off values live only
// there; hyprctl can't tell "VRR fullscreen only" from off)
function ruleFromLive(monitor, all, stored) {
    var rule = stored ? JSON.parse(JSON.stringify(stored)) : {};
    rule.output = selectorFor(monitor, all);
    rule.name = monitor.name;
    rule.label = monitor.model || monitor.description || monitor.name;
    if (monitor.disabled) {
        rule.disabled = true;
        if (!rule.mode)
            rule.mode = "preferred";
        if (!rule.position)
            rule.position = "auto";
        if (rule.scale === undefined)
            rule.scale = "auto";
        if (rule.transform === undefined)
            rule.transform = 0;
        if (rule.mirror === undefined)
            rule.mirror = "";
        return rule;
    }
    rule.disabled = false;
    rule.mode = modeString(monitor.width, monitor.height, monitor.refreshRate);
    rule.position = monitor.x + "x" + monitor.y;
    rule.scale = Math.round(monitor.scale * 100000) / 100000;
    rule.transform = monitor.transform || 0;
    var mirrorOf = monitor.mirrorOf && monitor.mirrorOf !== "none" ? monitor.mirrorOf : "";
    if (mirrorOf !== "") {
        // mirrorOf is a monitor id: keep the stored selector when it still
        // points at that monitor
        var target = null;
        for (var i = 0; i < all.length; i++) {
            if (String(all[i].id) === String(mirrorOf) || all[i].name === mirrorOf)
                target = all[i];
        }
        rule.mirror = target ? selectorFor(target, all) : (rule.mirror || "");
    } else {
        rule.mirror = "";
    }
    if (rule.vrr === undefined && monitor.vrr)
        rule.vrr = 1;
    if (rule.bitdepth === undefined && /2101010/.test(monitor.currentFormat || ""))
        rule.bitdepth = 10;
    return rule;
}

// Rules to store: the ones of connected monitors (from the editor) plus the
// stored ones of monitors not connected now (kept for when they return)
function mergeRules(stored, connectedRules, monitors) {
    var outputs = {};
    var ports = {};
    connectedRules.forEach(function (r) {
        outputs[r.output] = true;
    });
    monitors.forEach(function (m) {
        if (!ignored(m))
            ports[m.name] = true;
    });
    var kept = stored.filter(function (r) {
        if (outputs[r.output])
            return false;
        // A port rule for a port now used by a monitor with its own rule
        if (r.output.indexOf("desc:") !== 0 && ports[r.output])
            return false;
        return true;
    });
    return connectedRules.concat(kept);
}

// hyprctl eval text that tries rules live (not saved): Hyprland applies them
// on its next frame. The saved file stays as it was, so a config reload
// brings it back
function trialLua(rules) {
    return rules.map(function (r) {
        return ruleToLua(r, true);
    }).join("\n");
}
