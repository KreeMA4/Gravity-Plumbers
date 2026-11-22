#!/usr/bin/env python3
"""Run one Godot command for CI and judge it honestly.

Godot often exits with code 0 even when scripts fail to compile or errors are
printed, so this wrapper also scans the output. A step FAILS if:
  * the process exits non-zero or times out, or
  * the log contains SCRIPT ERROR / Parse Error / ERROR: lines (not allow-listed), or
  * an --expect pattern is missing (e.g. the test summary line), proving the
    thing we wanted to run actually ran.

Usage:
  python3 tools/ci/run_godot.py --name import --log logs/import.log --timeout 600 \
      [--expect "REGEX"] [--allow "REGEX"] -- <godot> --headless --path . --import

The result line is appended to $GITHUB_STEP_SUMMARY when available.
"""
import argparse
import os
import re
import subprocess
import sys
import time

ERROR_PATTERNS = [
    re.compile(r"SCRIPT ERROR"),
    re.compile(r"Parse Error"),
    re.compile(r"Failed to load script"),
    re.compile(r"Compile Error"),
    re.compile(r"^\s*ERROR:"),
    re.compile(r"Invalid call|Invalid access|Invalid assignment|Invalid get index|Invalid set index"),
    re.compile(r"Attempt to call function .* in base 'null instance'"),
]

# Lines that are known to be harmless on a CI machine (no audio device, etc.).
DEFAULT_ALLOW = [
    re.compile(r"ALSA|PulseAudio|audio driver", re.I),
    re.compile(r"Unable to initialize .*audio", re.I),
]


def summary(line):
    print(line)
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as f:
            f.write(line + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True)
    ap.add_argument("--log", required=True)
    ap.add_argument("--timeout", type=int, default=600)
    ap.add_argument("--expect", action="append", default=[])
    ap.add_argument("--allow", action="append", default=[])
    ap.add_argument("--quiet", action="store_true", help="don't echo Godot output (it's still in --log)")
    ap.add_argument("cmd", nargs=argparse.REMAINDER)
    a = ap.parse_args()
    cmd = a.cmd[1:] if a.cmd and a.cmd[0] == "--" else a.cmd
    os.makedirs(os.path.dirname(a.log) or ".", exist_ok=True)
    allow = DEFAULT_ALLOW + [re.compile(x) for x in a.allow]
    print("$ " + " ".join(cmd), flush=True)
    start = time.time()
    lines = []
    timed_out = False
    with open(a.log, "w", encoding="utf-8") as logf:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
        try:
            for line in proc.stdout:
                if not a.quiet:
                    sys.stdout.write(line)
                logf.write(line)
                lines.append(line.rstrip("\n"))
                if time.time() - start > a.timeout:
                    timed_out = True
                    proc.kill()
                    break
            proc.wait(timeout=30)
        except subprocess.TimeoutExpired:
            timed_out = True
            proc.kill()
    code = proc.returncode
    problems = []
    counts = {}
    for i, line in enumerate(lines):
        if any(p.search(line) for p in ERROR_PATTERNS) and not any(p.search(line) for p in allow):
            ctx = " | ".join(l.strip() for l in lines[i + 1:i + 2] if l.strip())
            key = "%s  %s" % (line.strip(), ("[" + ctx + "]") if ctx else "")
            if key not in counts:
                problems.append(key)
                counts[key] = 0
            counts[key] += 1
    problems = ["%s  (x%d)" % (k, counts[k]) if counts[k] > 1 else k for k in problems]
    leaks = sorted(set(l.strip() for l in lines if "Resource still in use" in l or "Leaked instance" in l))
    for l in leaks[:15]:
        problems.append("  detail: " + l)
    missing = [e for e in a.expect if not any(re.search(e, l) for l in lines)]
    secs = time.time() - start
    ok = (code == 0) and not timed_out and not problems and not missing
    status = "PASS" if ok else "FAIL"
    summary("- **%s**: %s (exit %s, %.0fs, %d log lines)" % (a.name, status, "timeout" if timed_out else code, secs, len(lines)))
    for p in problems[:40]:
        summary("  - error: `%s`" % p.replace("`", "'")[:400])
    if len(problems) > 40:
        summary("  - ... and %d more errors (see the logs artifact)" % (len(problems) - 40))
    for m in missing:
        summary("  - expected output not found: `%s` (the step did not really run to completion)" % m)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
