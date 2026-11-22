# Status

**Current milestone:** M2 (look and shaders)

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

## UNVERIFIED
**No Godot binary was run in the build environment** (running the downloaded editor was blocked). Everything below passed static checks only (`gdtoolkit` parse and `tools/validate_project.py`):
- That the project opens in Godot 4.6 with zero errors and zero warnings.
- That `tests/run_all.gd` passes.
- That the menu renders correctly at 1920x1080 and 2400x1080.
- M2: that the shaders compile on the Compatibility renderer, and that custom triangle winding (pipe tubes, caps) faces outward.
- M1: that crates actually fall in all 6 directions under Jolt, and that the camera roll looks smooth.

How to check on your phone: import the project, press Play, and check that the main menu appears. Then open the Debugger tab and check that there are no red errors. Three-finger tap: the overlay shows FPS.

## Known issues
- None recorded yet.
