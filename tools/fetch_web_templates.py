"""Install Godot's single-threaded web export templates.

The official template bundle (.tpz) is ~1 GB, but it is a zip, so this reads
only the two web_nothreads entries out of it with HTTP range requests and
drops them where the editor looks for them.

Usage: python3 tools/fetch_web_templates.py [version]   (default 4.7.2)
"""
import io
import os
import sys
import time
import urllib.request
import zipfile

VERSION = sys.argv[1] if len(sys.argv) > 1 else "4.7.2"
URL = ("https://github.com/godotengine/godot/releases/download/"
       f"{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz")
DEST = os.path.expanduser(
    f"~/.local/share/godot/export_templates/{VERSION}.stable")
WANTED = ("web_nothreads_release.zip", "web_nothreads_debug.zip")


def _retry(fn, attempts=6):
    """GitHub's release CDN throws the odd 5xx; back off and try again."""
    for attempt in range(attempts):
        try:
            return fn()
        except OSError:
            if attempt == attempts - 1:
                raise
            time.sleep(2 ** attempt)


class RangeFile(io.RawIOBase):
    """Seekable read-only view of a remote file, one range request per read."""

    def __init__(self, url):
        r = _retry(lambda: urllib.request.urlopen(urllib.request.Request(url, method="HEAD")))
        self.url = r.geturl()
        self.size = int(r.headers["Content-Length"])
        self.pos = 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, off, whence=0):
        base = (0, self.pos, self.size)[whence]
        self.pos = base + off
        return self.pos

    def _fetch(self, n):
        end = min(self.pos + n, self.size) - 1
        req = urllib.request.Request(
            self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        data = _retry(lambda: urllib.request.urlopen(req).read())
        self.pos += len(data)
        return data

    def readinto(self, b):
        if self.pos >= self.size or len(b) == 0:
            return 0
        data = self._fetch(len(b))
        b[:len(data)] = data
        return len(data)

    def readall(self):
        # zipfile reads the whole tail when looking for the directory - one
        # request instead of thousands of 8 KB ones.
        if self.pos >= self.size:
            return b""
        return self._fetch(self.size - self.pos)


def main():
    os.makedirs(DEST, exist_ok=True)
    z = zipfile.ZipFile(io.BufferedReader(RangeFile(URL), buffer_size=1 << 20))
    for name in z.namelist():
        base = os.path.basename(name)
        if base in WANTED:
            with z.open(name) as src, open(os.path.join(DEST, base), "wb") as dst:
                dst.write(src.read())
            print("installed", os.path.join(DEST, base))


if __name__ == "__main__":
    main()
