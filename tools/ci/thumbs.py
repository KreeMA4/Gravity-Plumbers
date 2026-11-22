#!/usr/bin/env python3
"""Screenshot report for CI: exposure statistics + tiny thumbnails in the log.

  python3 tools/ci/thumbs.py ci_screens/*.png

For every screenshot prints one line of numbers that describe how "washed out"
it is, and writes a table to $GITHUB_STEP_SUMMARY:
  white%   share of pixels that are nearly white (all channels > 0.9)
  clip%    share of pixels with any channel at >= 0.99 (blown out)
  sat      mean HSV saturation (0 = grey, 1 = pure colour)
  lum      mean luminance;  contrast = luminance standard deviation
With THUMBS="name1,name2,..." it also prints one small contact-sheet JPEG of
those shots as base64 ("THUMB sheet i/n data"), so the pictures can be looked
at from the job log alone. The STATS lines come last.
Needs Pillow (pip install pillow).
"""
import base64
import io
import os
import sys

from PIL import Image


def stats(img):
    small = img.convert("RGB").resize((320, int(320 * img.height / img.width)))
    px = list(small.getdata())
    n = len(px)
    white = clip = 0
    sat_sum = lum_sum = lum_sq = 0.0
    for r, g, b in px:
        r, g, b = r / 255.0, g / 255.0, b / 255.0
        mx, mn = max(r, g, b), min(r, g, b)
        if mn > 0.9:
            white += 1
        if mx >= 0.99:
            clip += 1
        sat_sum += (mx - mn) / mx if mx > 0 else 0.0
        lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        lum_sum += lum
        lum_sq += lum * lum
    mean = lum_sum / n
    var = max(0.0, lum_sq / n - mean * mean)
    return {"white": 100.0 * white / n, "clip": 100.0 * clip / n, "sat": sat_sum / n,
            "lum": mean, "contrast": var ** 0.5}


def contact_sheet(paths, names, cell_w=240):
    """One small JPEG with the chosen shots in a grid (cheap to view from the log)."""
    picks = [p for n in names for p in paths if os.path.splitext(os.path.basename(p))[0] == n]
    if not picks:
        return None
    cell_h = cell_w * 9 // 16
    cols = 4
    rows = (len(picks) + cols - 1) // cols
    sheet = Image.new("RGB", (cell_w * cols, cell_h * rows), (0, 0, 0))
    for i, p in enumerate(picks):
        im = Image.open(p).convert("RGB").resize((cell_w, cell_h))
        sheet.paste(im, ((i % cols) * cell_w, (i // cols) * cell_h))
    buf = io.BytesIO()
    sheet.save(buf, "JPEG", quality=58)
    return buf.getvalue()


def main(paths):
    rows = []
    for p in sorted(paths):
        name = os.path.splitext(os.path.basename(p))[0]
        rows.append((name, stats(Image.open(p))))
    names = [n for n in os.environ.get("THUMBS", "").split(",") if n]
    data = contact_sheet(paths, names) if names else None
    if data:
        b = base64.b64encode(data).decode()
        chunks = [b[i:i + 3000] for i in range(0, len(b), 3000)]
        for i, c in enumerate(chunks):
            print("THUMB sheet %d/%d %s" % (i + 1, len(chunks), c))
        print("THUMB order: " + ", ".join(n for n in names))
    # Numbers last, so the end of the job log shows them.
    for name, s in rows:
        print("STATS %-26s white %5.1f%%  clip %5.1f%%  sat %.2f  lum %.2f  contrast %.2f"
              % (name, s["white"], s["clip"], s["sat"], s["lum"], s["contrast"]))
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write("\n### Screenshot exposure\n| shot | near-white | blown-out | saturation | luminance | contrast |\n|---|---|---|---|---|---|\n")
            for name, s in rows:
                f.write("| %s | %.1f%% | %.1f%% | %.2f | %.2f | %.2f |\n"
                        % (name, s["white"], s["clip"], s["sat"], s["lum"], s["contrast"]))


if __name__ == "__main__":
    main(sys.argv[1:])
