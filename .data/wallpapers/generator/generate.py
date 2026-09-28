#!/usr/bin/env python3
"""Default lyne-dots wallpapers, generated from the theme presets.

Every theme in .data/themes/*.json gets three scenes, drawn from its palette
with the lyne-dots logo (same geometry as .data/assets/logo/lyne-dots-tight.svg
and the shell's LyneLogo: dot = accent, line = the accent's hue at 0.57
saturation / 0.9 lightness):

    lake     mountains, pines and a mirror lake (night on dark themes,
             dawn on light ones) - the theme's default wallpaper
    waves    layered flat waves with soft shadows, the logo as the sun
    contour  a big logo wrapped in contour lines

Output: .data/wallpapers/themes/<theme>/lyne-<theme>-<scene>.jpg

Pipeline: shapes (ridges, pines, stars, logo) are written as SVG and
rasterized by librsvg (antialiased); skies, glows, haze and the reflection are
computed in float32 with colors mixed in OKLab; grain + TPDF dither on the way
to 8 bits keep the gradients free of banding. Deterministic (fixed seeds).

Needs python-numpy, python-pillow and rsvg-convert (librsvg). The wordmark
uses the bundled Quicksand (SIL OFL, fonts/OFL-Quicksand.txt).

usage: generate.py [--themes a,b] [--scenes lake,waves,contour]
                   [--size 3840x2160] [--out DIR] [--jobs N]
"""
import argparse, colorsys, io, json, math, os, re, subprocess, sys
from concurrent.futures import ProcessPoolExecutor
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.dirname(os.path.dirname(HERE))
THEMES_DIR = os.path.join(DATA, "themes")
LOGO_SVG = os.path.join(DATA, "assets/logo/lyne-dots-tight.svg")
FONT = os.path.join(HERE, "fonts/Quicksand-500.ttf")
SCENES = ("lake", "waves", "contour")
WHITE = np.ones(3, np.float32)
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
def blur(a, s):
    """gaussian blur (FFT), 2D or HxWxC"""
    if s <= 0.3:
        return a
    pad = int(3 * s) + 1
    p = np.pad(a, [(pad, pad), (pad, pad)] + [(0, 0)] * (a.ndim - 2), mode="reflect")
    H, W = p.shape[:2]
    g = np.exp(-2 * (np.pi * s) ** 2 * (np.fft.rfftfreq(W)[None, :] ** 2 + np.fft.fftfreq(H)[:, None] ** 2))
    one = lambda x: np.fft.irfft2(np.fft.rfft2(x) * g, s=(H, W)).astype(np.float32)
    out = one(p) if a.ndim == 2 else np.stack([one(p[..., i]) for i in range(a.shape[2])], -1)
    return out[pad:-pad, pad:-pad]


def svg_rgba(body, W, H):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{body}</svg>'
    png = subprocess.run(["rsvg-convert"], input=svg.encode(), capture_output=True, check=True).stdout
    a = np.asarray(Image.open(io.BytesIO(png)).convert("RGBA"), np.float32) / 255
    return a[..., :3], a[..., 3]


def svg_mask(body, W, H):
    return svg_rgba(body, W, H)[1]


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


def poly_path(xs, ys, close_y):
    pts = " L".join(f"{f(x)} {f(y)}" for x, y in zip(xs, ys))
    return f"M{f(xs[0])} {f(close_y)} L{pts} L{f(xs[-1])} {f(close_y)} Z"


def fbm1d(n, rng, octaves, base, persist, smooth=True):
    """1D fractal noise in about [-1, 1]"""
    out, amp, tot = np.zeros(n), 1.0, 0.0
    x = np.linspace(0, 1, n)
    for o in range(octaves):
        k = int(base * 2 ** o) + 2
        pts = rng.uniform(-1, 1, k)
        u = x * (k - 1)
        i = np.clip(u.astype(int), 0, k - 2)
        fr = u - i
        if smooth:
            fr = fr * fr * (3 - 2 * fr)
        out += amp * (pts[i] * (1 - fr) + pts[i + 1] * fr)
        tot += amp
        amp *= persist
    return out / tot


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


def put_logo(img, c, cx, cy, height, glow=0.0):
    """logo centered at (cx, cy); colors pushed off the background when needed"""
    H, W = img.shape[:2]
    lw = height * LOGO["w"] / LOGO["h"]
    x0, y0 = cx - lw / 2, cy - height / 2
    box = img[int(max(y0, 0)):int(y0 + height), int(max(x0, 0)):int(x0 + lw)]
    behind = box.reshape(-1, 3).mean(0)
    line, dot = legible(c["line"], behind), legible(c["dot"], behind)
    k = height / LOGO["h"]
    rgb, a = svg_rgba(f'<g transform="translate({f(x0)} {f(y0)}) scale({k:.5f})">{logo_body(line, dot)}</g>', W, H)
    if glow > 0:
        img = screen(img, dot, blur(a, height * 0.22) * glow)
    return over(img, rgb, a), line


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


def brand(img, c, cx, cy, H, glow=True):
    """logo + wordmark block centered at (cx, cy)"""
    S = H / 1080
    lh = 110 * S
    ly = cy - 32 * S
    img, line = put_logo(img, c, cx, ly, lh, glow=0.5 if glow and not c["light"] else 0)
    top = ly + lh / 2 + 16 * S
    behind = img[int(top):int(top + 50 * S), int(cx - 150 * S):int(cx + 150 * S)].reshape(-1, 3).mean(0)
    word = legible(mix(c["text"], line, 0.25) if not c["light"] else c["text"], behind, 0.3)
    return put_wordmark(img, [("lyne", word), ("-dots", legible(line, behind, 0.25))], cx, top, 44 * S, 10 * S)


# ---------------------------------------------------------------- palette
def palette(theme):
    d = json.load(open(os.path.join(THEMES_DIR, theme + ".json")))
    c = {k: hexrgb(v) for k, v in d["palette"].items() if isinstance(v, str) and v.startswith("#")}
    for k in ("color3", "color5", "color6", "color16"):
        c[k] = hexrgb(d["terminal"][k])
    c["light"] = lum(c["background"]) > lum(c["text"])
    c["dot"] = c["accent"]
    c["line"] = logo_line_color(c["accent"])
    c["deep"] = c["background"] if c["light"] else c["blueDark"]
    c["warm"] = mix(c["color3"], c["color16"], 0.5)
    return c


# ================================================================ lake
def pine(rng, cx, base_y, h, w):
    """one pine: stacked drooping tiers"""
    tiers = int(np.clip(h / (w * 0.55), 4, 9))
    pts_r, pts_l = [], []
    top = base_y - h
    for i in range(1, tiers + 1):
        fr = i / tiers
        y = top + h * 0.9 * fr
        half = w / 2 * (0.18 + 0.82 * fr) * rng.uniform(0.9, 1.08)
        inner = half * 0.42
        pts_r += [(cx + half, y + h * 0.012), (cx + inner, y - h * 0.035)]
        pts_l += [(cx - half * rng.uniform(0.92, 1.05), y + h * 0.012), (cx - inner, y - h * 0.035)]
    pts = [(cx, top)] + pts_r[:-1] + [(cx + w * 0.06, base_y), (cx - w * 0.06, base_y)] + list(reversed(pts_l[:-1]))
    return "M" + " L".join(f"{f(x)} {f(y)}" for x, y in pts) + " Z"


def shore(rng, S, x0, x1, y0, y1, h0, h1, dens, hz):
    """pines along (x0,y0)-(x1,y1) over a filled ground; one <path> per shape
    so the ground and the trees never cancel each other's winding"""
    d = [f"M{f(x0)} {f(y0 - 0.09 * h0)} L{f(x1)} {f(y1 - 0.09 * h1)} L{f(x1)} {f(hz + S)} L{f(x0)} {f(hz + S)} Z"]
    n = int(abs(x1 - x0) / (dens * S))
    for i in range(n):
        fr = i / n
        x = x0 + (x1 - x0) * fr + rng.uniform(-0.35, 0.35) * dens * S
        y = y0 + (y1 - y0) * fr + rng.uniform(4, 9) * S
        h = (h0 + (h1 - h0) * fr ** 0.8) * rng.uniform(0.72, 1.12)
        d.append(pine(rng, x, min(y, hz), h, h * rng.uniform(0.3, 0.38)))
    return "".join(f'<path d="{p}"/>' for p in d)


def stars(rng, W, H, S, count, max_y, avoid=None):
    circles = []
    for _ in range(int(count * W * H / (1920 * 1080))):
        x, y = rng.uniform(0, W), max_y * rng.random() ** 1.4
        if avoid and math.hypot(x - avoid[0], y - avoid[1]) < avoid[2]:
            continue
        b = rng.random() ** 5
        op = (0.25 + 0.75 * b) * max(0.0, 1 - y / (max_y * 1.06)) ** 0.8
        circles.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f((0.55 + 1.3 * b) * S)}" fill-opacity="{op:.3f}"/>')
    return svg_mask('<g fill="#fff">' + "".join(circles) + "</g>", W, H)


def scene_lake(c, W, H, seed=11):
    S = H / 1080
    rng = np.random.default_rng(seed)
    light = c["light"]
    hz = H * 0.70
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    bg, text, accent, deep = c["background"], c["text"], c["accent"], c["deep"]
    if not light:
        sky = [shade(deep, -0.03), mix(deep, accent, 0.16), mix(bg, accent, 0.42)]
        glow_c = mix(accent, text, 0.55)
        orb_c = mix(text, WHITE, 0.35)
        orb = (W * 0.73, H * 0.275, H * 0.036)
        mts = [shade(mix(bg, accent, 0.50), 0.02), mix(bg, accent, 0.34), mix(deep, accent, 0.20)]
        haze_c = mix(sky[2], text, 0.25)
        trees = [mix(deep, accent, 0.10), shade(deep, -0.035)]
        water = shade(deep, -0.01)
    else:
        sky = [mix(bg, accent, 0.48), mix(bg, accent, 0.22), mix(bg, c["warm"], 0.30)]
        glow_c = mix(c["warm"], WHITE, 0.45)
        orb_c = shade(mix(bg, WHITE, 0.85), 0.01)
        orb = (W * 0.70, hz - H * 0.215, H * 0.045)
        mts = [mix(sky[1], accent, 0.28), mix(bg, accent, 0.46), mix(accent, text, 0.22)]
        haze_c = mix(sky[2], WHITE, 0.4)
        trees = [mix(accent, text, 0.42), mix(text, accent, 0.28)]
        water = mix(accent, text, 0.15)

    # --- sky + glow around the orb
    img = ramp([(0, sky[0]), (0.55, sky[1]), (1, sky[2])], np.clip(yy / hz, 0, 1) ** 1.15)
    d = np.hypot(xx - orb[0], yy - orb[1]) / H
    g = (0.30 * np.exp(-d / 0.07) + 0.16 * np.exp(-d / 0.28)) if not light else (0.65 * np.exp(-d / 0.10) + 0.35 * np.exp(-d / 0.40))
    img = screen(img, glow_c, np.clip(g, 0, 1))
    if light:  # thin clouds lit from below
        cl = np.zeros((H, W), np.float32)
        rc = np.random.default_rng(seed + 7)
        for _ in range(16):
            cy_, cx_ = H * rc.uniform(0.08, 0.5), W * rc.uniform(-0.1, 1.1)
            w_, h_ = W * rc.uniform(0.07, 0.2), H * rc.uniform(0.004, 0.010)
            cl += np.exp(-((xx - cx_) / w_) ** 2 - ((yy - cy_) / h_) ** 2) * rc.uniform(0.4, 1)
        img = over(img, mix(glow_c, bg, 0.3), blur(np.clip(cl, 0, 1), 2 * S) * 0.45)
    else:
        st = stars(rng, W, H, S, 900, hz * 0.8, (orb[0], orb[1], H * 0.08))
        img = over(img, mix(text, WHITE, 0.3), st)
        img = screen(img, glow_c, blur(st, 3 * S) * 1.6)

    # --- orb: textured moon / plain sun, with a halo
    ox, oy, orr = orb
    disk = svg_mask(f'<circle cx="{f(ox)}" cy="{f(oy)}" r="{f(orr)}" fill="#fff"/>', W, H)
    dm = np.hypot(xx - ox, yy - oy)
    if not light:
        tex = blur(np.random.default_rng(seed + 3).normal(0, 1, (H, W)).astype(np.float32), 5 * S)
        tex /= np.abs(tex).max() + 1e-6
        limb = np.clip(dm / orr, 0, 1)
        img = over(img, orb_c[None, None, :] * (1 - 0.10 * tex[..., None] - 0.06 * limb[..., None] ** 3), disk)
    else:
        img = over(img, orb_c, disk)
    img = screen(img, glow_c, np.exp(-np.maximum(dm - orr, 0) / (H * 0.012)) * (1 - disk) * (0.55 if not light else 0.7))

    # --- three mountain ranges, lit on the side facing the orb
    hzb = np.exp(-((yy - hz) / (H * 0.05)) ** 2)
    for i, (base, amp, bs, skew, so) in enumerate([(hz - H * 0.05, H * 0.27, 3, -0.5, 1),
                                                   (hz - H * 0.02, H * 0.19, 4, -0.45, 2),
                                                   (hz, H * 0.11, 5, 0.6, 3)]):
        r2 = np.random.default_rng(seed + so)
        n = W // 2
        big = 1 - np.abs(fbm1d(n, r2, 2, bs, 0.45))
        det = fbm1d(n, r2, 7, bs * 6, 0.52, smooth=False)
        env = 0.55 + 0.45 * np.exp(-(np.linspace(-1, 1, n) - skew) ** 2 / 0.6)
        ridge = np.minimum(base - amp * env * (big ** 1.6 * 0.85 + 0.10 * det + 0.1), hz)
        xs = np.linspace(-2, W + 2, n)
        m = svg_mask(f'<path d="{poly_path(xs, ridge, hz + 2 * S)}" fill="#fff"/>', W, H)
        rc = np.interp(np.arange(W), xs, ridge).astype(np.float32)
        depth = np.clip((yy - rc[None, :]) / (H * 0.3), 0, 1)
        face = np.tanh(blur(np.clip(np.gradient(rc) / S, -2, 2)[None, :].repeat(3, 0), 40 * S)[1] * 1.5)
        col = np.broadcast_to(mts[i], (H, W, 3)).copy()
        lit = face[None, :] * (1 - depth) ** 2 * (0.22 if not light else 0.12)
        if not light:
            col = over(col, glow_c, np.clip(lit, 0, 1))
            col = over(col, shade(mts[i], -0.05), np.clip(-lit, 0, 1) * 1.2)
        else:
            col = over(col, shade(mts[i], -0.06), np.clip(lit, 0, 1))
        col = over(col, haze_c, hzb * (0.30 if light else 0.22) * (1 - 0.2 * i))
        img = over(img, col, m)
    img = over(img, haze_c, np.exp(-((yy - hz + H * 0.01) / (H * 0.025)) ** 2) * (0.18 if light else 0.10))

    # --- pine shores: lighter far banks, dark near ones
    rb = np.random.default_rng(seed + 20)
    back = shore(rb, S, -20 * S, W * 0.40, hz - H * 0.10, hz - H * 0.004, H * 0.09, H * 0.022, 8.5, hz) + \
        shore(rb, S, W + 20 * S, W * 0.575, hz - H * 0.13, hz - H * 0.004, H * 0.11, H * 0.022, 8.5, hz)
    front = shore(rb, S, -40 * S, W * 0.33, hz - H * 0.19, hz + H * 0.002, H * 0.20, H * 0.03, 12, hz) + \
        shore(rb, S, W + 40 * S, W * 0.645, hz - H * 0.22, hz + H * 0.002, H * 0.22, H * 0.03, 12, hz)
    far_trees = over(np.broadcast_to(trees[0], (H, W, 3)), haze_c, np.exp(-((yy - hz) / (H * 0.04)) ** 2)[..., None] * 0.18)
    img = over(img, far_trees, svg_mask(f'<g fill="#fff">{back}</g>', W, H))
    img = over(img, trees[1], svg_mask(f'<g fill="#fff">{front}</g>', W, H))
    del far_trees

    # --- lake: mirrored, gently rippled, blurred and tinted
    hzi = int(round(hz))
    up = img[:hzi]
    rh = H - hzi
    ry, rx = np.mgrid[0:rh, 0:W].astype(np.float32)
    k = ry / rh
    sx = np.clip(rx + (np.sin(rx / (37 * S) + ry / (3.1 * S)) * 0.6 + np.sin(rx / (91 * S) - ry / (6.3 * S))) * (0.3 + 3.2 * k) * S, 0, W - 1)
    sy = np.clip(hzi - 1 - ry + np.sin(ry / (4 * S) + rx / (140 * S)) * (0.2 + 1.2 * k) * S, 0, hzi - 1)
    y0, x0 = np.floor(sy).astype(np.int32), np.floor(sx).astype(np.int32)
    y1, x1 = np.minimum(y0 + 1, hzi - 1), np.minimum(x0 + 1, W - 1)
    fy, fx = (sy - y0)[..., None], (sx - x0)[..., None]
    ref = (up[y0, x0] * (1 - fx) + up[y0, x1] * fx) * (1 - fy) + (up[y1, x0] * (1 - fx) + up[y1, x1] * fx) * fy
    del y0, x0, y1, x1, sx, sy
    ref = blur(ref, 1.2 * S)
    ref = over(ref, water, ((0.38 + 0.25 * k) if not light else (0.12 + 0.15 * k))[..., None])
    # glitter trail under the orb
    rg = np.random.default_rng(seed + 1)
    ell, y = [], 3 * S
    while y < rh:
        fr = y / rh
        if rg.random() < 0.85:
            wdt = (8 + 110 * fr ** 0.8) * S * rg.uniform(0.35, 1.1)
            hh = (1.0 + 3.0 * fr) * S
            xc = ox + rg.normal(0, 3 + 22 * fr) * S
            ell.append(f'<ellipse cx="{f(xc)}" cy="{f(y)}" rx="{f(wdt / 2)}" ry="{f(hh / 2)}" fill-opacity="{(0.8 - 0.4 * fr) * rg.uniform(0.45, 1):.3f}"/>')
        y += (2.8 + 10 * fr) * S * rg.uniform(0.7, 1.3)
    gl = blur(svg_mask('<g fill="#fff">' + "".join(ell) + "</g>", W, rh), 0.7 * S)
    ref = screen(ref, orb_c if not light else glow_c, gl * (0.85 if not light else 0.6))
    ref = screen(ref, haze_c, np.exp(-(ry / (1.2 * S)) ** 2) * np.exp(-((rx - W / 2) / (W * 0.28)) ** 2) * 0.35)
    img = np.concatenate([up, ref], 0)

    if not light:  # vignette
        v = np.hypot((xx - W / 2) / (W * 0.75), (yy - H * 0.45) / (H * 0.8))
        img = img * (1 - 0.22 * np.clip(v, 0, 1) ** 2.2)[..., None]
    return brand(img, c, W * 0.5, H * 0.285, H)


# ================================================================ waves
def scene_waves(c, W, H, seed=4):
    S = H / 1080
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    light = c["light"]
    bg, deep, accent, text = c["background"], c["deep"], c["accent"], c["text"]
    if not light:
        top, low = shade(deep, -0.02), mix(bg, accent, 0.30)
        glow_c = mix(accent, text, 0.4)
        bands = [mix(bg, accent, 0.42), mix(bg, accent, 0.30), mix(bg, mix(accent, c["color5"], 0.3), 0.26),
                 mix(deep, accent, 0.14), shade(deep, -0.02)]
    else:
        top, low = mix(bg, accent, 0.30), mix(bg, c["warm"], 0.22)
        glow_c = mix(bg, WHITE, 0.7)
        bands = [mix(bg, accent, 0.22), mix(bg, accent, 0.38), mix(mix(accent, c["color5"], 0.4), bg, 0.42),
                 mix(accent, text, 0.12), mix(accent, text, 0.38)]
    img = ramp([(0, top), (1, low)], np.clip(yy / (H * 0.72), 0, 1))
    sun = (W * 0.5, H * 0.42)
    d = np.hypot(xx - sun[0], yy - sun[1]) / H
    img = screen(img, glow_c, 0.45 * np.exp(-d / 0.10) + 0.20 * np.exp(-d / 0.35))
    if not light:
        img = over(img, mix(text, WHITE, 0.3), stars(np.random.default_rng(seed), W, H, S, 500, H * 0.55))
    for i, col in enumerate(bands):
        r = np.random.default_rng(seed + i * 13)
        xs = np.linspace(-4, W + 4, 400)
        u = xs / W
        ph1, ph2 = r.uniform(0, 6.3, 2)
        fr1, fr2 = r.uniform(0.7, 1.3), r.uniform(1.8, 2.8)
        ys = H * (0.60 + 0.085 * i) + H * (0.07 - 0.008 * i) * (np.sin(u * math.pi * 2 * fr1 + ph1) * 0.7 + np.sin(u * math.pi * 2 * fr2 + ph2) * 0.3)
        m = svg_mask(f'<path d="{poly_path(xs, ys, H + 4)}" fill="#fff"/>', W, H)
        # soft shadow cast on the layer behind
        img = over(img, shade(bands[i - 1] if i else low, -0.10 if not light else -0.12), blur(m, 14 * S) * (1 - m) * (0.55 if not light else 0.35))
        rc = np.interp(np.arange(W), xs, ys).astype(np.float32)
        img = over(img, ramp([(0, shade(col, 0.035)), (1, shade(col, -0.03))], np.clip((yy - rc[None, :]) / (H * 0.25), 0, 1)), m)
    return brand(img, c, sun[0], sun[1] - H * 0.02, H)


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
    theme, scene, W, H, out = job
    c = palette(theme)
    img = {"lake": scene_lake, "waves": scene_waves, "contour": scene_contour}[scene](c, W, H)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    finish(img).save(out, quality=92, subsampling=0, optimize=True, progressive=True)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--themes", help="comma-separated theme ids (default: every .data/themes/*.json)")
    ap.add_argument("--scenes", default=",".join(SCENES))
    ap.add_argument("--size", default="3840x2160")
    ap.add_argument("--out", default=os.path.join(DATA, "wallpapers/themes"))
    ap.add_argument("--jobs", type=int, default=3, help="parallel renders (~3 GB of RAM each at 4K)")
    a = ap.parse_args()
    W, H = (int(v) for v in a.size.lower().split("x"))
    themes = a.themes.split(",") if a.themes else sorted(p[:-5] for p in os.listdir(THEMES_DIR) if p.endswith(".json"))
    jobs = [(t, s, W, H, os.path.join(a.out, t, f"lyne-{t}-{s}.jpg")) for t in themes for s in a.scenes.split(",")]
    with ProcessPoolExecutor(a.jobs) as ex:
        for out in ex.map(render, jobs):
            print(os.path.relpath(out))


if __name__ == "__main__":
    sys.exit(main())
