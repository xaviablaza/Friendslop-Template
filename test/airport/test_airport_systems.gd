extends GutTest
## Focused scene-free contract tests; independent of concurrent core/presentation edits.
const Systems = preload("res://scripts/airport/airport_systems.gd")

class Fixture extends RefCounted:
	const BELT_SPEED = 0.065
	var bags: Dictionary = {}
	var players: Dictionary = {}
	var dog: Dictionary = {"location": "floor", "position": Vector3(0, 0.3, 1), "held_by": 0, "t": 0.0, "scanned": false, "alerts": 0, "alert_bag": -1, "bark_left": 0.0}
	var dog_goal = Vector3(0, 0.3, 1)
	var dog_scan_count = 0
	var belt_running = false
	var upgrades = {"kennel": 0}
	var last_event = ""
	var collision_query: Callable
	var rng = RandomNumberGenerator.new()
	func get_item(id: int) -> Dictionary:
		for bag in bags.values():
			for item in bag.items:
				if int(item.id) == id:
					return item
		return {}
	func bag_position(bag: Dictionary) -> Vector3:
		return bag.position
	func _valid_placement(extra: Variant) -> bool:
		return extra is Dictionary and extra.get("location", "") in ["belt", "floor", "table"] and extra.get("position", Vector3.ZERO) is Vector3

var sim
var systems

func before_each():
	sim = Fixture.new()
	sim.rng.seed = 9123
	systems = Systems.new()
	systems.initialize(sim)
	_player(7)

func _player(id: int, point: Vector3 = Vector3(0, 0.3, 1)) -> Dictionary:
	var player = {"held_kind": "", "held_id": -1, "position": point, "tool": 0}
	systems.ensure_player(player)
	sim.players[id] = player
	return player

func _bag(id: int, point: Vector3 = Vector3(0, 0.04, 1), mass: float = 28.0) -> Dictionary:
	var bag = {"id": id, "location": "floor", "position": point, "held_by": 0, "mass_kg": mass, "size": 0, "items": [], "velocity": Vector3.ZERO, "angular_velocity": Vector3.ZERO, "off_belt": true, "flight_age": 0.0, "last_thrower": 0, "category": "legal", "dog_alert": false}
	systems.ensure_bag(bag)
	sim.bags[id] = bag
	return bag

func _hold_bag(bag: Dictionary, id: int = 7):
	bag.location = "held"
	bag.held_by = id
	sim.players[id].held_kind = "bag"
	sim.players[id].held_id = bag.id

func _act(action: String, target: int = -1, extra: Variant = null, peer: int = 7) -> Variant:
	return systems.act(sim, peer, action, target, extra)

func _motion(sprint: bool, jump: bool = false) -> Dictionary:
	return {"moving": true, "sprinting": sprint, "crouching": false, "jump": jump}

func test_defaults_are_idempotent_and_unknown_actions_fall_through():
	sim.players[7].health = 42.0
	sim.dog.xp = 30
	systems.initialize(sim)
	assert_eq(sim.players[7].health, 42.0)
	assert_eq(sim.dog.xp, 30)
	assert_null(_act("unlock"))
	assert_null(systems.act(sim, 999, "movement", -1, _motion(true)))

func test_sprint_is_authoritative_expires_and_recovers():
	_act("movement", -1, _motion(true))
	systems.update(sim, 0.2)
	assert_almost_eq(sim.players[7].stamina, 96.2, 0.001)
	assert_true(sim.players[7].sprinting)
	systems.update(sim, 0.3)
	assert_false(sim.players[7].sprinting)
	var drained: float = sim.players[7].stamina
	systems.update(sim, 1.0)
	assert_gt(sim.players[7].stamina, drained)

func test_jump_spam_is_cooldown_limited_and_malformed_intent_rejected():
	_act("movement", -1, _motion(false, true))
	assert_eq(sim.players[7].stamina, 88.0)
	for i in range(8):
		_act("movement", -1, _motion(false, true))
	assert_eq(sim.players[7].stamina, 88.0)
	_act("movement", -1, {"moving": true, "sprinting": 9, "jump": false, "crouching": false})
	assert_false(sim.players[7].sprinting)
	sim.players[7].stamina = 1.0
	_act("movement", -1, _motion(true))
	systems.update(sim, 0.1)
	assert_eq(sim.players[7].stamina, 0.0)
	assert_false(sim.players[7].sprinting)
	assert_true(sim.players[7].exhausted)

func test_care_consumes_real_finite_portions_and_requires_proximity():
	_act("take_food")
	assert_eq(sim.players[7].food, 0)
	sim.players[7].position = systems.DOG_CARE_POINT
	for i in range(5):
		_act("take_food")
	assert_eq(sim.players[7].food, 3)
	_act("take_water")
	assert_eq(sim.players[7].water, 1)
	sim.dog.position = systems.DOG_CARE_POINT
	sim.dog.hunger = 80.0
	sim.dog.thirst = 90.0
	_act("feed_dog")
	_act("water_dog")
	assert_eq(sim.players[7].food, 2)
	assert_eq(sim.players[7].water, 0)
	assert_eq(sim.dog.hunger, 25.0)
	assert_eq(sim.dog.thirst, 35.0)
	_act("water_dog")
	assert_eq(sim.dog.thirst, 35.0)

func test_rest_reduces_need_growth_but_does_not_replace_food():
	sim.players[7].position = systems.DOG_CARE_POINT
	sim.dog.position = systems.DOG_CARE_POINT
	_act("rest_dog")
	systems.update_dog(sim, 2.0)
	assert_eq(sim.dog.mode, "stay")
	assert_gt(sim.dog.hunger, 15.0)
	assert_lt(sim.dog.hunger, 15.32)
	assert_eq(sim.dog.rest_left, 6.0)

func test_heavy_carry_waits_for_second_player_solo_drag_is_slow():
	var bag = _bag(1)
	_hold_bag(bag)
	assert_almost_eq(systems.carry_multiplier(sim, 7), 0.3, 0.001)
	_player(8)
	assert_eq(systems.carry_multiplier(sim, 7), 0.0)
	_act("join_carry", 1, null, 8)
	assert_eq(bag.carry_helpers, [8])
	assert_eq(sim.players[7].carry_partner, 8)
	assert_eq(sim.players[8].carry_partner, 7)
	assert_eq(sim.players[8].carry_bag, 1)
	assert_almost_eq(systems.carry_multiplier(sim, 7), 0.85, 0.001)
	assert_almost_eq(systems.carry_multiplier(sim, 8), 0.85 * (1.0 - 28.0 / 70.0), 0.001)
	assert_not_null(_act("pickup_item", 9, null, 8))

func test_helper_needs_empty_hands_proximity_and_distinct_identity():
	var bag = _bag(1)
	_hold_bag(bag)
	_player(8, Vector3(9, 0.3, 1))
	_act("join_carry", 1, null, 8)
	_act("join_carry", 1)
	assert_eq(bag.carry_helpers.size(), 0)
	sim.players[8].position = sim.players[7].position
	sim.players[8].held_kind = "dog"
	_act("join_carry", 1, null, 8)
	assert_eq(bag.carry_helpers.size(), 0)

func test_leave_disconnect_or_separation_releases_both_owners():
	for mode in ["leave", "disconnect", "separate"]:
		var bag = _bag(1)
		_hold_bag(bag)
		_player(8)
		_act("join_carry", 1, null, 8)
		match mode:
			"leave": _act("leave_carry", 1, null, 8)
			"disconnect": systems.remove_player(sim, 8)
			"separate":
				sim.players[8].position = Vector3(9, 0, 1)
				systems.update(sim, 0.01)
		assert_eq(bag.location, "floor", mode)
		assert_eq(bag.held_by, 0, mode)
		assert_eq(bag.carry_helpers, [], mode)
		assert_eq(sim.players[7].held_kind, "", mode)
		assert_eq(sim.players[8].carry_bag, -1, mode)
		assert_eq(sim.players[7].carry_partner, 0, mode)

func test_primary_disconnect_and_helper_drop_release_shared_carry():
	var bag = _bag(1)
	_hold_bag(bag)
	_player(8)
	_act("join_carry", 1, null, 8)
	systems.remove_player(sim, 7)
	assert_eq(bag.location, "floor")
	assert_eq(sim.players[8].carry_partner, 0)
	_hold_bag(bag)
	_act("join_carry", 1, null, 8)
	_act("place_bag", -1, {"location": "floor", "position": Vector3.ZERO}, 8)
	assert_eq(bag.location, "floor")
	assert_eq(sim.players[7].held_kind, "")

func test_physical_piles_separate_ground_bodies_and_support_a_real_stack():
	var lower = _bag(1)
	var upper = _bag(2, Vector3(0, 0.36, 1))
	upper.location = "airborne"
	upper.velocity = Vector3(0, -6, 0)
	systems.update(sim, 0.05)
	assert_eq(upper.location, "floor")
	assert_almost_eq(upper.position.y, lower.position.y + 0.48, 0.001)
	assert_gt(upper.damage, 0.0)
	sim.bags.erase(1)
	systems.update(sim, 0.2)
	assert_almost_eq(upper.position.y, 0.04, 0.001)
	var adjacent = _bag(3, upper.position)
	systems.update(sim, 0.05)
	var difference: Vector3 = adjacent.position - upper.position
	assert_true(absf(difference.x) >= 0.7 or absf(difference.z) >= 0.5)

func test_pile_support_keeps_room_surfaces_but_releases_removed_support():
	var bag = _bag(1, Vector3(2, 1.1, 0))
	sim.collision_query = func(from: Vector3, to: Vector3, _entity: Dictionary):
		if from.y >= 1.1 and to.y < 1.1:
			return {"position": Vector3(from.x, 1.1, from.z), "normal": Vector3.UP}
		return {}
	for index in range(60):
		systems.update(sim, 1.0 / 60.0)
	assert_almost_eq(bag.position.y, 1.1, 0.001)
	assert_eq(bag.location, "floor")
	var upper = _bag(2, Vector3(2, 1.58, 0))
	systems.update(sim, 0.1)
	assert_almost_eq(upper.position.y, 1.58, 0.001)
	sim.bags.erase(1)
	systems.update(sim, 1.0)
	assert_almost_eq(upper.position.y, 1.1, 0.001)
	sim.collision_query = Callable()
	systems.update(sim, 1.0)
	assert_almost_eq(upper.position.y, 0.04, 0.001)

func test_pile_side_contacts_bounce_incoming_bag_and_cause_damage():
	var still = _bag(1)
	var incoming = _bag(2, Vector3(0.6, 0.04, 1))
	incoming.location = "airborne"
	incoming.velocity = Vector3(-7, 0, 0)
	systems.update(sim, 0.01)
	assert_gt(incoming.velocity.x, 0.0)
	assert_gt(incoming.damage, 0.0)
	assert_gt(still.damage, 0.0)

func test_prop_sweep_prevents_wall_crossing_and_fast_item_injures():
	var bag = _bag(1)
	var item = {"id": 9, "location": "airborne", "held_by": 0, "position": Vector3(-1, 0.95, 1), "mass_kg": 2.0, "category": "legal", "velocity": Vector3(8, 0, 0), "flight_age": 1.0, "last_thrower": 0}
	bag.items.append(item)
	sim.collision_query = func(from: Vector3, to: Vector3, _entity: Dictionary):
		if from.x < 0.2 and to.x >= 0.2:
			return {"position": from.lerp(to, (0.2 - from.x) / (to.x - from.x)), "normal": Vector3.LEFT}
		return {}
	systems.update(sim, 0.4)
	assert_lt(sim.players[7].health, 100.0)
	assert_lt(item.position.x, 0.2)

func test_impacts_damage_bags_and_injure_players_first_aid_is_local():
	var bag = _bag(1, sim.players[7].position + Vector3.UP * 0.65)
	systems.impact(sim, bag, 8.0)
	assert_gt(bag.damage, 0.0)
	assert_lt(sim.players[7].health, 100.0)
	var hurt: float = sim.players[7].health
	_act("first_aid")
	assert_eq(sim.players[7].health, hurt)
	sim.players[7].position = systems.FIRST_AID_POINT
	_act("first_aid")
	assert_eq(sim.players[7].health, 100.0)
	assert_eq(sim.players[7].hurt_left, 0.0)

func test_item_throw_validates_ownership_and_host_strength_then_lands():
	var bag = _bag(1)
	var item = {"id": 9, "location": "held", "held_by": 7, "position": sim.players[7].position, "mass_kg": 2.0, "category": "legal"}
	bag.items.append(item)
	sim.players[7].held_kind = "item"
	sim.players[7].held_id = 9
	_act("throw_item", 9, {"origin": Vector3(9, 1, 1), "direction": Vector3.RIGHT})
	assert_eq(item.location, "held")
	_act("throw_item", 9, {"origin": Vector3(0, 1, 1), "direction": Vector3.RIGHT, "velocity": Vector3.ONE * 999})
	assert_eq(item.location, "airborne")
	assert_eq(item.velocity, Vector3(6.5, 2.6, 0))
	assert_eq(sim.players[7].held_kind, "")
	systems.update(sim, 2.0)
	assert_eq(item.location, "floor")
	assert_eq(item.velocity, Vector3.ZERO)
	assert_almost_eq(item.position.y, 0.04, 0.001)

func test_cartoon_dog_toss_is_capped_and_harmless():
	sim.players[7].held_kind = "dog"
	sim.dog.location = "held"
	sim.dog.held_by = 7
	_act("throw_dog", -1, {"origin": Vector3(0, 1, 1), "direction": Vector3.UP})
	assert_eq(sim.dog.location, "airborne")
	assert_eq(sim.dog.velocity, Vector3(0, 2.8, 0))
	assert_eq(sim.players[7].held_kind, "")
	systems.update_dog(sim, 2.0)
	assert_eq(sim.dog.location, "floor")
	assert_almost_eq(sim.dog.position.y, 0.3, 0.001)
	assert_eq(sim.players[7].health, 100.0)
	assert_false(sim.dog.has("health"))

func test_scan_awards_training_once_per_scan_and_can_be_repeated():
	sim.belt_running = true
	sim.dog.location = "belt"
	sim.dog.t = 0.44
	systems.update_dog(sim, 0.2)
	assert_true(sim.dog.scanned)
	assert_eq(sim.dog.xp, 10)
	assert_eq(sim.dog_scan_count, 1)
	systems.update_dog(sim, 0.2)
	assert_eq(sim.dog.xp, 10)
	sim.dog.scanned = false # Core's place_dog begins a new scan.
	sim.dog.t = 0.44
	systems.update_dog(sim, 0.2)
	assert_eq(sim.dog.xp, 20)
	assert_eq(sim.dog_scan_count, 2)

func test_follow_patrol_and_sweeps_never_cross_obstacles():
	_act("dog_mode", -1, "follow")
	sim.players[7].position = Vector3(4, 0.3, 1)
	var start: Vector3 = sim.dog.position
	systems.update_dog(sim, 0.1)
	assert_gt(sim.dog.position.x, start.x)
	start = sim.dog.position
	sim.collision_query = func(from: Vector3, to: Vector3, _entity: Dictionary):
		return {"position": from.lerp(to, 0.5), "normal": (from - to).normalized()}
	systems.update_dog(sim, 0.1)
	assert_eq(sim.dog.position, start)
	_act("dog_mode", -1, "patrol")
	var old_index: int = sim.dog.patrol_index
	systems.update_dog(sim, 0.1)
	assert_ne(sim.dog.patrol_index, old_index)
	systems.remove_player(sim, 7)
	assert_eq(sim.dog.follow_peer, 0)

func _scent_count(category: String, need: float, xp: int, kennel: int) -> int:
	sim.bags.clear()
	sim.rng.seed = 9917
	sim.dog.xp = xp
	sim.dog.hunger = need
	sim.dog.thirst = need
	sim.dog.location = "floor"
	sim.dog.mode = "stay"
	sim.upgrades.kennel = kennel
	var count = 0
	for i in range(300):
		var bag = _bag(1, sim.dog.position)
		bag.category = category
		sim.dog.scent_left = 0.0
		systems.update_dog(sim, 0.0)
		if bag.dog_alert:
			count += 1
	return count

func test_seeded_scent_has_true_false_positives_and_care_training_effects():
	var poor_true = _scent_count("narcotics", 100.0, 0, 0)
	var trained_true = _scent_count("narcotics", 0.0, 100, 1)
	var poor_false = _scent_count("legal", 100.0, 0, 0)
	var trained_false = _scent_count("legal", 0.0, 100, 1)
	assert_gt(poor_true, 0)
	assert_lt(poor_true, 300)
	assert_gt(trained_true, poor_true)
	assert_gt(poor_false, 0)
	assert_lt(trained_false, poor_false)
	assert_eq(_scent_count("narcotics", 0.0, 100, 1), trained_true)

func test_core_snapshot_roundtrips_shared_carry_and_airborne_dog():
	var core_script = load("res://scripts/airport/airport_simulation.gd")
	var host = core_script.new()
	host.set_seed(776)
	host.add_player(7)
	host.add_player(8)
	host.update(0.0)
	host.belt_running = false
	var bag: Dictionary = host.bags[1]
	# Heavy shell plus current contents, keeping the additive mass invariant.
	bag.shell_mass_kg = 28.0
	host.ensure_bag_physics(bag)
	host.act(7, "pickup_bag", 1)
	host.act(8, "join_carry", 1)
	assert_eq(bag.carry_helpers, [8])
	var restored = core_script.new()
	restored.apply_snapshot(host.snapshot())
	assert_eq(restored.players.size(), 2)
	assert_eq(restored.bags[1].carry_helpers, [8])
	host.act(8, "leave_carry", 1)
	host.act(7, "pickup_dog")
	host.act(7, "throw_dog", -1, {"origin": Vector3(0, 1, 0), "direction": Vector3.FORWARD})
	assert_eq(host.dog.location, "airborne")
	restored.apply_snapshot(host.snapshot())
	assert_eq(restored.dog.location, "airborne")
	assert_eq(restored.dog.velocity, host.dog.velocity)
	host.update(0.2)
	restored.update(0.2)
	assert_eq(restored.dog.position, host.dog.position)

func test_core_route_cleans_shared_links_before_snapshot():
	var core_script = load("res://scripts/airport/airport_simulation.gd")
	var host = core_script.new()
	host.set_seed(777)
	host.add_player(7)
	host.add_player(8)
	host.update(0.0)
	host.belt_running = false
	var bag: Dictionary = host.bags[1]
	bag.shell_mass_kg = 28.0
	host.ensure_bag_physics(bag)
	bag.scanned = true
	bag.opened = true
	bag.inspected = true
	bag.unlocked = true
	if bag.carrier:
		bag.pet.fed = true
		bag.pet.hunger = 0.0
		bag.pet.thirst = 0.0
	host.act(7, "pickup_bag", 1)
	host.act(8, "join_carry", 1)
	assert_eq(bag.carry_helpers, [8])
	host.act(7, "route", 1, host.expected_route(bag))
	assert_eq(bag.location, "sorted")
	assert_eq(bag.carry_helpers, [])
	assert_eq(host.players[7].carry_partner, 0)
	assert_eq(host.players[8].carry_bag, -1)
	var restored = core_script.new()
	restored.apply_snapshot(host.snapshot())
	assert_eq(restored.handled, 1)
	assert_eq(restored.players.size(), 2)

func test_dictionary_copy_continues_care_and_intent_without_helper_state():
	_act("movement", -1, _motion(true))
	sim.dog.hunger = 45.0
	var restored = Fixture.new()
	restored.players = sim.players.duplicate(true)
	restored.dog = sim.dog.duplicate(true)
	var second = Systems.new()
	second.initialize(restored)
	systems.update(sim, 0.1)
	second.update(restored, 0.1)
	assert_eq(restored.players[7], sim.players[7])
	second.update_dog(restored, 0.1)
	systems.update_dog(sim, 0.1)
	assert_eq(restored.dog.hunger, sim.dog.hunger)
