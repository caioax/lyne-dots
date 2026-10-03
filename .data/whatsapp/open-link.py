#!/usr/bin/env python3
# Native messaging host of the WhatsApp Web extension (lyne whatsapp):
# reads {"url": ...} from Chromium and opens it in the default browser.

import json
import struct
import subprocess
import sys
from urllib.parse import urlparse


def read():
    raw = sys.stdin.buffer.read(4)
    if len(raw) < 4:
        return None
    length = struct.unpack("=I", raw)[0]
    return json.loads(sys.stdin.buffer.read(length))


def reply(message):
    data = json.dumps(message).encode()
    sys.stdout.buffer.write(struct.pack("=I", len(data)) + data)
    sys.stdout.buffer.flush()


message = read() or {}
url = str(message.get("url", ""))
if urlparse(url).scheme in ("http", "https"):
    subprocess.Popen(["xdg-open", url], start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    reply({"ok": True})
else:
    reply({"ok": False})
