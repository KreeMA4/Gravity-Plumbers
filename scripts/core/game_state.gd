extends Node
## GameState (autoload)
## -----------------------------------------------------------------------------
## Knows which "screen" is showing (menu, hub, level...) and swaps screens.
## Every screen is a script that builds itself in code; we just do
## `load(path).new()` and add it under the Main node from scenes/main.tscn.
## Also stores the current level choice and difficulty.

signal screen_changed(screen_id: String)
signal app_paused(paused: bool)

## Screens get added here as each milestone lands.
const SCREENS: Dictionary = {
	"main_menu": "res://scripts/ui/main_menu.gd",
	"gravity_test": "res://scripts/levels/gravity_test_room.gd",
	"tests": "res://scripts/ui/tests_screen.gd",
	"look_test": "res://scripts/levels/look_test_room.gd",
	"playground": "res://scripts/levels/ragdoll_playground.gd",
	"game": "res://scripts/levels/level_runner.gd",
	"results": "res://scripts/ui/results_screen.gd",
	"host_join": "res://scripts/ui/host_join_menu.gd",
	"lobby": "res://scripts/ui/lobby_screen.gd",
	"customize": "res://scripts/ui/customize_screen.gd",
	"settings": "res://scripts/ui/settings_menu.gd",
	"soak_test": "res://scripts/levels/soak_test.gd",
}

var difficulty: int = 1                 ## 0 Chill, 1 Normal, 2 Chaos.
var level_id: String = "hub"            ## Which level the next "game" screen loads.
var last_results: Dictionary = {}       ## Filled by LevelRunner for the results screen.
var current_screen_id: String = ""
var menu_message: String = ""           ## Shown once on the main menu (e.g. "Host left").

var _main: Node = null
var _current: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.register_all()
	GameLog.info("Gravity Plumbers %s (%s) starting on %s" % [Tuning.GAME_VERSION, Tuning.MILESTONE_ID, OS.get_name()])


## Called by scenes/main.gd when the main scene is ready.
func register_main(main_node: Node) -> void:
	_main = main_node


## Swap to another screen. `params` is passed to the screen's setup() if it has one.
func goto_screen(screen_id: String, params: Dictionary = {}) -> void:
	if _main == null or not is_instance_valid(_main):
		GameLog.error("goto_screen called before Main was ready")
		return
	if not screen_available(screen_id):
		GameLog.warn("Screen not available yet: " + screen_id)
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	if _current != null and is_instance_valid(_current):
		_main.remove_child(_current)
		_current.queue_free()
	_current = null
	var scr: GDScript = load(SCREENS[screen_id]) as GDScript
	if scr == null:
		GameLog.error("Could not load screen script " + str(SCREENS[screen_id]))
		return
	var node: Node = scr.new() as Node
	node.name = screen_id.capitalize().replace(" ", "")
	if node.has_method("setup"):
		node.call("setup", params)
	_current = node
	current_screen_id = screen_id
	_main.add_child(node)
	screen_changed.emit(screen_id)
	GameLog.info("Screen -> " + screen_id)


## True if the screen's script exists (lets the menu grey out future milestones).
func screen_available(screen_id: String) -> bool:
	return SCREENS.has(screen_id) and ResourceLoader.exists(str(SCREENS[screen_id]))


func get_current_screen() -> Node:
	return _current


## Start a level (or the hub) for everyone. Host only when online.
func start_level(new_level_id: String) -> void:
	level_id = new_level_id
	goto_screen("game", {"level_id": new_level_id})


## Quit cleanly: stop all audio first and give Godot's audio thread a moment
## to release the playing sounds, so nothing is left "in use" at exit.
func quit_game(exit_code: int = 0) -> void:
	AudioManager.stop_all()
	await get_tree().process_frame
	await get_tree().process_frame
	OS.delay_msec(250)   # the audio thread keeps running while we wait
	await get_tree().process_frame
	get_tree().quit(exit_code)


func _notification(what: int) -> void:
	# Android lifecycle: the app was sent to the background / came back.
	if what == NOTIFICATION_APPLICATION_PAUSED:
		GameLog.info("App paused (backgrounded)")
		app_paused.emit(true)
		SaveData.save()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		GameLog.info("App resumed")
		app_paused.emit(false)
