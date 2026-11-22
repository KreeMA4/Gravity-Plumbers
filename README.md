# Gravity Plumbers

A 3D co-op physics comedy for Android, made in Godot 4. Up to 4 wobbly space plumbers
keep a falling-apart space station from flooding with cosmic sludge, while the
station's gravity keeps shifting.

* **Engine:** Godot **4.6** or newer is recommended. The minimum is **4.4**, the first version
  with built-in Jolt Physics and 3D physics interpolation. GDScript only. Compatibility (OpenGL)
  renderer.
* **Platform:** Android phones in landscape, with touch controls. It also runs on desktop with
  keyboard, mouse or a gamepad, for testing.
* **No downloads:** every model, texture and sound is made by code in this project.

**Status: release candidate 1 (v0.10.0, milestone M10).** All 5 levels, the hub, co-op,
customization, audio and settings are written. **Important:** this project was built without
being able to run Godot, so none of it has been tried in the engine yet. Every script passes a
GDScript parser and the project validator, but expect a few small runtime errors on first
launch. See `docs/STATUS.md` for details and `docs/TESTING.md` for a checklist to work through
on your phone.

## What's in the game
* **Hub, "The Rusty Pipe":** a job console to pick a level and difficulty, a mirror to change
  your outfit, a tool rack, and a practice gravity switch.
* **The 5 levels**, each built around one gravity idea:
  1. **Orbital Bathroom** (tutorial): a single 180° flip.
  2. **Zero-G Cafeteria:** zero-G zones and the G-Wrench.
  3. **Asteroid Waterworks:** planetoid gravity you can walk all the way around.
  4. **Spin-Cycle Habitat:** a scheduled cycle that rotates "down" from wall to wall.
  5. **Reactor Plumbing Panic:** gravity storms and THE GREAT CLOG boss.
* **Wobbly active-ragdoll plumbers:** grab, carry, throw, hang, flop and get up.
* **Tools:** plunger, pipe wrench, duct tape and the gravity-bending **G-Wrench**.
* **Co-op for 2-4 players** over LAN or a phone hotspot (room codes, LAN browsing), with
  best-effort internet play through UPnP.
* **Full customization** with a randomizer, locks and 3 outfit slots. Golden ducks unlock more items.
* **All models, textures, sounds and music are made by code.**
* **Debug rooms:** Gravity Test Room, Look Test Room, Ragdoll Playground, Plumbing Workshop,
  Physics Soak Test, and Run Tests.

---

## 1. Get the project onto your phone (no PC needed)

1. Download the project zip. Either:
   * open `dist/GravityPlumbers_<milestone>.zip` on GitHub and tap **Download**, or
   * on the GitHub page of this branch, tap **Code → Download ZIP**.
2. Open the **Files** app (or "Files by Google").
3. Move the zip to **Documents** or **Downloads**. Android Go phones only let Godot see those
   two folders.
4. Tap the zip and choose **Extract**. You should now have a folder that contains
   `project.godot`. With the dist zip that folder is `GravityPlumbers/`; with a GitHub zip it
   has the branch name.

## 2. Open it in the Godot Android editor

1. Install **Godot Engine 4.6** (or newer) from the Play Store, or install the official Android
   editor APK from godotengine.org.
2. Open Godot. In the **Project Manager**, tap **Import**.
3. Browse to the extracted folder, pick `project.godot`, then tap **Import & Edit**.
4. The first import takes a minute or two, because Godot converts the sounds and the icon.
   Wait until the progress bar at the bottom is gone.
5. Tap **▶ (Play)** at the top right. The game starts at the main menu.

**If you see errors:** open the **Debugger** tab at the bottom of the editor, then the
**Errors** sub-tab. Long-press to copy the red lines and paste them to Claude. The game also
writes logs you can read afterwards:
* `user://logs/game.log`: the game's own messages.
* `user://logs/godot.log`: the engine's messages.

On Android, `user://` is the app's private data folder. The in-game **Settings → Show recent log**
button shows the last lines on screen.

## 3. Controls

**Touch (landscape):**
* **Left thumb:** a floating joystick appears wherever you touch the left half of the screen.
* **Right half:** drag anywhere that isn't a button to look around.
* **Buttons:** Jump, Grab L, Grab R (hold), Use (tool or interact), Boots (toggle),
  Flop, Get Up, Emote and Pause.
* **Settings → Controls:** single Grab button, left-handed layout, button size and opacity,
  haptics.

**Desktop:** WASD to move, drag with the mouse to look, Space to jump, Q/E to grab left/right,
F to use, G for boots, R to flop, T to get up, X to emote, Esc to pause. F3 shows the debug
overlay and F4 cycles gravity (only in debug rooms). Gamepads work too.

**Debug overlay:** tap with three fingers, or press F3.

## 4. Export an APK (play without the editor)

1. In the editor, open **Project → Export…**.
2. The **Android** preset is already set up: arm64-v8a, debug, no Gradle, with the permissions
   INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE and VIBRATE.
3. If the editor says **export templates are missing**, tap **Manage Export Templates →
   Download and Install**. This is the one download Godot itself needs.
4. If it asks for a **debug keystore**, the Android editor normally makes one for you. If it
   doesn't, go to **Editor Settings → Export → Android**, tap the folder next to
   *Debug Keystore* and let it generate one. Never put keystores in this project.
5. Make sure **Use Gradle Build** is OFF, then tap **Export Project…**, choose a file name in
   Downloads (for example `GravityPlumbers.apk`) and untick **Export With Debug** only if you
   have a release keystore.
6. Open the APK from the Files app to install it. Android will ask you to allow installs from
   the Godot app or the Files app.

## 5. Play together (LAN and hotspot)

All phones must be on the **same Wi-Fi**, or connected to the **host phone's hotspot**.

* **Host:** Main menu → **Host Game** → choose a level and difficulty → **Start Hosting**.
  The lobby shows a **room code** like `ABCDE-FGHIJ` and the local IP.
* **Join:** Main menu → **Join Game**. Hosts on the same network appear in the list
  automatically, so just tap one. You can also type the room code, or open **Advanced** and
  enter the IP and port.
* **No Wi-Fi?** Turn on the host phone's **mobile hotspot**, have friends connect to it, and
  join with the room code. The Join screen has step-by-step help.
* **Internet play (best effort):** the host tries UPnP. If your router allows it, a second
  "internet" room code appears. If not, the lobby explains the other options: port forwarding
  (UDP 24777), a hotspot, or a VPN like Tailscale or ZeroTier.

Ports: game **UDP 24777**, LAN discovery **UDP 24778**.

## 6. Tweak the game feel

Every tunable number is in **`scripts/core/tuning.gd`**, each with a comment. Change one,
press Play, and feel the difference. `docs/TUNING.md` says which ones to try first.

## 7. For developers

* `python3 tools/validate_project.py`: static checks (paths, autoloads, indentation,
  class names, input actions, Godot 3 syntax, autoload member typos). Uses only the Python
  standard library.
* `python3 tools/make_audio.py`: regenerates every `.wav` in `assets/audio/`.
* `python3 tools/make_zip.py M3`: builds `dist/GravityPlumbers_M3.zip`.
* Tests: `godot --headless --import`, then `godot --headless -s res://tests/run_all.gd`.
  You can also run them on the phone from **Main menu → Debug rooms → Run Tests**.
* Desktop network test: `godot -- --server` in one window and `godot -- --client=127.0.0.1`
  in another.
* Soak test: `godot -- --soak`, or **Debug rooms → Physics Soak Test**.

## 8. Known issues

* **Nothing has been run in Godot yet** (see the status note at the top). Please report the first errors you hit.
* On the internet (as opposed to LAN or hotspot), clients feel their own plumber lag, because the host is in charge of all physics.
* If knees or elbows bend the wrong way, see the "Joint limits" note in `docs/TUNING.md`.
* More in `docs/STATUS.md`.

## 9. Project layout

```
project.godot, export_presets.cfg, icon.svg, README.md
docs/      STATUS, DECISIONS, TUNING, NETWORK, TESTING
tools/     validate_project.py, make_audio.py, make_zip.py, extract_strings.py
tests/     run_all.gd, test_runner.gd + logic tests
assets/    audio/*.wav (generated), lang/strings.csv
shaders/   toon, outline, starfield (sky), goo, blob_shadow
scenes/    main.tscn (the only scene; everything else is built in code)
scripts/   core/ gravity/ character/ items/ plumbing/ net/ levels/ ui/ fx/ audio/
```
