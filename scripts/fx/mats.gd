class_name Mats
extends RefCounted
## Shared, cached materials. Reusing one material per colour keeps draw calls
## and memory low, so always get materials from here instead of making new ones.
##
##   Mats.toon(color)               flat cel-shaded colour (levels, props)
##   Mats.toon(color, true)         ...plus the inverted-hull outline pass
##   Mats.glow(color)               unshaded bright colour (lamps, screens)
##   Mats.goo()                     wobbly sludge
##   Mats.blob_shadow()             soft round shadow decal

const TOON: Shader = preload("res://shaders/toon.gdshader")
const OUTLINE: Shader = preload("res://shaders/outline.gdshader")
const GOO: Shader = preload("res://shaders/goo.gdshader")
const BLOB: Shader = preload("res://shaders/blob_shadow.gdshader")
const SKY: Shader = preload("res://shaders/starfield.gdshader")

static var _cache: Dictionary = {}


## Cel-shaded material. `outline` adds a dark outline pass; `outline_px`
## is the outline thickness in metres.
static func toon(color: Color, outline: bool = false, outline_px: float = 0.025, rim: float = 0.3) -> Material:
	var key: String = "toon_%s_%s_%.3f_%.2f" % [color.to_html(), str(outline), outline_px, rim]
	if _cache.has(key):
		return _cache[key] as Material
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("rim_strength", rim)
	if outline:
		m.next_pass = outline_pass(outline_px)
	_cache[key] = m
	return m


## A toon material that glows a little (for interactive things like switches).
static func toon_glow(color: Color, amount: float = 0.35, outline: bool = true) -> Material:
	var key: String = "toonglow_%s_%.2f_%s" % [color.to_html(), amount, str(outline)]
	if _cache.has(key):
		return _cache[key] as Material
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission_amount", amount)
	if outline:
		m.next_pass = outline_pass(0.025)
	_cache[key] = m
	return m


static func outline_pass(thickness: float) -> Material:
	var key: String = "outline_%.3f" % thickness
	if _cache.has(key):
		return _cache[key] as Material
	var o: ShaderMaterial = ShaderMaterial.new()
	o.shader = OUTLINE
	o.set_shader_parameter("thickness", thickness)
	_cache[key] = o
	return o


## Level surfaces (floors, walls, ceilings): toon shading without the rim
## highlight, plus a world-space pattern so big surfaces read as materials
## (1 = floor tiles with grout and a soft checker, 2 = wall panels with seams).
static func surface(color: Color, pattern: int = 0, scale: float = 1.0, strength: float = 0.14) -> Material:
	var key: String = "surf_%s_%d_%.2f_%.2f" % [color.to_html(), pattern, scale, strength]
	if _cache.has(key):
		return _cache[key] as Material
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("rim_strength", 0.0)
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("pattern_scale", scale)
	m.set_shader_parameter("pattern_strength", strength)
	_cache[key] = m
	return m


## Plain solid colour (kept for simple debug geometry). Uses the toon look.
static func solid(color: Color) -> Material:
	return toon(color)


## Unshaded glowing colour.
static func glow(color: Color) -> Material:
	var key: String = "glow_" + color.to_html()
	if _cache.has(key):
		return _cache[key] as Material
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = m
	return m


## See-through glass for windows.
static func glass() -> Material:
	if _cache.has("glass"):
		return _cache["glass"] as Material
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.85, 1.0, 0.12)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["glass"] = m
	return m


static func goo() -> Material:
	if _cache.has("goo"):
		return _cache["goo"] as Material
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = GOO
	_cache["goo"] = m
	return m


static func blob_shadow() -> Material:
	if _cache.has("blob"):
		return _cache["blob"] as Material
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = BLOB
	_cache["blob"] = m
	return m


## The space sky material (one per level so its storm tint can animate).
static func new_sky_material() -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SKY
	return m


static func clear_cache() -> void:
	_cache.clear()
