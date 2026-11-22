# Status

**Current milestone:** M10 — release candidate 1 (v0.10.0)

## Done
- project.godot: Jolt Physics, Compatibility renderer, gravity 0, 60 Hz physics, physics interpolation, landscape, touch emulated from the mouse.
- Autoloads: Tuning, SaveData, GameState, Quality, GravityManager, AudioManager, NetManager (offline only for now).
- Main menu built in code. Screens that aren't built yet are greyed out.
- Debug overlay (three-finger tap or F3).
- Logs in `user://logs/`.
- Save file with versioning, migration and corrupt-file fallback.
- Android export preset. `tools/validate_project.py`. Test framework with save tests.

- M1: GravityManager (global gravity with telegraphed shifts, blended transitions, storms, switchable zones replicated by RPC), GravityFieldData (box, sphere with falloff, zero-G with drag, push vent), GravityBody (gravity force, drag, speed clamp, G-Wrench override timer, out-of-bounds reset), GravityHUD arrow, the Gravity Test Room, gravity unit tests, and an in-game test runner.
- M2: toon shader (3 bands plus rim), inverted-hull outline pass, procedural starfield, nebula and planet sky, goo shader, blob shadow shader, cached materials (Mats), PipeBuilder (tubes with parallel-transport frames, flanges, valve wheel, MultiMesh bolts), LevelBuilder (rooms with doorways and windows, rounded edges, lamps, pipes, rocks), the Look Test Room, and a menu backdrop with a window.
- M3: 11-body active ragdoll (7-body "simple" rig on Low quality) with ConeTwist and Hinge joints, PD muscles (LimbController), a hover spring and upright controller along local up, camera-relative walking with a procedural walk cycle, jump with coyote time and buffering, Flop / Get Up, impact and unbraced-shift ragdoll triggers, recovery with a dizzy wobble, magnetic boots with charge, flush and respawn, grab hands (PinJoint to props, plumbers and static pipes; bracing; throwing), googly eyes, mouth states, a swaying mustache, squash and stretch, multi-touch controls, a gravity-following camera with collision, and the Ragdoll Playground with bots.
- M4: ToolBase (right-hand equip with a locked 6DOF joint, context Use label, tap Grab R to drop, auto-return to the rack when lost), Plunger (suction anchor that braces you, clog plunging, zero-G pop), Pipe Wrench (valve turning, tightening, bonk), Duct Tape (leak sealing, taping props in place), G-Wrench (axis override on props and plumbers, custom self-stick direction, beam, cooldown), ToolRack, and Use-to-interact for switches.
- M5: WorkOrder and WorkOrderManager (ordered and parallel orders, early targets, net state; unit tested), SludgeMeter (unit tested; solo can't hard-fail), Leak (spray, tape sealing, goo spitting), Valve (wrench turning, two-player valves that turn at half speed solo), Clog (plunger hits, pop burst), Tank (goo blobs and canisters), PipeSegment plus PipePort (snap radius and angle, locks in), GravitySwitch (global, field or field direction actions; two-player; relay "required_dir"), Vent hazard (telegraphed PUSH burst), GoldenDuck, GooCanister, a GooPool of 60 pooled blobs, KillVolume, LevelCatalog, LevelSpawner (data-driven), LevelRunner (rules, storms, dispatcher lines, flush penalty, all-flushed grace, win/fail, awards), the HUD (sludge bar, timer, checklist, toasts, shift warning with an edge pulse, teammate pointers), the pause menu, the level select console, the results screen, and the Plumbing Workshop test level.
- M6: the hub (The Rusty Pipe: job console with difficulty and stars, tool rack, practice switch and rail, a duck), Level 1 Orbital Bathroom (6 ordered work orders built around one 180° flip; tutorial prompts; ceiling spawn pad used after the flip), and saving stars, best times and ducks to user://save.json.
- M7: NetManager (ENet host/join, version handshake, player list with looks, ready, kick, lobby info, mid-level join with catch-up sync, disconnect handling, ping, ENet traffic stats, rate-limited validated input, 20 Hz snapshots with priority and a byte budget, client interpolation and extrapolation, 5 Hz level state, reliable events, results relay, host-paused notice, fake remote bot through simulated lag and loss, `--server` / `--client=` flags), RoomCode (Crockford base32, forgiving decode; tested), LanDiscovery (UDP beacons with graceful failure), UpnpHelper (worker thread), NetUtil (private IP picking, hotspot-aware), SnapshotSync (tested), the Host/Join screen (LAN list, code, advanced IP, hotspot help, connecting overlay with cancel) and the Lobby screen (code with copy, IPs, UPnP status, player list with 3D previews, ready, kick, level and difficulty, test tools).
- M8: the customise screen (8 category tabs, a SubViewport turntable preview with drag-spin and reaction hop, an option grid with colour swatches and locked items, a randomizer with per-category locks plus colours-only and undo, 3 outfit slots, name edit, Done), the hub mirror, your plumber idling in the menu backdrop, live outfits in the lobby, "Random on join", host-side look clamping, and look/randomizer unit tests.
- M9: Level 2 Zero-G Cafeteria (zero-G dining zone, floating food and canisters, G-Wrench intro, two-player valve, plunger anchoring), Level 3 Asteroid Waterworks (two planetoids with sphere gravity, pipes wrapped round the rock, a zero-G gap with a bridge-pipe puzzle), Level 4 Spin-Cycle Habitat (scheduled gravity cycle floor→wall→ceiling→wall, jobs on every wall, relay switch), Level 5 Reactor Plumbing Panic (3 rooms, storms every 40 s, two coordinated room switches that turn on and aim the reactor field, vents, and THE GREAT CLOG boss fed with goo), Spinner decorations, difficulty scaling, and mid-level join.
- M10: synthesized audio (`tools/make_audio.py`: 33 SFX plus 3 seamless music loops, with the storm layer crossfading), blip voice for the dispatcher and plumbers (screams when flung), footsteps, landing dust, jump rings, hit-stop, a full Settings screen (graphics, comfort, sound, controls, misc, recent log), blob shadows, a static-mesh batching pass for the draw-call budget, interpolation-safe decorative animation, the physics soak test (`godot -- --soak`, exit code), every UI string collected in `assets/lang/strings.csv`, and final docs.

## VERIFIED by Godot 4.6 in GitHub Actions (run #11, all green)
These checks run on every push and every manual build. See `.github/workflows/android-apk.yml`.
- Headless project import: no errors.
- **37/37 logic tests pass** (gravity, work orders, room codes, network codecs, looks, save migration).
- **Every screen and all 7 levels boot** and run 10 s of simulated time with zero script or engine errors: main menu, gravity test, look test, playground, customize, settings, host/join, tests, hub, levels 1-5 and the workshop.
- **Physics soak test passes:** 4 bot plumbers, 30 crates and 40 goo blobs, with random gravity flips for 2 minutes of simulated time. No NaN and nothing escaping.
- **Real OpenGL rendering** (Compatibility renderer through Mesa): every shader compiles. Screenshots of the main menu, the look test, Level 1 and Level 5 are in the `ci-screenshots` artifact.
- **Android export**, with these APK checks passing: signed (debug key), package `org.gravityplumbers.game`, minSdk 24 / targetSdk 35, arm64-v8a, launcher activity, landscape orientation, and all 5 permissions.

Bugs that CI found and that are now fixed:
- Mesh batching called an API that doesn't exist in GDScript.
- The sky shader parameter was read while still null.
- Static resource caches and audio playbacks were left over at quit; the game now shuts down cleanly.
- `get_meta(key, null)` printed an error on every grab or bonk of a non-plumber body. The validator now rejects that pattern.

## UNVERIFIED (needs a real phone)

**No Godot binary was run in the build environment, for ANY milestone** (running the downloaded editor was blocked). Everything below passed static checks only (`gdtoolkit` parse and `tools/validate_project.py`):
- That the project opens in Godot 4.6 with zero errors and zero warnings.
- That `tests/run_all.gd` passes.
- That the menu renders correctly at 1920x1080 and 2400x1080.
- M10: that the generated WAVs import and loop cleanly (looping is set in code), that the batched level meshes look right (they're merged per material), the actual FPS and draw counts on phones, and APK export with the preset.
- M9: level layouts are hand-placed by coordinates and untested in play. Some objects may sit slightly inside walls or be awkward to reach; nudge positions in `scripts/levels/level_data/*.gd`. Overlapping sphere fields between the two asteroids are blended (equal priority), so they make a weak "saddle" zone.
- M8: SubViewport preview sizing in the Compatibility renderer; how comfortable "hold to save" outfit slots are to use.
- M7: everything over a real network: LAN broadcast on Android (multicast lock), hotspot routing, UPnP on real routers, and how interpolation feels at 20 Hz. ENet statistics may report 0 on some platforms.
- M6: whether Level 1's ceiling leak and valve are comfortable to reach while standing upside down (they may need moving a little lower in `orbital_bathroom.gd`).
- M5: Area3D tank counting with pooled blobs re-enabled through process_mode; PUSH vent strength; the HUD layout on 21:9 screens.
- M4: how the equipped-tool alignment looks in the hand, and that Generic6DOFJoint3D (defaults: all axes locked) holds tools rigidly under Jolt.
- M3: the actual ragdoll feel under Jolt: that it stands, walks without tripping, recovers reliably, and doesn't jitter. Joint hinge angle signs (see TUNING.md). Multi-touch on a real device.
- M2: that the shaders compile on the Compatibility renderer, and that custom triangle winding (pipe tubes, caps) faces outward.
- M1: that crates actually fall in all 6 directions under Jolt, and that the camera roll looks smooth.

How to check on your phone: import the project, press Play, and check that the main menu appears. Then open the Debugger tab and check that there are no red errors. Three-finger tap: the overlay shows FPS.

## Known issues
- **Gameplay feel and touch input are unverified.** Godot now runs every screen and level in CI with zero errors, but nobody has played it with fingers yet. Ragdoll feel, touch controls, real networking between phones, and performance on a phone still need testing on a device.
- **Client latency:** clients feel about 2 × ping + 100 ms on their own plumber (pure host authority). Fine on LAN and hotspots. See NETWORK.md.
- **Joint hinge angle signs under Jolt are a guess.** If knees or elbows bend backwards, flip the limits in `ragdoll_builder.gd` (see TUNING.md).
- **Level coordinates were placed by hand without play-testing**, so some objects may need nudging.
- **Look changes from the hub mirror apply from the next level** (the current plumber isn't rebuilt live).
- **Translation:** only English. Strings are collected in `assets/lang/strings.csv`, but no translation is registered in Project Settings yet.
- **Running tests headless needs the class cache:** run `godot --headless --import` before `-s res://tests/run_all.gd`.

## How to verify everything on the phone
Follow `docs/TESTING.md` from M0 down. Each milestone has a short checklist.
