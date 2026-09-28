.pragma library

// Builds a complete lyne-dots theme (palette, terminal, hyprland) from a few
// choices. Colors are placed in OKLCH, with lightness targets taken from the
// bundled presets, and mapped back into sRGB by lowering the chroma.
//
// seed: {
//   name        display name
//   scheme      "dark" | "light"
//   accent      "#rrggbb"
//   exactAccent keep the accent as picked (otherwise its lightness is moved
//               into a readable range for the scheme)
//   tint        0-1, how much the backgrounds and text take the neutral hue
//   neutralHue  hue (degrees) of the backgrounds; the accent's when omitted
//   vibrance    0-1, chroma of the status and terminal colors
//   harmony     0-1, how far the status and terminal hues lean to the accent
// }

// ---------------------------------------------------------------- color math
function _toLinear(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function _toSrgb(c) {
    return c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
}

function hexToRgb(hex) {
    const h = String(hex).replace("#", "");
    return [0, 2, 4].map(i => parseInt(h.substr(i, 2), 16) / 255);
}

function rgbToHex(rgb) {
    return "#" + rgb.map(c => {
        const v = Math.round(Math.min(1, Math.max(0, c)) * 255);
        return (v < 16 ? "0" : "") + v.toString(16);
    }).join("");
}

function _rgbToOklab(rgb) {
    const [r, g, b] = rgb.map(_toLinear);
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s];
}

// Linear sRGB, possibly out of [0, 1]
function _oklabToLinear(lab) {
    const [L, a, b] = lab;
    const l = Math.pow(L + 0.3963377774 * a + 0.2158037573 * b, 3);
    const m = Math.pow(L - 0.1055613458 * a - 0.0638541728 * b, 3);
    const s = Math.pow(L - 0.0894841775 * a - 1.2914855480 * b, 3);
    return [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s];
}

// { l, c, h } with h in degrees
function hexToOklch(hex) {
    const [L, a, b] = _rgbToOklab(hexToRgb(hex));
    const h = Math.atan2(b, a) * 180 / Math.PI;
    return {
        l: L,
        c: Math.hypot(a, b),
        h: h < 0 ? h + 360 : h
    };
}

function _inGamut(lin) {
    return lin.every(v => v >= -0.0001 && v <= 1.0001);
}

// OKLCH -> hex; out-of-gamut colors keep their lightness and hue and lose
// chroma until they fit
function oklch(l, c, h) {
    l = Math.min(1, Math.max(0, l));
    const rad = h * Math.PI / 180;
    const at = chroma => _oklabToLinear([l, chroma * Math.cos(rad), chroma * Math.sin(rad)]);
    let lin = at(c);
    if (!_inGamut(lin)) {
        let lo = 0, hi = c;
        for (let i = 0; i < 24; i++) {
            const mid = (lo + hi) / 2;
            if (_inGamut(at(mid)))
                lo = mid;
            else
                hi = mid;
        }
        lin = at(lo);
    }
    return rgbToHex(lin.map(v => _toSrgb(Math.min(1, Math.max(0, v)))));
}

// WCAG 2 contrast ratio between two colors (1-21)
function contrast(hexA, hexB) {
    const lum = hex => {
        const [r, g, b] = hexToRgb(hex).map(_toLinear);
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    };
    const a = lum(hexA), b = lum(hexB);
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}

// Moves hue `from` towards `to` (shortest way) by t. Hues far from `to` move
// less and opposite ones not at all, so yellow never slides into orange just
// because the accent is blue
function _leanHue(from, to, t) {
    const d = ((to - from + 540) % 360) - 180;
    const falloff = Math.max(0, 1 - Math.abs(d) / 150);
    return (from + d * t * falloff + 360) % 360;
}

function _clamp(v, lo, hi) {
    return Math.min(hi, Math.max(lo, v));
}

// ---------------------------------------------------------------- generator
// Lightness targets per scheme (OKLCH L), from the bundled presets
const _LEVELS = {
    dark: {
        background: 0.23,
        surface0: 0.275,
        surface1: 0.31,
        surface2: 0.40,
        surface3: 0.49,
        text: 0.89,
        subtext: 0.78,
        muted: 0.49,
        greyBlue: 0.33,
        blueDark: 0.19,
        accent: [0.70, 0.86],
        status: 0.76,
        ansi: 0.74,
        ansiBright: 0.80,
        color0: 0.27,
        color8: 0.46
    },
    light: {
        background: 0.955,
        surface0: 0.92,
        surface1: 0.885,
        surface2: 0.82,
        surface3: 0.72,
        text: 0.38,
        subtext: 0.50,
        muted: 0.70,
        greyBlue: 0.87,
        blueDark: 0.93,
        accent: [0.42, 0.60],
        status: 0.58,
        ansi: 0.55,
        ansiBright: 0.61,
        color0: 0.86,
        color8: 0.72
    }
};

// Hues (OKLCH degrees) of the status and ANSI colors before harmonizing
const _HUES = {
    red: 25,
    green: 142,
    yellow: 88,
    blue: 258,
    magenta: 318,
    cyan: 205,
    orange: 52
};

// Moves the lightness of an OKLCH color, within [lo, hi], until `ok` accepts
// it (towards the text side of the scheme); the closest candidate otherwise
function _readable(c, lo, hi, towardsLight, ok) {
    let l = _clamp(c.l, lo, hi);
    const step = towardsLight ? 0.01 : -0.01;
    for (let i = 0; i < 60; i++) {
        const hex = oklch(l, c.c, c.h);
        if (ok(hex) || (towardsLight ? l >= hi : l <= lo))
            return hex;
        l = _clamp(l + step, lo, hi);
    }
    return oklch(l, c.c, c.h);
}

function generate(seed) {
    const scheme = seed.scheme === "light" ? "light" : "dark";
    const lv = _LEVELS[scheme];
    const tint = _clamp(seed.tint ?? 0.5, 0, 1);
    const vibrance = _clamp(seed.vibrance ?? 0.5, 0, 1);
    const harmony = _clamp(seed.harmony ?? 0.15, 0, 1);

    const acc = hexToOklch(seed.accent || "#7aa2f7");
    // Grey accents have no meaningful hue: use a neutral blue for the tint
    const accHue = acc.c < 0.02 ? 260 : acc.h;
    const nHue = seed.neutralHue ?? accHue;
    // Light backgrounds show a tint much sooner than dark ones
    const nC = (scheme === "dark" ? 0.05 : 0.025) * tint;

    const neutral = (l, cScale) => oklch(l, nC * (cScale ?? 1), nHue);
    const background = neutral(lv.background);
    // Readable as text on the background, and under text in the background
    // color (buttons, active tabs)
    const accentOk = hex => contrast(hex, background) >= 4.5;
    const accent = seed.exactAccent ? rgbToHex(hexToRgb(seed.accent)) : _readable(acc, lv.accent[0], lv.accent[1], scheme === "dark", accentOk);

    // Status/ANSI hue, leaning towards the accent
    const hue = name => _leanHue(_HUES[name], accHue, harmony);
    const chroma = 0.06 + 0.14 * vibrance;
    const tone = (name, l, cScale) => oklch(l, chroma * (cScale ?? 1), hue(name));

    const surface0 = neutral(lv.surface0, 1.2);
    const surface1 = neutral(lv.surface1, 1.3);
    const surface2 = neutral(lv.surface2, 1.4);
    const surface3 = neutral(lv.surface3, 1.5);
    const text = neutral(lv.text, 0.7);
    const subtext = neutral(lv.subtext, 0.9);
    const muted = neutral(lv.muted, 1.4);

    const palette = {
        background: background,
        surface0: surface0,
        surface1: surface1,
        surface2: surface2,
        surface3: surface3,
        text: text,
        textReverse: background,
        subtext: subtext,
        subtextReverse: surface3,
        accent: accent,
        success: tone("green", lv.status),
        warning: tone("yellow", lv.status + (scheme === "dark" ? 0.06 : 0.04), 0.9),
        error: tone("red", lv.status - 0.03, 1.1),
        muted: muted,
        greyBlue: oklch(lv.greyBlue, Math.max(nC * 1.5, 0.04 + 0.03 * tint), accHue),
        blueDark: neutral(lv.blueDark, 0.8)
    };

    const ansi = (name, bright) => tone(name, bright ? lv.ansiBright : lv.ansi, bright ? 0.95 : 1);
    const terminal = {
        background: background,
        foreground: text,
        selectionBackground: surface2,
        selectionForeground: text,
        urlColor: ansi("cyan", false),
        cursor: text,
        cursorTextColor: background,
        activeTabBackground: accent,
        activeTabForeground: background,
        inactiveTabBackground: surface1,
        inactiveTabForeground: muted,
        activeBorderColor: accent,
        inactiveBorderColor: surface1,
        color0: neutral(lv.color0, 1.2),
        color1: ansi("red", false),
        color2: ansi("green", false),
        color3: ansi("yellow", false),
        color4: ansi("blue", false),
        color5: ansi("magenta", false),
        color6: ansi("cyan", false),
        color7: subtext,
        color8: neutral(lv.color8, 1.4),
        color9: ansi("red", true),
        color10: ansi("green", true),
        color11: ansi("yellow", true),
        color12: ansi("blue", true),
        color13: ansi("magenta", true),
        color14: ansi("cyan", true),
        color15: text,
        color16: tone("orange", lv.ansi + 0.02),
        color17: tone("red", scheme === "dark" ? 0.60 : 0.50, 1.1)
    };

    const bare = hex => hex.replace("#", "");
    return {
        name: seed.name || "Custom",
        variant: scheme,
        custom: true,
        seed: {
            accent: seed.accent,
            exactAccent: !!seed.exactAccent,
            tint: tint,
            neutralHue: seed.neutralHue ?? null,
            vibrance: vibrance,
            harmony: harmony
        },
        palette: palette,
        opacity: {
            background: scheme === "dark" ? 0.9 : 0.95
        },
        hyprland: {
            activeBorder: bare(accent) + "ff",
            inactiveBorder: bare(surface3) + "aa",
            shadowColor: bare(palette.blueDark) + "ee"
        },
        terminal: terminal
    };
}
