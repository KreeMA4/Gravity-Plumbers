#!/usr/bin/env bash
# Verify an exported APK is really installable: signed, arm64, right package,
# required permissions present, landscape orientation. Fails loudly otherwise.
# Usage: tools/ci/verify_apk.sh path/to/app.apk
set -euo pipefail
APK="$1"
BT="$(ls -d "$ANDROID_SDK_ROOT"/build-tools/* | sort -V | tail -n 1)"
AAPT="$BT/aapt"
APKSIGNER="$BT/apksigner"
fail() { echo "APK CHECK FAILED: $*"; echo "- APK check: **FAIL** - $*" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"; exit 1; }

[ -s "$APK" ] || fail "APK missing or empty: $APK"
SIZE=$(stat -c %s "$APK")
[ "$SIZE" -gt 5000000 ] || fail "APK is suspiciously small ($SIZE bytes)"

echo "== apksigner verify"
"$APKSIGNER" verify --verbose --print-certs "$APK" | tee /tmp/apksigner.txt
grep -q "Verified using v2 scheme (APK Signature Scheme v2): true\|Verified using v1 scheme (JAR signing): true" /tmp/apksigner.txt || fail "APK signature does not verify"

echo "== aapt badging"
"$AAPT" dump badging "$APK" | tee /tmp/badging.txt
grep -q "package: name='org.gravityplumbers.game'" /tmp/badging.txt || fail "wrong package name"
grep -q "native-code: 'arm64-v8a'" /tmp/badging.txt || fail "no arm64-v8a native code (needed for the Galaxy S25 Ultra)"
grep -q "launchable-activity" /tmp/badging.txt || fail "no launchable activity"
for p in INTERNET ACCESS_NETWORK_STATE ACCESS_WIFI_STATE CHANGE_WIFI_MULTICAST_STATE VIBRATE; do
  grep -q "uses-permission: name='android.permission.$p'" /tmp/badging.txt || fail "missing permission $p"
done

echo "== manifest orientation"
"$AAPT" dump xmltree "$APK" AndroidManifest.xml > /tmp/manifest.txt
grep -i "screenOrientation" /tmp/manifest.txt | tee /tmp/orient.txt
# 0 = landscape, 6 = sensorLandscape, 8 = reverseLandscape, 11 = userLandscape
grep -Eq "screenOrientation.*\(type 0x10\)0x(0|6|8|b)\b" /tmp/orient.txt || fail "activity is not landscape"

echo "== pck inside"
unzip -l "$APK" | grep -Eq "assets/.*\.pck|assets/_cl_" || unzip -l "$APK" | grep -q "assets/" || fail "no game data in assets/"

{
  echo "- APK check: **PASS** - $(basename "$APK"), $((SIZE / 1024 / 1024)) MB, signed, arm64-v8a, landscape, all 5 permissions"
  echo '  ```'
  grep -E "^package:|sdkVersion|targetSdkVersion|native-code" /tmp/badging.txt
  echo '  ```'
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
echo "APK OK"
