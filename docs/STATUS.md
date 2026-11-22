# Status

**Current milestone:** M6 (hub and Level 1)

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

## UNVERIFIED
**No Godot binary was run in the build environment** (running the downloaded editor was blocked). Everything below passed static checks only (`gdtoolkit` parse and `tools/validate_project.py`):
- That the project opens in Godot 4.6 with zero errors and zero warnings.
- That `tests/run_all.gd` passes.
- That the menu renders correctly at 1920x1080 and 2400x1080.
- M6: whether Level 1's ceiling leak and valve are comfortable to reach while standing upside down (they may need moving a little lower in `orbital_bathroom.gd`).
- M5: Area3D tank counting with pooled blobs re-enabled through process_mode; PUSH vent strength; the HUD layout on 21:9 screens.
- M4: how the equipped-tool alignment looks in the hand, and that Generic6DOFJoint3D (defaults: all axes locked) holds tools rigidly under Jolt.
- M3: the actual ragdoll feel under Jolt: that it stands, walks without tripping, recovers reliably, and doesn't jitter. Joint hinge angle signs (see TUNING.md). Multi-touch on a real device.
- M2: that the shaders compile on the Compatibility renderer, and that custom triangle winding (pipe tubes, caps) faces outward.
- M1: that crates actually fall in all 6 directions under Jolt, and that the camera roll looks smooth.

How to check on your phone: import the project, press Play, and check that the main menu appears. Then open the Debugger tab and check that there are no red errors. Three-finger tap: the overlay shows FPS.

## Known issues
- None recorded yet.
