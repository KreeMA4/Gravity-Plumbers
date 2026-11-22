class_name Mats
extends RefCounted
## Shared, cached materials. Reusing one material per colour keeps draw calls
## and memory low. Always get materials from here instead of making new ones.

static var _cache: Dictionary = {}


## A flat, solid-colour material for level geometry and props.
static func solid(color: Color) -> Material:
	var key: String = "solid_" + color.to_html()
	if _cache.has(key):
		return _cache[key] as Material
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	_cache[key] = m
	return m


## A glowing, unshaded material (lamps, screens, sludge highlights).
static func glow(color: Color) -> Material:
	var key: String = "glow_" + color.to_html()
	if _cache.has(key):
		return _cache[key] as Material
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cache[key] = m
	return m


static func clear_cache() -> void:
	_cache.clear()
