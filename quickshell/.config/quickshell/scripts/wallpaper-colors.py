#!/usr/bin/env python3
"""Accent candidates of an image, for Settings › Theme › New theme.

Prints up to 8 hex colors, best accent first: the image is quantized, near
duplicates (in OKLab) are merged, and colors are ranked by chroma with a
small weight for how much of the image they cover, so a small bright logo
can beat a large dull background.

usage: wallpaper-colors.py IMAGE
"""
import math
import sys

from PIL import Image


def to_linear(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def oklab(rgb):
    r, g, b = (to_linear(c) for c in rgb)
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def main():
    img = Image.open(sys.argv[1]).convert("RGB")
    img.thumbnail((256, 256))
    q = img.quantize(colors=48, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette()
    total = img.width * img.height
    colors = []
    for count, idx in q.getcolors():
        rgb = tuple(pal[idx * 3:idx * 3 + 3])
        lab = oklab(rgb)
        colors.append({"rgb": rgb, "lab": lab, "share": count / total, "chroma": math.hypot(lab[1], lab[2])})

    # Merge near duplicates into the more common one
    colors.sort(key=lambda c: -c["share"])
    kept = []
    for c in colors:
        twin = next((k for k in kept if math.dist(k["lab"], c["lab"]) < 0.07), None)
        if twin:
            twin["share"] += c["share"]
        else:
            kept.append(c)

    # Too dark or too light to be an accent
    usable = [c for c in kept if 0.3 < c["lab"][0] < 0.95] or kept
    usable.sort(key=lambda c: -(c["chroma"] + 0.02) * c["share"] ** 0.25)
    for c in usable[:8]:
        print("#%02x%02x%02x" % c["rgb"])


if __name__ == "__main__":
    main()
