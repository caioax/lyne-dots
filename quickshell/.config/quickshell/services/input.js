.pragma library

// Touchpads for Settings › Input (TouchpadService). `hyprctl devices -j`
// lists them among the mice and has no type field: libinput names end in
// "touchpad" ("syna7db5:01-06cb:cd41-touchpad"), while the same chip's
// "-mouse" interface and keyboards with a "-mouse" interface are left out.

// Names of the touchpads in `hyprctl devices -j` output (text or parsed)
function touchpadNames(devices) {
    let data = devices;
    if (typeof data === "string") {
        try {
            data = JSON.parse(data);
        } catch (e) {
            return [];
        }
    }
    const mice = Array.isArray(data?.mice) ? data.mice : [];
    const names = [];
    for (const m of mice) {
        const name = typeof m?.name === "string" ? m.name : "";
        if (/touchpad/i.test(name) && !names.includes(name))
            names.push(name);
    }
    return names;
}

// Names to keep a rule for: the saved ones (a touchpad not listed yet at
// startup keeps its rule) plus the ones seen now, in that order
function mergeNames(saved, seen) {
    const out = [];
    for (const name of [...(saved ?? []), ...(seen ?? [])]) {
        if (typeof name === "string" && name !== "" && !out.includes(name))
            out.push(name);
    }
    return out;
}
