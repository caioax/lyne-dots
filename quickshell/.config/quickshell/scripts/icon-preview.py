#!/usr/bin/env python3
"""Icon theme previews for Settings › Icons (IconService).

    icon-preview.py ICON_DIRS ID [ID ...]

Finds the file a few icons (a folder, a terminal, a web browser, a
symbolic volume icon, settings and the home folder) come from in each
theme ID, the way apps look them up (the freedesktop icon theme spec): the
theme's folders whose size matches first, then the closest size, then the
themes it inherits, then hicolor. ICON_DIRS: the icon directories, colon
separated, in lookup order. Prints { id: { slot: path } } as JSON; a slot
no theme in the chain has is left out.

Standard library only; nothing is cached (a lookup only checks whether
files exist).
"""

import configparser
import json
import os
import sys

SIZE = 48
EXTENSIONS = (".svg", ".png", ".xpm")
# Slot -> icon names to try, in order
SLOTS = {
    "folder": ("folder",),
    "terminal": ("utilities-terminal", "terminal", "org.gnome.Terminal"),
    "browser": ("web-browser", "internet-web-browser", "applications-internet"),
    "symbolic": ("audio-volume-high-symbolic", "audio-volume-high"),
    "settings": ("preferences-system", "systemsettings", "preferences-desktop"),
    "home": ("user-home", "folder-home"),
}


class Theme:
    def __init__(self, theme_id, roots):
        self.id = theme_id
        # The theme's folder in each icon directory that has one
        self.bases = [os.path.join(r, theme_id) for r in roots if os.path.isdir(os.path.join(r, theme_id))]
        self.inherits = []
        self.dirs = []
        index = next((os.path.join(b, "index.theme") for b in self.bases if os.path.isfile(os.path.join(b, "index.theme"))), None)
        if index is None:
            return
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.optionxform = str
        try:
            with open(index, encoding="utf-8", errors="replace") as f:
                parser.read_file(f)
        except (configparser.Error, OSError):
            return
        if not parser.has_section("Icon Theme"):
            return
        head = parser["Icon Theme"]
        self.inherits = [t.strip() for t in head.get("Inherits", "").split(",") if t.strip()]
        names = head.get("Directories", "").split(",") + head.get("ScaledDirectories", "").split(",")
        for name in dict.fromkeys(n.strip() for n in names if n.strip()):
            if not parser.has_section(name):
                continue
            sec = parser[name]
            try:
                size = int(sec.get("Size", "0"))
                d = {
                    "name": name,
                    "size": size,
                    "scale": int(sec.get("Scale", "1")),
                    "type": sec.get("Type", "Threshold"),
                    "min": int(sec.get("MinSize", size)),
                    "max": int(sec.get("MaxSize", size)),
                    "threshold": int(sec.get("Threshold", "2")),
                }
            except ValueError:
                continue
            if size > 0:
                self.dirs.append(d)

    def files(self, d, icon):
        for base in self.bases:
            for ext in EXTENSIONS:
                path = os.path.join(base, d["name"], icon + ext)
                if os.path.isfile(path):
                    yield path


def matches(d, size):
    if d["scale"] != 1:
        return False
    if d["type"] == "Fixed":
        return d["size"] == size
    if d["type"] == "Scalable":
        return d["min"] <= size <= d["max"]
    return d["size"] - d["threshold"] <= size <= d["size"] + d["threshold"]


def distance(d, size):
    s = d["scale"]
    if d["type"] == "Fixed":
        return abs(d["size"] * s - size)
    if d["type"] == "Scalable":
        if size < d["min"] * s:
            return d["min"] * s - size
        if size > d["max"] * s:
            return size - d["max"] * s
        return 0
    low, high = (d["size"] - d["threshold"]) * s, (d["size"] + d["threshold"]) * s
    if size < low:
        return low - size
    if size > high:
        return size - high
    return 0


def lookup(theme, icon):
    """The spec's LookupIcon: an exact size match, else the closest one"""
    for d in theme.dirs:
        if matches(d, SIZE):
            for path in theme.files(d, icon):
                return path
    best, best_distance = None, None
    for d in theme.dirs:
        for path in theme.files(d, icon):
            dist = distance(d, SIZE)
            if best is None or dist < best_distance:
                best, best_distance = path, dist
            break
    return best


def chain(theme_id, themes, roots):
    """The theme, the ones it inherits (depth first), then hicolor"""
    order, seen = [], set()

    def visit(tid):
        if tid in seen:
            return
        seen.add(tid)
        if tid not in themes:
            themes[tid] = Theme(tid, roots)
        order.append(themes[tid])
        for parent in themes[tid].inherits:
            visit(parent)

    visit(theme_id)
    if "hicolor" not in seen:
        visit("hicolor")
    return order


def preview(theme_id, themes, roots):
    found = {}
    order = chain(theme_id, themes, roots)
    for slot, names in SLOTS.items():
        for icon in names:
            path = next((p for p in (lookup(t, icon) for t in order) if p), None)
            if path:
                found[slot] = path
                break
    return found


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        sys.exit(1)
    roots = [r for r in sys.argv[1].split(":") if r]
    themes = {}
    result = {}
    for theme_id in sys.argv[2:]:
        if theme_id and "/" not in theme_id and theme_id not in result:
            result[theme_id] = preview(theme_id, themes, roots)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
