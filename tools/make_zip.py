#!/usr/bin/env python3
"""Build dist/GravityPlumbers_<milestone>.zip of the project for the phone.

Usage:  python3 tools/make_zip.py M3
Excludes .git, the .godot cache, build outputs and old zips. Only the latest
zip is kept in dist/ so the repository doesn't fill up with copies.
"""
import os
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
EXCLUDE_DIRS = {".git", ".godot", "build", "dist", "__pycache__"}


def main():
    milestone = sys.argv[1] if len(sys.argv) > 1 else "dev"
    dist = os.path.join(ROOT, "dist")
    os.makedirs(dist, exist_ok=True)
    for old in os.listdir(dist):
        if old.endswith(".zip"):
            os.remove(os.path.join(dist, old))
    out = os.path.join(dist, "GravityPlumbers_%s.zip" % milestone)
    count = 0
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for dirpath, dirnames, filenames in os.walk(ROOT):
            dirnames[:] = sorted(d for d in dirnames if d not in EXCLUDE_DIRS)
            for fn in sorted(filenames):
                if fn.endswith((".zip", ".pyc", ".apk", ".tmp")):
                    continue
                full = os.path.join(dirpath, fn)
                arc = os.path.join("GravityPlumbers", os.path.relpath(full, ROOT))
                z.write(full, arc)
                count += 1
    print("Wrote %s (%d files, %.1f KB)" % (os.path.relpath(out, ROOT), count, os.path.getsize(out) / 1024))


if __name__ == "__main__":
    main()
