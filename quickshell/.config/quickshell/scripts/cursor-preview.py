#!/usr/bin/env python3
"""Cursor theme previews for Settings › Cursor (CursorService).

    cursor-preview.py CACHE_DIR ID THEME_DIR [ID THEME_DIR ...]

Writes CACHE_DIR/<id>/<shape>-<size>.png for a few shapes of each theme
(default, pointer, text, wait), at the sizes the shell offers, from the
xcursor files in THEME_DIR/cursors: the image whose nominal size is closest
(the first frame of animated ones). A theme is only read again when its
folder changes; cache folders of themes not given are removed. Prints
{ id: [shapes found] } as JSON.

Standard library only: xcursor files are parsed here and the PNGs written
with zlib.
"""

import json
import os
import shutil
import struct
import sys
import zlib

VERSION = "1"
SIZES = (24, 32, 48, 64)
# Shape -> xcursor names to try, in order
SHAPES = {
    "default": ("left_ptr", "default", "arrow", "top_left_arrow"),
    "pointer": ("pointer", "hand2", "hand1", "pointing_hand", "hand"),
    "text": ("text", "xterm", "ibeam"),
    "wait": ("watch", "wait", "left_ptr_watch", "progress"),
}
IMAGE_TYPE = 0xFFFD0002
MAX_SIDE = 0x7FFF


def read_images(path):
    """[(nominal, width, height, offset)] of the file's images, first frames
    first; [] when it isn't a readable xcursor file"""
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError:
        return [], b""
    if len(data) < 16 or data[:4] != b"Xcur":
        return [], b""
    header, _version, ntoc = struct.unpack_from("<III", data, 4)
    images = []
    for i in range(ntoc):
        pos = header + i * 12
        if pos + 12 > len(data):
            break
        kind, nominal, offset = struct.unpack_from("<III", data, pos)
        if kind != IMAGE_TYPE or offset + 36 > len(data):
            continue
        _hsize, ckind, _sub, _ver, width, height = struct.unpack_from("<IIIIII", data, offset)
        if ckind != IMAGE_TYPE or not (0 < width <= MAX_SIDE and 0 < height <= MAX_SIDE):
            continue
        if offset + 36 + width * height * 4 > len(data):
            continue
        images.append((nominal, width, height, offset + 36))
    return images, data


def pick(images, size):
    """The first image whose nominal size is closest to size (larger on a tie)"""
    best = None
    for image in images:
        key = (abs(image[0] - size), -image[0])
        if best is None or key < best[0]:
            best = (key, image)
    return best[1] if best else None


def png(width, height, argb):
    """PNG bytes from premultiplied little-endian ARGB pixels"""
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for (p,) in struct.iter_unpack("<I", argb[y * width * 4:(y + 1) * width * 4]):
            a = p >> 24
            r, g, b = (p >> 16) & 255, (p >> 8) & 255, p & 255
            if 0 < a < 255:
                r, g, b = (min(255, c * 255 // a) for c in (r, g, b))
            elif a == 0:
                r = g = b = 0
            rows += bytes((r, g, b, a))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))


def write(path, body):
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(body)
    os.replace(tmp, path)


def stamp_of(theme_dir):
    cursors = os.path.join(theme_dir, "cursors")
    try:
        mtime = os.stat(cursors).st_mtime_ns
    except OSError:
        mtime = 0
    return f"{VERSION}\n{os.path.realpath(theme_dir)}\n{mtime}\n"


def preview(cache_dir, theme_id, theme_dir):
    out = os.path.join(cache_dir, theme_id)
    stamp_path = os.path.join(out, "stamp")
    stamp = stamp_of(theme_dir)
    try:
        with open(stamp_path) as f:
            if f.read() == stamp:
                return sorted(name[:-len("-32.png")] for name in os.listdir(out) if name.endswith("-32.png"))
    except OSError:
        pass

    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out, exist_ok=True)
    found = []
    for shape, names in SHAPES.items():
        for name in names:
            images, data = read_images(os.path.join(theme_dir, "cursors", name))
            if images:
                break
        else:
            continue
        for size in SIZES:
            _nominal, width, height, offset = pick(images, size)
            write(os.path.join(out, f"{shape}-{size}.png"), png(width, height, data[offset:offset + width * height * 4]))
        found.append(shape)
    write(stamp_path, stamp.encode())
    return sorted(found)


def main(argv):
    if len(argv) < 2 or len(argv) % 2 == 1:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 1
    cache_dir = argv[1]
    os.makedirs(cache_dir, exist_ok=True)
    pairs = list(zip(argv[2::2], argv[3::2]))
    result = {}
    for theme_id, theme_dir in pairs:
        if "/" in theme_id or theme_id in ("", ".", ".."):
            continue
        try:
            result[theme_id] = preview(cache_dir, theme_id, theme_dir)
        except Exception as e:  # one broken theme mustn't hide the others
            print(f"{theme_id}: {e}", file=sys.stderr)
            result[theme_id] = []
    # Themes that are gone (only folders this script made)
    for name in os.listdir(cache_dir):
        path = os.path.join(cache_dir, name)
        if name not in result and os.path.isfile(os.path.join(path, "stamp")):
            shutil.rmtree(path, ignore_errors=True)
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
