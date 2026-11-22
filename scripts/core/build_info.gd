class_name BuildInfo
extends RefCounted
## Which build this is. The committed copy says "local build". The Android CI
## workflow (tools/ci/stamp_build.py) overwrites it before exporting, with the
## GitHub Actions run number and commit; that change is never committed. So the
## APK on the phone shows exactly which run produced it: on the main menu, in the
## debug overlay (three-finger tap), and in the startup log.

const RUN_NUMBER: int = 0
const COMMIT: String = ""
const LABEL: String = "local build"
