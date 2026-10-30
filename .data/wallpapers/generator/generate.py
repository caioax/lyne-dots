#!/usr/bin/env python3
"""Default lyne-dots wallpapers, generated from the theme presets.

Every theme in .data/themes/*.json gets one scene, contour, drawn from its
palette: a big lyne-dots logo wrapped in contour lines, with the wordmark
(same geometry as .data/assets/logo/lyne-dots-tight.svg and the shell's
LyneLogo: dot = accent, line = the accent's hue at 0.57 saturation / 0.9
lightness). It is the theme's default wallpaper.

Output: .data/wallpapers/themes/<theme>/lyne-<theme>-contour.jpg

Pipeline: the logo rings are written as SVG and rasterized by librsvg
(antialiased); the background and the glow are computed in float32 with
colors mixed in OKLab; grain + TPDF dither on the way to 8 bits keep the
gradients free of banding. Deterministic (fixed seed).

Needs python-numpy, python-pillow and rsvg-convert (librsvg). The wordmark
uses the bundled Quicksand (SIL OFL, fonts/OFL-Quicksand.txt).

usage: generate.py [--themes a,b] [--theme-file PATH ...]
                   [--size 3840x2160] [--out DIR] [--jobs N]

--theme-file renders any theme JSON (e.g. one made in Settings, from
~/.local/themes); its id is the file name without .json.
"""
import argparse, colorsys, io, json, os, re, subprocess, sys
from concurrent.futures import ProcessPoolExecutor
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.realpath(__file__))
DATA = os.path.dirname(os.path.dirname(HERE))
THEMES_DIR = os.path.join(DATA, "themes")
LOGO_SVG = os.path.join(DATA, "assets/logo/lyne-dots-tight.svg")
FONT = os.path.join(HERE, "fonts/Quicksand-500.ttf")
# Minimum OKLab lightness gap between the logo and what is behind it
LOGO_CONTRAST = 0.2


# ---------------------------------------------------------------- color
def hexrgb(h):
    h = h.lstrip("#")[:6]
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)


def hexc(c):
    return "#%02x%02x%02x" % tuple(int(round(float(np.clip(v, 0, 1)) * 255)) for v in c)


def to_lin(c):
    c = np.asarray(c, np.float32)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0, None)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


_M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
                [0.2119034982, 0.6806995451, 0.1073969566],
                [0.0883024619, 0.2817188376, 0.6299787005]], np.float32)
_M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
                [1.9779984951, -2.4285922050, 0.4505937099],
                [0.0259040371, 0.7827717662, -0.8086757660]], np.float32)
_M1I, _M2I = np.linalg.inv(_M1), np.linalg.inv(_M2)


def oklab(c):
    return np.cbrt(to_lin(c) @ _M1.T) @ _M2.T


def from_oklab(l):
    return np.clip(to_srgb(((l @ _M2I.T) ** 3) @ _M1I.T), 0, 1)


def mix(a, b, t):
    """perceptual mix (OKLab) of two sRGB colors"""
    return from_oklab(oklab(a) * (1 - t) + oklab(b) * t).astype(np.float32)


def shade(c, dl=0.0, sat=1.0):
    """shift OKLab lightness by dl and scale chroma by sat"""
    L = oklab(c).copy()
    L[..., 0] += dl
    L[..., 1:] *= sat
    return from_oklab(L).astype(np.float32)


def lum(c):
    return float(oklab(c)[0])


def ramp(stops, t):
    """map a scalar field (0-1) through OKLab color stops [(pos, rgb), ...]"""
    n = 2048
    xs = np.array([p for p, _ in stops])
    labs = np.array([oklab(c) for _, c in stops])
    grid = np.linspace(0, 1, n)
    lut = from_oklab(np.stack([np.interp(grid, xs, labs[:, i]) for i in range(3)], -1)).astype(np.float32)
    return lut[np.clip((t * (n - 1)).astype(np.int32), 0, n - 1)]


def logo_line_color(dot):
    """LyneLogo.qml: the line is the dot's hue at 0.57 saturation / 0.9 lightness"""
    h, l, s = colorsys.rgb_to_hls(*dot)
    return np.array(colorsys.hls_to_rgb(h, l * 0.9, s * 0.57), np.float32)


def legible(col, behind, gap=LOGO_CONTRAST):
    """keep col's hue but move its lightness away from behind when too close"""
    lc, lb = lum(col), lum(behind)
    if abs(lc - lb) >= gap:
        return col
    up = lb < 0.62 if abs(lc - lb) < 0.02 else lc > lb
    return shade(col, (lb + gap if up else lb - gap) - lc)


# ---------------------------------------------------------------- raster
def svg_rgba(body, W, H):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{body}</svg>'
    png = subprocess.run(["rsvg-convert"], input=svg.encode(), capture_output=True, check=True).stdout
    a = np.asarray(Image.open(io.BytesIO(png)).convert("RGBA"), np.float32) / 255
    return a[..., :3], a[..., 3]


def over(img, color, alpha):
    a = alpha[..., None] if np.ndim(alpha) == 2 else alpha
    return img * (1 - a) + color * a


def screen(img, color, alpha):
    a = alpha[..., None] if np.ndim(alpha) == 2 else alpha
    return 1 - (1 - img) * (1 - color * a)


def f(v):
    return f"{v:.2f}"


def finish(img, seed=3, grain=0.9):
    """float -> 8 bit: fine grain + TPDF dither, so gradients never band"""
    rng = np.random.default_rng(seed)
    H, W = img.shape[:2]
    noise = rng.normal(0, grain / 255, (H, W, 1)).astype(np.float32)
    noise = noise + (rng.random((H, W, 3), np.float32) - rng.random((H, W, 3), np.float32)) / 255
    return Image.fromarray((np.clip(img + noise, 0, 1) * 255 + 0.5).astype(np.uint8))


# ---------------------------------------------------------------- logo
def _logo_geom():
    s = open(LOGO_SVG).read()
    vb = [float(v) for v in re.search(r'viewBox="([^"]+)"', s).group(1).split()]
    num = lambda k: float(re.search(fr'\s{k}="([^"]+)"', s).group(1))
    return dict(w=vb[2], h=vb[3], path=re.search(r'<path[^>]* d="([^"]+)"', s).group(1),
                sw=num("stroke-width"), cx=num("cx"), cy=num("cy"), r=num("r"))


LOGO = _logo_geom()


def logo_body(line, dot, sw_extra=0.0, r_extra=0.0):
    return (f'<path d="{LOGO["path"]}" stroke="{hexc(line)}" stroke-width="{LOGO["sw"] + sw_extra:.2f}" '
            f'fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<circle cx="{LOGO["cx"]}" cy="{LOGO["cy"]}" r="{LOGO["r"] + r_extra:.2f}" fill="{hexc(dot)}"/>')


def put_wordmark(img, parts, cx, top, size, spacing):
    """'lyne-dots' letter-spaced, drawn 2x and downsampled for clean edges"""
    H, W = img.shape[:2]
    ss = 2
    font = ImageFont.truetype(FONT, int(round(size * ss)))
    chars = [(ch, col) for t, col in parts for ch in t]
    widths = [font.getlength(ch) / ss for ch, _ in chars]
    x = cx - (sum(widths) + spacing * (len(chars) - 1)) / 2
    x0, x1 = int(max(x - size, 0)), int(min(cx + (cx - x) + size, W))
    y0, y1 = int(max(top - size * 0.3, 0)), int(min(top + size * 1.6, H))
    layer = Image.new("RGBA", ((x1 - x0) * ss, (y1 - y0) * ss), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    for (ch, col), wd in zip(chars, widths):
        dr.text(((x - x0) * ss, (top - y0) * ss), ch, font=font, fill=tuple(int(v * 255) for v in col) + (255,))
        x += wd + spacing
    a = np.asarray(layer.resize((x1 - x0, y1 - y0), Image.LANCZOS), np.float32) / 255
    img = img.copy()
    img[y0:y1, x0:x1] = over(img[y0:y1, x0:x1], a[..., :3], a[..., 3])
    return img


# ---------------------------------------------------------------- palette
def palette(path):
    d = json.load(open(path))
    c = {k: hexrgb(v) for k, v in d["palette"].items() if isinstance(v, str) and v.startswith("#")}
    c["light"] = lum(c["background"]) > lum(c["text"])
    c["dot"] = c["accent"]
    c["line"] = logo_line_color(c["accent"])
    c["deep"] = c["background"] if c["light"] else c["blueDark"]
    return c


# ================================================================ contour
def scene_contour(c, W, H):
    S = H / 1080
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    light = c["light"]
    base = c["background"] if light else mix(c["background"], c["deep"], 0.5)
    img = ramp([(0, shade(base, 0.012)), (1, shade(base, -0.02))], np.clip(np.hypot(xx - W * 0.35, yy - H * 0.4) / W, 0, 1))
    # a big logo right of center, kept inside the 16:10 and 21:9 crops
    lh = H * 0.72
    k = lh / LOGO["h"]
    lw = LOGO["w"] * k
    x0, y0 = W * 0.62 - lw / 2, H * 0.52 - lh / 2
    line, dot = legible(c["line"], base, 0.25), legible(c["dot"], base, 0.25)
    n, gap, thin = 11, 30 * S / k, 2.2 * S / k
    body = ""
    for i in range(n, 0, -1):  # outermost first; each ring = colored stroke minus a base-colored one
        t = (1 - i / n) ** 1.3
        body += logo_body(mix(base, line, 0.10 + 0.55 * t), mix(base, dot, 0.12 + 0.6 * t), 2 * gap * i, gap * i)
        body += logo_body(base, base, 2 * gap * i - 2 * thin, gap * i - thin)
    body += logo_body(line, dot)
    rgb, a = svg_rgba(f'<g transform="translate({f(x0)} {f(y0)}) scale({k:.5f})">{body}</g>', W, H)
    img = over(img, rgb, a)
    d = np.hypot(xx - (x0 + LOGO["cx"] * k), yy - (y0 + LOGO["cy"] * k)) / H
    img = screen(img, dot, np.exp(-d / 0.12) * (0.25 if not light else 0.12))
    # wordmark bottom left, clear of the rings
    word = mix(c["text"], line, 0.25) if not light else c["text"]
    return put_wordmark(img, [("lyne", word), ("-dots", line)], W * 0.2, H * 0.84, 40 * S, 9 * S)


# ---------------------------------------------------------------- main
def render(job):
    path, W, H, out = job
    img = scene_contour(palette(path), W, H)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    finish(img).save(out, quality=92, subsampling=0, optimize=True, progressive=True)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--themes", help="comma-separated theme ids (default: every .data/themes/*.json)")
    ap.add_argument("--theme-file", action="append", default=[], help="a theme JSON anywhere (repeatable); only these are rendered")
    ap.add_argument("--size", default="3840x2160")
    ap.add_argument("--out", default=os.path.join(DATA, "wallpapers/themes"))
    ap.add_argument("--jobs", type=int, default=3, help="parallel renders (~3 GB of RAM each at 4K)")
    a = ap.parse_args()
    W, H = (int(v) for v in a.size.lower().split("x"))
    if a.theme_file:
        themes = [(os.path.basename(p)[:-5] if p.endswith(".json") else os.path.basename(p), p) for p in a.theme_file]
    else:
        ids = a.themes.split(",") if a.themes else sorted(p[:-5] for p in os.listdir(THEMES_DIR) if p.endswith(".json"))
        themes = [(t, os.path.join(THEMES_DIR, t + ".json")) for t in ids]
    jobs = [(path, W, H, os.path.join(a.out, t, f"lyne-{t}-contour.jpg")) for t, path in themes]
    with ProcessPoolExecutor(a.jobs) as ex:
        for out in ex.map(render, jobs):
            print(os.path.relpath(out))


if __name__ == "__main__":
    sys.exit(main())
