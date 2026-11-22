# Status

**Current milestone:** M0 (foundation)

## Done
- project.godot: Jolt Physics, Compatibility renderer, gravity 0, 60 Hz physics, physics interpolation, landscape, touch emulated from the mouse.
- Autoloads: Tuning, SaveData, GameState, Quality, GravityManager, AudioManager, NetManager (offline only for now).
- Main menu built in code. Screens that aren't built yet are greyed out.
- Debug overlay (three-finger tap or F3).
- Logs in `user://logs/`.
- Save file with versioning, migration and corrupt-file fallback.
- Android export preset. `tools/validate_project.py`. Test framework with save tests.

## UNVERIFIED
**No Godot binary was run in the build environment** (running the downloaded editor was blocked). Everything below passed static checks only (`gdtoolkit` parse and `tools/validate_project.py`):
- That the project opens in Godot 4.6 with zero errors and zero warnings.
- That `tests/run_all.gd` passes.
- That the menu renders correctly at 1920x1080 and 2400x1080.

How to check on your phone: import the project, press Play, and check that the main menu appears. Then open the Debugger tab and check that there are no red errors. Three-finger tap: the overlay shows FPS.

## Known issues
- None recorded yet.
