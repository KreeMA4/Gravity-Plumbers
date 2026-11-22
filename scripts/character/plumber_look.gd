class_name PlumberLook
extends Resource
## A plumber's appearance in ~19 bytes. Sent over the network on join, saved
## in user://save.json, and turned into meshes by PlumberMeshBuilder.
## Every value is an index into the option tables below; from_bytes() clamps
## everything because network clients are untrusted.

const VERSION: int = 1

## Option tables: category -> list of option names (index = stored value).
const OPTIONS: Dictionary = {
	"build": ["Short & Round", "Tall & Lanky", "Big & Beefy", "Tiny", "Pear", "Bean"],
	"eyes": ["Googly", "Sleepy", "Angry Brow", "Tiny Dots", "Huge", "Cyclops"],
	"expression": ["Cheerful", "Grumpy", "Goofy", "Shy"],
	"nose": ["Round", "Long", "Button", "Potato", "Pointy", "None"],
	"mustache": ["Handlebar", "Walrus", "Pencil", "Curly", "Fluffy", "None"],
	"brows": ["Bushy", "Thin", "Angry", "Unibrow", "Raised", "None"],
	"headgear": ["Cap + Lamp", "Bucket", "Fishbowl", "Plunger Hat", "Hard Hat", "Visor", "Antenna Beanie", "Chef Hat", "None"],
	"backpack": ["Air Tank", "Pipe Bundle", "Toolbox", "Jet Nozzle", "Duck Float", "None"],
	"pattern": ["Plain", "Stripes", "Patches", "Polka Dots", "Hazard", "Stars"],
	"boots": ["Chunky Rubber", "Rocket", "Tiny", "Socks Only", "Flippers", "High Tops"],
	"gloves": ["Chunky Rubber", "Mittens", "Tiny", "Bare Hands", "Oven Mitts", "Boxing"],
	"tag": ["Yellow", "Teal", "Pink", "Orange", "Lime", "Purple", "White", "Red"],
	"emote": ["Dance", "Wave", "Flex", "Cry", "Point"],
	"voice": ["Very Low", "Low", "Lowish", "Normal", "Bright", "High", "Squeaky", "Chipmunk"],
}

## Colour slots. Each stores an index into SWATCHES.
const COLOR_SLOTS: Array = ["skin", "overalls", "gloves_col", "boots_col", "accent"]

## Hand-picked swatches (no ugly random HSV).
const SWATCHES: Array = [
	Color(1.0, 0.82, 0.66), Color(0.93, 0.68, 0.5), Color(0.72, 0.48, 0.32), Color(0.48, 0.3, 0.2),
	Color(0.55, 0.85, 0.6), Color(0.6, 0.75, 1.0),
	Color(0.2, 0.45, 0.85), Color(0.85, 0.2, 0.25), Color(0.15, 0.62, 0.55), Color(0.95, 0.55, 0.15),
	Color(0.5, 0.3, 0.75), Color(0.95, 0.8, 0.2), Color(0.3, 0.3, 0.38), Color(0.95, 0.95, 0.97),
	Color(1.0, 0.45, 0.65), Color(0.45, 0.8, 0.25),
]
## Which swatches suit each slot (skin tones first for skin, etc.).
const SLOT_SWATCHES: Dictionary = {
	"skin": [0, 1, 2, 3, 4, 5],
	"overalls": [6, 7, 8, 9, 10, 11, 12, 14, 15],
	"gloves_col": [13, 11, 7, 6, 12, 9, 15],
	"boots_col": [12, 3, 7, 6, 11, 9, 13],
	"accent": [11, 9, 14, 8, 15, 13, 7, 10],
}
## Curated harmonious sets: [skin, overalls, gloves, boots, accent] swatch indices.
const PALETTES: Array = [
	[0, 6, 13, 12, 11], [1, 7, 13, 3, 11], [2, 8, 11, 12, 9], [3, 9, 13, 12, 8],
	[0, 10, 11, 12, 14], [1, 12, 9, 3, 11], [4, 11, 7, 6, 14], [5, 14, 13, 10, 15],
	[2, 15, 13, 12, 10], [0, 7, 11, 6, 13],
]

## Locked items: category -> {option index: golden ducks needed}. 60%+ unlocked at start.
const LOCKS: Dictionary = {
	"headgear": {2: 1, 6: 3, 7: 5},
	"backpack": {3: 2, 4: 4},
	"pattern": {4: 2, 5: 4},
	"boots": {1: 3, 4: 6},
	"gloves": {4: 2, 5: 5},
	"eyes": {5: 3},
	"mustache": {3: 1},
}

## The byte order of every field (after the version byte).
const FIELDS: Array = ["build", "skin", "overalls", "gloves_col", "boots_col", "accent",
	"eyes", "expression", "nose", "mustache", "brows", "headgear", "backpack", "pattern",
	"boots", "gloves", "tag", "emote", "voice"]

## Categories shown in the customise screen, and which fields each one controls.
const CATEGORIES: Dictionary = {
	"build": ["build"],
	"colors": ["skin", "overalls", "gloves_col", "boots_col", "accent"],
	"face": ["eyes", "expression", "nose", "mustache", "brows"],
	"headgear": ["headgear"],
	"backpack": ["backpack"],
	"pattern": ["pattern"],
	"boots": ["boots", "gloves"],
	"extras": ["tag", "emote", "voice"],
}

var values: Dictionary = {}


func _init() -> void:
	for f: String in FIELDS:
		values[f] = 0
	values["mustache"] = 0
	values["voice"] = 3
	values["skin"] = 0
	values["overalls"] = 6
	values["gloves_col"] = 13
	values["boots_col"] = 12
	values["accent"] = 11


func get_v(field: String) -> int:
	return int(values.get(field, 0))


func set_v(field: String, v: int) -> void:
	values[field] = clampi(v, 0, max_value(field))


## Largest allowed value for a field.
static func max_value(field: String) -> int:
	if COLOR_SLOTS.has(field):
		return SWATCHES.size() - 1
	var opts: Array = OPTIONS.get(field, [])
	return maxi(0, opts.size() - 1)


func color(slot: String) -> Color:
	return SWATCHES[clampi(get_v(slot), 0, SWATCHES.size() - 1)] as Color


## Voice pitch multiplier for the blip voice.
func voice_pitch() -> float:
	return 0.6 + float(get_v("voice")) * 0.14


func to_bytes() -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	b.append(VERSION)
	for f: String in FIELDS:
		b.append(clampi(get_v(f), 0, 255))
	return b


## Build a look from bytes. Unknown/garbage values are clamped to valid ranges.
static func from_bytes(b: PackedByteArray) -> PlumberLook:
	var look: PlumberLook = PlumberLook.new()
	if b.size() < 2:
		return look
	for i: int in FIELDS.size():
		if i + 1 >= b.size():
			break
		var f: String = FIELDS[i]
		look.values[f] = clampi(int(b[i + 1]), 0, max_value(f))
	return look


func duplicate_look() -> PlumberLook:
	return from_bytes(to_bytes())


func equals(other: PlumberLook) -> bool:
	return other != null and to_bytes() == other.to_bytes()


## Is this option available with `ducks` golden ducks collected?
static func is_unlocked(field: String, option: int, ducks: int) -> bool:
	var locks: Dictionary = LOCKS.get(field, {})
	if not locks.has(option):
		return true
	return ducks >= int(locks[option])


static func ducks_needed(field: String, option: int) -> int:
	var locks: Dictionary = LOCKS.get(field, {})
	return int(locks.get(option, 0))


## Replace locked choices with option 0 (host-side validation).
func enforce_unlocks(ducks: int) -> void:
	for f: String in FIELDS:
		if not is_unlocked(f, get_v(f), ducks):
			values[f] = 0


## Randomise everything except categories in `locked_categories`.
## colors_only = only the colour slots. Respects unlocks.
func randomize_look(rng: RandomNumberGenerator, locked_categories: Array, ducks: int, colors_only: bool = false) -> void:
	for cat: String in CATEGORIES.keys():
		if locked_categories.has(cat):
			continue
		if colors_only and cat != "colors":
			continue
		if cat == "colors":
			var pal: Array = PALETTES[rng.randi_range(0, PALETTES.size() - 1)]
			for i: int in COLOR_SLOTS.size():
				values[COLOR_SLOTS[i]] = int(pal[i])
			# Occasionally swap one slot for another suitable swatch for variety.
			if rng.randf() < 0.5:
				var slot: String = COLOR_SLOTS[rng.randi_range(1, COLOR_SLOTS.size() - 1)]
				var choices: Array = SLOT_SWATCHES[slot]
				values[slot] = int(choices[rng.randi_range(0, choices.size() - 1)])
			continue
		for f: Variant in CATEGORIES[cat]:
			var field: String = str(f)
			var allowed: Array = []
			for i: int in max_value(field) + 1:
				if is_unlocked(field, i, ducks):
					allowed.append(i)
			if allowed.size() > 0:
				values[field] = int(allowed[rng.randi_range(0, allowed.size() - 1)])


## A nice default look for player n (so 4 friends don't all look the same).
static func default_for(n: int) -> PlumberLook:
	var look: PlumberLook = PlumberLook.new()
	var pal: Array = PALETTES[n % PALETTES.size()]
	for i: int in COLOR_SLOTS.size():
		look.values[COLOR_SLOTS[i]] = int(pal[i])
	look.values["build"] = n % 6
	look.values["headgear"] = [0, 4, 1, 3][n % 4]
	look.values["mustache"] = [0, 1, 4, 2][n % 4]
	look.values["tag"] = n % 8
	look.values["voice"] = [3, 1, 5, 2][n % 4]
	return look


## Body build scale factors: [height, width, limb thickness, head size].
static func build_scales(build: int) -> Vector4:
	match build:
		0: return Vector4(0.95, 1.12, 1.05, 1.0)   # short & round
		1: return Vector4(1.12, 0.9, 0.9, 0.95)    # tall & lanky
		2: return Vector4(1.05, 1.18, 1.2, 1.0)    # big & beefy
		3: return Vector4(0.85, 0.9, 0.9, 1.1)     # tiny
		4: return Vector4(0.98, 1.08, 1.0, 0.92)   # pear
		5: return Vector4(1.0, 0.96, 0.95, 1.05)   # bean
	return Vector4(1, 1, 1, 1)
