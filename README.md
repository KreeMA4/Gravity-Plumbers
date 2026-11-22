# Gravity Plumbers

A 3D co-op physics comedy for Android, made in Godot 4. Up to 4 wobbly space plumbers
keep a falling-apart space station from flooding with cosmic sludge, while the
station's gravity keeps shifting.

* **Engine:** Godot **4.6** or newer (4.4 and 4.5 should also work, but they are not tested).
  GDScript only. Jolt physics. Compatibility (OpenGL) renderer.
* **Platform:** Android phones in landscape, with touch controls. It also runs on desktop with
  keyboard, mouse or a gamepad, for testing.
* **No downloads:** every model, texture and sound is made by code in this project.

See `docs/STATUS.md` for what works right now and what is still **UNVERIFIED**.

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

On Android, `user://` is the app's private data folder. The in-game **Settings → Show log**
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

See `docs/STATUS.md`.
