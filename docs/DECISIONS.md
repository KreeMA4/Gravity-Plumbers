# Decisions log

One line per decision: what was decided, and why.

- **No Godot binary was run while building this.** The official Godot 4.6 Linux build downloaded fine, but this environment's permission rules blocked running it. Instead, every script is checked with `gdtoolkit` (a GDScript parser) plus `tools/validate_project.py`. Runtime behaviour is listed under UNVERIFIED in STATUS.md.
- **Input actions are registered in code** (`scripts/core/input_setup.gd`), not in project.godot. Why: the input-map text format is fiddly and easy to break by hand. The validator reads the same list.
- **Screens are built in code and swapped by GameState** under the single `scenes/main.tscn`, instead of `change_scene_to_file`. Why: there is only one tiny .tscn, nothing to break, and the autoloads stay simple.
- **Screen ids are added to GameState.SCREENS milestone by milestone.** Menu buttons for screens that don't exist yet are greyed out and marked "(soon)", so every milestone runs without errors.
- **Autoload order:** Tuning, SaveData, GameState, Quality, GravityManager, AudioManager, NetManager. Each one only uses autoloads listed before it in `_ready`.
- **Logging:** Godot's file logging is on (`user://logs/godot.log`), and `GameLog` also writes `user://logs/game.log`. Game warnings are plain prints, so a healthy session shows zero engine warnings.
- **Physics interpolation is on.** Cameras update in `_process` from `get_global_transform_interpolated()` and have interpolation turned off themselves. Teleports call `reset_physics_interpolation()`.
- **Only the latest milestone zip is kept** in `dist/`, so the git history doesn't fill up with copies.
- **Window:** 1920x1080 base with `canvas_items` stretch and `expand` aspect, so UI sizes are in "1080p pixels" and layouts widen for 21:9 screens. Orientation is sensor-landscape.
