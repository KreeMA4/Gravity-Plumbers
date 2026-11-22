extends TestCase
## Contextual interaction target scoring (scripts/character/interaction.gd).

const UP: Vector3 = Vector3.UP
const FROM: Vector3 = Vector3(0, 0.9, 0)
const LOOK: Vector3 = Vector3(0, 0, -1)


func s(target: Vector3) -> float:
	return Interaction.score_candidate(FROM, LOOK, target, UP, 1.9, 0.35)


func test_range() -> void:
	check(s(Vector3(0, 0.2, -1.2)) >= 0.0, "item 1.2 m ahead on the floor is a candidate")
	check(s(Vector3(0, 0.2, -2.5)) < 0.0, "item 2.5 m away is out of range")


func test_prefers_what_you_face() -> void:
	var ahead: float = s(Vector3(0, 0.2, -1.4))
	var side: float = s(Vector3(1.2, 0.2, -0.6))
	check(ahead > side, "an item straight ahead beats one off to the side")
	check(s(Vector3(0, 0.2, 1.2)) < 0.0, "an item behind you (not underfoot) is ignored")
	check(s(Vector3(0, 0.2, 0.3)) >= 0.0, "an item right at your feet still counts")


func test_prefers_closer_when_equally_in_front() -> void:
	check(s(Vector3(0, 0.2, -0.9)) > s(Vector3(0, 0.2, -1.7)), "closer item wins when both are ahead")


func test_works_on_walls() -> void:
	# Standing on a wall: "up" is +X, looking along -Z.
	var sc: float = Interaction.score_candidate(Vector3(0.9, 0, 0), LOOK, Vector3(0.2, 0, -1.2), Vector3.RIGHT, 1.9, 0.35)
	check(sc >= 0.0, "scoring uses the plumber's own up, so it works on walls and ceilings")


func test_prompt_text() -> void:
	var a: Interaction = Interaction.new()
	a.kind = Interaction.Kind.PICKUP
	a.verb = "PICK UP"
	a.item_name = "Plunger"
	check_eq(a.prompt_text(), "PICK UP  Plunger", "prompt reads verb + item")
	check(not a.is_none(), "a pickup is not 'none'")
	check(Interaction.new().is_none(), "default is no interaction")
