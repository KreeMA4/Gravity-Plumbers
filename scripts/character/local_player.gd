class_name LocalPlayer
extends Node
## Everything THIS device needs to control a plumber: the camera, the touch
## controls (on their own CanvasLayer), and the input collector.
## Used by the Ragdoll Playground and by LevelRunner.

var camera: PlumberCamera
var touch: TouchControls
var input: LocalInput
var ui_layer: CanvasLayer
var prompt: InteractPrompt
var plumber: Plumber = null
## What Interact would do right now (recomputed every frame for the prompt + button).
var interaction: Interaction = Interaction.new()


func _init() -> void:
	name = "LocalPlayer"
	camera = PlumberCamera.new()
	camera.name = "PlayerCamera"
	add_child(camera)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	touch = TouchControls.new()
	touch.name = "TouchControls"
	prompt = InteractPrompt.new()
	prompt.name = "InteractPrompt"
	ui_layer.add_child(prompt)      # under the touch controls (it ignores touches)
	ui_layer.add_child(touch)
	input = LocalInput.new()
	input.touch = touch
	input.camera = camera
	add_child(input)


func attach(p: Plumber) -> void:
	plumber = p
	camera.set_plumber(p)
	input.plumber = p
	if p != null and not p.impact.is_connected(_on_impact):
		p.impact.connect(_on_impact)


func set_blocked(on: bool) -> void:
	input.blocked = on
	touch.enabled = not on
	touch.visible = not on
	if on:
		touch.reset()


func _process(_delta: float) -> void:
	if plumber != null and is_instance_valid(plumber):
		touch.boots_lit = plumber.boots_on
		touch.use_enabled = plumber.can_use()
		touch.get_up_enabled = plumber.state == Plumber.State.RAGDOLL
		if input.blocked:
			interaction = Interaction.new()
		else:
			interaction = Interaction.find(plumber, camera.get_aim())
	else:
		interaction = Interaction.new()
	touch.interact_label = "" if interaction.is_none() else interaction.button_text()
	prompt.show_action(interaction, camera.cam)


func _on_impact(strength: float, _at: Vector3) -> void:
	# Hit-stop: a 40 ms freeze on really big hits sells the impact.
	if strength > 14.0 and SaveData.setting_b("hit_stop") and not NetManager.is_online() and Engine.time_scale > 0.9:
		Engine.time_scale = 0.05
		get_tree().create_timer(0.04, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)
	if strength > 6.0:
		camera.add_shake(clampf(strength / 20.0, 0.1, 0.6))
		if SaveData.setting_b("haptics") and OS.has_feature("mobile"):
			Input.vibrate_handheld(40)
