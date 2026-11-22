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
- **"11 bodies"** means pelvis, chest, head, 2 upper arms, 2 forearm+hand, 2 thighs and 2 shin+foot, as the brief lists them. The simple rig (7 bodies) merges each whole arm and each whole leg.
- **Muscles change angular velocity directly** (a velocity-based PD controller) instead of applying torques. Why: it doesn't depend on mass or inertia, so light and heavy limbs tune the same and the rig is much harder to explode. A fraction of the change is pushed back into the parent body.
- **A hover spring on the pelvis does the standing**, with the legs mostly animating. This is the standard trick that makes active ragdolls controllable. A ray from the pelvis along -local up stands in for the "foot rays".
- **No self-collision inside one plumber.** Every pair of parts gets a collision exception, for stability.
- **The mustache is cosmetic springs, not physics bodies.** It looks the same, costs nothing and never needs syncing.
- **Grab hands landed in M3** (the brief has them in M4), because bracing during gravity shifts needs them. M4 adds the tools.
- **Touch controls take touches in `_input`.** The top 16% of the screen is left alone so HUD buttons stay tappable.
- **"A single player can never hard-fail."** In solo, the sludge meter is capped at 95% and the timer never fails you. Fewer stars is the only penalty. Co-op can flood.
- **Two-player valves and switches work solo:** a two-player valve turns at half speed with one player, and a two-player switch needs only one pull. Same code, but solo stays completable.
- **Gameplay objects share one tiny network state format** (`LevelObject.get_net_state()`). The host broadcasts them a few times a second with the sludge and the work orders, instead of a custom message per object.
- **Pooled goo blobs are disabled with `process_mode = DISABLED`**, which takes them out of the physics space, instead of being freed and recreated.
- **Results screen landed in M5** so the test level can finish; M6 adds the hub and Level 1.
- **Every RPC lives on the NetManager autoload** (plus GravityManager's two). Level nodes are built in code, so their paths would be fragile; an autoload's path never changes.
- **Puppets use the host's rig type** (sent with start_level), so snapshot part lists always line up, even when a client's own quality setting is "simple ragdoll".
- **Network ids for props = build order.** Every peer builds the level from the same data in the same order, so nothing has to be negotiated.
- **"Back to Lobby" after a level** returns everyone to the lobby screen. The hub is also playable online, as a lobby level choice.
- **The fake remote bot** feeds its input through the real packet encoder and the simulated lag and loss queue, so one phone can test the network path.
