class_name AirportSimulation
extends RefCounted
## Seedable, scene-free, host-owned state. The scene supplies proximity checks.
## Scanner is a fictional non-ionizing training device, including the dog gag.

const SHIFT_SECONDS: float = 240.0
const BELT_SPEED: float = 0.065
const UPGRADE_COSTS: Dictionary = {"scanner": 45, "kennel": 35, "evidence": 30, "bio_lab": 70, "belt": 55, "terminal": 120}
const ROUTES: Array = ["gate_a", "gate_b", "gate_c", "oversize", "security", "bio", "rescue"]
const Catalog = preload("res://scripts/airport/airport_catalog.gd")
const CATEGORIES: Array = Catalog.CATEGORIES
const STATE_FIELDS: Array = ["money", "reputation", "handled", "correct", "mistakes", "organics", "narcotics", "rescues", "legals", "items_seized", "airport_level", "day", "time_left", "shift_finished", "belt_running", "arrival_interval", "last_event", "upgrades", "contracts", "dog_scan_count", "dog", "dog_goal", "_next_bag_id", "_next_item_id", "_arrival_left", "_terminal_arrival", "throws", "landings", "catches", "throw_events", "catch_events", "landing_events"]
const FLIGHT_STEP: float = 1.0 / 120.0
const BAG_FLOOR: float = 0.04
const GRAVITY: float = 9.81
const RESTITUTION: float = 0.2
const EVENT_LIMIT: int = 64

var bags: Dictionary = {}
var players: Dictionary = {}
var money: int = 0
var reputation: int = 0
var handled: int = 0
var correct: int = 0
var mistakes: int = 0
var organics: int = 0
var narcotics: int = 0
var rescues: int = 0
var legals: int = 0
var items_seized: int = 0
var airport_level: int = 1
var day: int = 1
var time_left: float = SHIFT_SECONDS
var shift_finished: bool = false
var belt_running: bool = true
var arrival_interval: float = 10.0
var last_event: String = "Airport open. Inspect, then route baggage."
var upgrades: Dictionary = {"scanner": 0, "kennel": 0, "evidence": 0, "bio_lab": 0, "belt": 0, "terminal": 0}
var contracts: Dictionary = {"legal": false, "organic": false, "rescue": false}
var dog_scan_count: int = 0
var dog: Dictionary = {"location": "floor", "position": Vector3(0, 0.3, 0), "held_by": 0, "t": 0.0, "scanned": false, "alerts": 0, "alert_bag": -1, "bark_left": 0.0}
var dog_goal: Vector3 = Vector3(0, 0.3, 0)
var _next_bag_id: int = 1
var _next_item_id: int = 1
var _arrival_left: float = 0.0
var _terminal_arrival: bool = false
var throws: int = 0
var landings: int = 0
var catches: int = 0
var throw_events: Array[Dictionary] = []
var catch_events: Array[Dictionary] = []
var landing_events: Array[Dictionary] = []
## Host scene supplies a bag-base sweep; never part of a network snapshot.
var collision_query: Callable
var systems = preload("res://scripts/airport/airport_systems.gd").new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Explicit opt-in fixtures for old harnesses; production arrivals are random.
var fixture_mode: bool = false

func _init() -> void:
	rng.randomize()
	dog.last_thrower = 0
	systems.initialize(self)

func set_seed(value: int) -> void:
	rng.seed = value

func set_fixture_mode(enabled: bool = true) -> void:
	fixture_mode = enabled
	if enabled:
		set_seed(1)

func _ensure_core_player(player: Dictionary) -> void:
	var defaults: Dictionary = {"key_durability": 8, "pliers_durability": 5, "seals": 3, "food": 2, "water": 2, "lock_game": {}}
	for field in defaults:
		if not player.has(field):
			player[field] = defaults[field].duplicate(true) if defaults[field] is Dictionary else defaults[field]
	systems.ensure_player(player)

func add_player(peer_id: int) -> void:
	if peer_id > 0 and not players.has(peer_id):
		players[peer_id] = {"held_kind": "", "held_id": -1, "tool": 0, "position": Vector3.ZERO}
		_ensure_core_player(players[peer_id])

func set_player_position(peer_id: int, position: Vector3) -> void:
	if players.has(peer_id) and position.is_finite():
		players[peer_id].position = position
		_sync_held(players[peer_id])

func remove_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	systems.remove_player(self, peer_id)
	var player: Dictionary = players[peer_id]
	var entity: Dictionary = _held_entity(player)
	if not entity.is_empty():
		entity.location = "floor"
		entity.position = player.position
		entity.held_by = 0
		if player.held_kind == "bag":
			ensure_bag_physics(entity)
			_stop_bag(entity)
			entity.off_belt = true
		if player.held_kind == "dog":
			dog_goal = player.position
	players.erase(peer_id)

func _held_entity(player: Dictionary) -> Dictionary:
	match player.held_kind:
		"bag": return bags.get(int(player.held_id), {})
		"item": return get_item(int(player.held_id))
		"dog": return dog
	return {}

func _sync_held(player: Dictionary) -> void:
	var entity: Dictionary = _held_entity(player)
	if not entity.is_empty():
		entity.position = player.position

func _clear_hands(player: Dictionary) -> void:
	player.held_kind = ""
	player.held_id = -1

func _hold(player: Dictionary, peer_id: int, kind: String, id: int, entity: Dictionary) -> void:
	if kind == "bag":
		ensure_bag_physics(entity)
		_stop_bag(entity)
		entity.off_belt = true
	player.held_kind = kind
	player.held_id = id
	entity.location = "held"
	entity.held_by = peer_id
	entity.position = player.position

func _accessible(bag: Dictionary, peer_id: int) -> bool:
	return not bag.is_empty() and bag.location not in ["sorted", "airborne"] and (bag.location != "held" or int(bag.held_by) == peer_id)

func _feedback(message: String) -> String:
	last_event = message
	return message

func act(peer_id: int, action: String, target_id: int = -1, extra: Variant = null) -> String:
	if not players.has(peer_id):
		return _feedback("Join the airport before acting.")
	if shift_finished:
		return _feedback("Shift finished. Start the next shift.")
	var handled_action: Variant = systems.act(self, peer_id, action, target_id, extra)
	var result: String = _core_act(peer_id, action, target_id, extra) if handled_action == null else str(handled_action)
	for entry in bags.values():
		_refresh_mass(entry)
	return _feedback(result)

func _core_act(peer_id: int, action: String, target_id: int = -1, extra: Variant = null) -> String:
	if not players.has(peer_id):
		return _feedback("Join the airport before acting.")
	if shift_finished:
		return _feedback("Shift finished. Start the next shift.")
	var player: Dictionary = players[peer_id]
	var bag: Dictionary = bags.get(target_id, {})
	match action:
		"toggle_belt":
			belt_running = not belt_running
			return _feedback("Intake resumed." if belt_running else "Intake paused for inspection.")
		"tool":
			if typeof(extra) != TYPE_INT or extra < 0 or extra > 2:
				return _feedback("Choose hands, approved key, or pliers.")
			player.tool = extra
			return _feedback(["Hands selected.", "Approved key selected.", "Pliers selected."][extra])
		"pickup_bag":
			if player.held_kind != "" or bag.is_empty() or bag.location in ["held", "sorted", "airborne"]:
				return _feedback("Need empty hands and an available bag.")
			_hold(player, peer_id, "bag", target_id, bag)
			return _feedback("Carrying bag %d." % target_id)
		"throw_bag":
			return _throw_bag(player, peer_id, target_id, extra)
		"catch_bag":
			return _catch_bag(player, peer_id, bag)
		"place_bag":
			if player.held_kind != "bag" or not _valid_placement(extra):
				return _feedback("Choose a valid belt, table, or floor placement.")
			var held: Dictionary = bags[int(player.held_id)]
			if extra.location == "belt" and not _belt_space(float(extra.get("t", 0.0)), held.id):
				return _feedback("Belt queue full; place the bag on the floor or table.")
			_place(held, extra, player.position)
			_clear_hands(player)
			return _feedback("Bag placed on %s." % held.location)
		"unlock":
			return _start_lock(player, bag, peer_id)
		"lock_input":
			return _lock_input(player, peer_id, extra)
		"close":
			if not _accessible(bag, peer_id) or not bag.opened:
				return _feedback("Open an available bag first.")
			bag.opened = false
			return _feedback("Bag closed; use a seal to relock it.")
		"relock":
			if not _accessible(bag, peer_id) or bag.opened or not bag.unlocked:
				return _feedback("Close an unlocked bag before relocking.")
			if player.seals <= 0:
				return _feedback("No seals left. Restock at the tool station.")
			player.seals -= 1
			bag.lock = "approved"
			bag.unlocked = false
			return _feedback("Bag resealed and relocked.")
		"restock_tools":
			if money < 12:
				return _feedback("Tool restock costs $12.")
			money -= 12
			player.key_durability = 8
			player.pliers_durability = 5
			player.seals = 3
			return _feedback("Key, pliers, and three seals restocked. -$12")
		"feed_pet":
			return _feed_pet(player, bag, peer_id)
		"dispose_item":
			return _dispose_item(player)
		"open":
			if not _accessible(bag, peer_id) or not bag.unlocked:
				return _feedback("Unlock an available bag first.")
			bag.opened = true
			bag.inspected = true
			return _feedback("Bag opened for inspection.")
		"take_item":
			if player.held_kind != "" or not _accessible(bag, peer_id) or not bag.opened:
				return _feedback("Open the bag and use empty hands.")
			if typeof(extra) != TYPE_INT or extra < 0 or extra >= bag.items.size():
				return _feedback("Choose an item in the bag.")
			var item: Dictionary = bag.items[extra]
			if item.category in ["safeguarding", "pet", "wildlife"]:
				return _feedback("Keep animals safely in their carrier and route to animal care.")
			if item.location != "bag" or item.deposited:
				return _feedback("Item already removed.")
			_hold(player, peer_id, "item", item.id, item)
			return _feedback("Carrying %s." % item.label)
		"pickup_item":
			var item: Dictionary = get_item(target_id)
			if player.held_kind != "" or item.is_empty() or item.location != "floor" or item.deposited or item.category in ["safeguarding", "pet", "wildlife"]:
				return _feedback("Need empty hands and an available floor item.")
			_hold(player, peer_id, "item", target_id, item)
			return _feedback("Item picked up.")
		"drop_item":
			if player.held_kind != "item" or not _valid_position(extra):
				return _feedback("Choose a valid floor position for a held item.")
			var item: Dictionary = get_item(player.held_id)
			item.location = "floor"
			item.position = extra
			item.held_by = 0
			_clear_hands(player)
			return _feedback("Item placed on floor.")
		"return_item":
			if player.held_kind != "item" or not _accessible(bag, peer_id) or not bag.opened:
				return _feedback("Return a held item to any available open bag.")
			var item: Dictionary = get_item(player.held_id)
			if item.is_empty():
				return _feedback("Held item unavailable.")
			for source in bags.values():
				for index in range(source.items.size() - 1, -1, -1):
					if int(source.items[index].id) == int(item.id):
						source.items.remove_at(index)
			bag.items.append(item)
			item.location = "bag"
			item.position = bag_position(bag)
			item.held_by = 0
			_clear_hands(player)
			return _feedback("Item repacked into bag %d." % bag.id)
		"seize_item":
			if player.held_kind != "item":
				return _feedback("Carry a restricted item to evidence first.")
			var item: Dictionary = get_item(player.held_id)
			if item.category not in ["narcotics", "organic", "customs"] or item.deposited:
				return _feedback("Legal belongings are not contraband; do not seize them.")
			item.location = "evidence"
			item.deposited = true
			item.held_by = 0
			var bonus: int = 16 if upgrades.evidence > 0 else 8
			money += bonus
			items_seized += 1
			_clear_hands(player)
			return _feedback("Evidence secured. +$%d" % bonus)
		"route":
			if typeof(extra) != TYPE_STRING or extra not in ROUTES:
				return _feedback("Choose a valid route.")
			if bag.is_empty() or player.held_kind != "bag" or int(player.held_id) != target_id or int(bag.held_by) != peer_id:
				return _feedback("Carry this bag to its route.")
			if not bag.scanned:
				return _feedback("Scan the bag before routing.")
			if bag.category != "legal" and not bag.inspected:
				return _feedback("Open restricted baggage and inspect before routing.")
			if bag.carrier and (not bag.pet.fed or bag.pet.hunger >= 50.0 or bag.pet.thirst >= 50.0):
				return _feedback("Feed and water the animal before routing to animal care.")
			if extra != expected_route(bag):
				money = maxi(0, money - 10)
				reputation -= 1
				mistakes += 1
				return _feedback("Wrong route. -$10; bag stays in your hands. Dog alerts are not convictions.")
			return _finish_bag(bag, player)
		"call_dog":
			if dog.location != "floor" or not _valid_position(extra):
				return _feedback("Call the dog to a valid floor position.")
			dog_goal = extra
			return _feedback("Dog called. Alerts guide inspection, not conviction.")
		"pickup_dog":
			if player.held_kind != "" or dog.location not in ["floor", "belt"]:
				return _feedback("Need empty hands and an available dog.")
			_hold(player, peer_id, "dog", -1, dog)
			return _feedback("Carrying a very good dog.")
		"place_dog":
			if player.held_kind != "dog" or not _valid_placement(extra, true):
				return _feedback("Place a held dog on the floor or training belt.")
			_place(dog, extra, player.position)
			dog.scanned = false
			dog_goal = dog.position
			_clear_hands(player)
			return _feedback("Dog placed safely. Scanner is fictional and non-ionizing.")
		"upgrade_scanner", "upgrade_kennel", "upgrade_evidence", "upgrade_bio_lab", "upgrade_belt", "upgrade_terminal":
			return _buy_upgrade(action.trim_prefix("upgrade_"))
	return _feedback("Unknown airport action.")

## Migration helper for scene-free fixtures; snapshots themselves remain strict.
func ensure_bag_physics(bag: Dictionary) -> void:
	var defaults: Dictionary = {"velocity": Vector3.ZERO, "rotation": Vector3.ZERO, "angular_velocity": Vector3.ZERO, "off_belt": false, "flight_age": 0.0, "last_thrower": 0, "throw_origin": bag.get("position", Vector3.ZERO), "throw_landed": false, "inspected": bool(bag.get("opened", false)), "carrier": false, "pet": {}, "truth": {"scent_roll": 0.5}, "shell_mass_kg": [2.0, 3.5, 5.0][clampi(int(bag.get("size", 0)), 0, 2)]}
	for field in defaults:
		if not bag.has(field):
			bag[field] = defaults[field]
	for item in bag.get("items", []):
		var item_defaults: Dictionary = {"mass_kg": 1.0, "velocity": Vector3.ZERO, "flight_age": 0.0, "last_thrower": 0, "truth": {"declared_category": str(item.get("category", "legal")), "restricted": item.get("category", "legal") != "legal", "roll": 0.0, "probability": 1.0}}
		for field in item_defaults:
			if not item.has(field):
				item[field] = item_defaults[field]
	systems.ensure_bag(bag)
	_refresh_mass(bag)

func _refresh_mass(bag: Dictionary) -> void:
	var total: float = float(bag.get("shell_mass_kg", 2.0))
	var present: Array = []
	for item in bag.get("items", []):
		if item.location == "bag":
			total += float(item.get("mass_kg", 1.0))
			present.append(item.category)
	bag.mass_kg = total
	# Routing follows actual remaining contents, not the original case label.
	bag.category = "legal"
	for category in ["safeguarding", "pet", "wildlife", "explosives", "weapons", "dangerous", "narcotics", "organic", "customs"]:
		if category in present:
			bag.category = category
			break

func _start_lock(player: Dictionary, bag: Dictionary, peer_id: int) -> String:
	if not _accessible(bag, peer_id):
		return _feedback("Bag unavailable.")
	if bag.unlocked:
		return _feedback("Bag already unlocked.")
	if not player.lock_game.is_empty():
		return _feedback("Finish the active lock challenge first.")
	if player.tool == 0 or (player.tool == 1 and bag.lock != "approved"):
		return _feedback("Approved key opens approved locks; foreign locks require pliers.")
	var durability: String = "key_durability" if player.tool == 1 else "pliers_durability"
	if player[durability] <= 0:
		return _feedback("Tool worn out. Restock at the tool station.")
	for other in players.values():
		if not other.lock_game.is_empty() and other.lock_game.bag_id == bag.id:
			return _feedback("Another inspector is working on this lock.")
	player[durability] -= 1
	var sequence: Array = []
	for index in range(3 if player.tool == 1 else 4):
		sequence.append(rng.randi_range(0, 2))
	player.lock_game = {"bag_id": int(bag.id), "remaining": 7.0 if player.tool == 1 else 9.0, "sequence": sequence, "progress": 0, "tool": int(player.tool)}
	return _feedback("Lock challenge started. Enter the displayed sequence before time runs out.")

func _lock_input(player: Dictionary, peer_id: int, value: Variant) -> String:
	if typeof(value) != TYPE_INT or value < 0 or value > 2 or player.lock_game.is_empty():
		return _feedback("Enter 1, 2, or 3 during an active lock challenge.")
	var game: Dictionary = player.lock_game
	var bag: Dictionary = bags.get(int(game.bag_id), {})
	if not _accessible(bag, peer_id) or bag.unlocked or game.remaining <= 0.0:
		player.lock_game = {}
		return _feedback("Lock challenge cancelled; bag unavailable.")
	if int(game.sequence[game.progress]) != value:
		player.lock_game = {}
		return _feedback("Wrong lock input. Tool use consumed; try again.")
	game.progress += 1
	if game.progress < game.sequence.size():
		return _feedback("Lock input accepted.")
	bag.unlocked = true
	if game.tool == 2:
		bag.lock = "cut"
	player.lock_game = {}
	return _feedback("Bag unlocked.")

func _feed_pet(player: Dictionary, bag: Dictionary, peer_id: int) -> String:
	if not _accessible(bag, peer_id) or not bag.carrier or not bag.opened:
		return _feedback("Open an available animal carrier first.")
	if bag.pet.fed and bag.pet.hunger < 30.0 and bag.pet.thirst < 30.0:
		return _feedback("Animal is already fed and watered.")
	if player.food < 1 or player.water < 1:
		return _feedback("Animal care requires one food and one water supply.")
	player.food -= 1
	player.water -= 1
	bag.pet.hunger = 0.0
	bag.pet.thirst = 0.0
	bag.pet.fed = true
	return _feedback("Animal fed and watered gently. Ready for animal care.")

func _dispose_item(player: Dictionary) -> String:
	if player.held_kind != "item":
		return _feedback("Carry a dangerous training object to disposal first.")
	var item: Dictionary = get_item(int(player.held_id))
	if item.is_empty() or item.category not in Catalog.DISPOSAL_CATEGORIES or item.deposited:
		return _feedback("Only weapons, explosives, and dangerous objects use secure disposal.")
	item.location = "disposed"
	item.deposited = true
	item.held_by = 0
	item.velocity = Vector3.ZERO
	items_seized += 1
	money += 10
	_clear_hands(player)
	return _feedback("Fictional hazardous object secured for specialist disposal. +$10")

func _stop_bag(bag: Dictionary) -> void:
	bag.velocity = Vector3.ZERO
	bag.angular_velocity = Vector3.ZERO

func carry_speed(peer_id: int) -> float:
	var player: Dictionary = players.get(peer_id, {})
	if player.is_empty() or player.held_kind != "bag":
		return float(systems.carry_multiplier(self, peer_id))
	var bag: Dictionary = bags.get(player.held_id, {})
	if bag.is_empty():
		return 1.0
	# Recipient views are deliberately missing truth. Reading carry speed must
	# not normalize/rededuce their hidden categories or invent local truth.
	if not bag.has("mass_kg"):
		ensure_bag_physics(bag)
	return clampf(1.0 - float(bag.mass_kg) / 70.0, 0.55, 0.92) * float(systems.carry_multiplier(self, peer_id))

func _record_event(events: Array[Dictionary], event: Dictionary) -> void:
	events.append(event.duplicate(true))
	if events.size() > EVENT_LIMIT:
		events.pop_front()

func _throw_bag(player: Dictionary, peer_id: int, target_id: int, extra: Variant) -> String:
	if player.held_kind != "bag" or (target_id != -1 and target_id != int(player.held_id)):
		return _feedback("Only carried baggage can be thrown. Place dogs and belongings gently.")
	var bag: Dictionary = bags.get(int(player.held_id), {})
	if bag.is_empty() or bag.location != "held" or int(bag.held_by) != peer_id:
		return _feedback("Carry your own bag first.")
	if bag.carrier or bag.category == "safeguarding":
		return _feedback("Animal carriers need gentle handling. Carry this bag to animal care.")
	if not extra is Dictionary or not _valid_position(extra.get("origin")) or not _valid_position(extra.get("direction")):
		return _feedback("Throw requires a finite origin and unit aim direction.")
	var origin: Vector3 = extra.origin
	var direction: Vector3 = extra.direction
	if absf(direction.length_squared() - 1.0) > 0.001 or origin.distance_to(player.position) > 2.0:
		return _feedback("Throw from your own position with a unit aim direction.")
	# Fixed host strength, never a client-supplied velocity or impulse.
	ensure_bag_physics(bag)
	var mass: float = bag.mass_kg
	var velocity: Vector3 = direction * minf(90.0 / mass, 9.0) + Vector3.UP * (35.0 / mass)
	bag.position = origin
	bag.throw_origin = origin
	bag.velocity = velocity
	bag.angular_velocity = Vector3(2.4, 1.1, -1.7) * (8.0 / mass)
	bag.location = "airborne"
	bag.held_by = 0
	bag.opened = false
	bag.off_belt = true
	bag.flight_age = 0.0
	bag.last_thrower = peer_id
	bag.throw_landed = false
	_clear_hands(player)
	throws += 1
	_record_event(throw_events, {"bag_id": int(bag.id), "peer_id": peer_id, "mass_kg": mass, "position": origin, "start_position": origin, "velocity": velocity, "serial": throws})
	return _feedback("Threw bag %d (%.0f kg)." % [bag.id, mass])

func _catch_bag(player: Dictionary, peer_id: int, bag: Dictionary) -> String:
	if player.held_kind != "" or bag.is_empty() or bag.location != "airborne":
		return _feedback("Catch requires empty hands and an airborne bag.")
	if bag.position.y <= 0.12 or bag.flight_age < 0.08 or (int(bag.last_thrower) == peer_id and bag.flight_age < 0.35):
		return _feedback("Wait for the bag to be in flight and clear of the floor.")
	if (player.position + Vector3.UP * 0.8).distance_to(bag.position + Vector3.UP * 0.2) > 1.65:
		return _feedback("Airborne bag is out of catch reach.")
	var event: Dictionary = {"bag_id": int(bag.id), "peer_id": peer_id, "last_thrower": int(bag.last_thrower), "mass_kg": float(bag.mass_kg), "height": float(bag.position.y), "position": bag.position, "flight_age": float(bag.flight_age), "serial": catches + 1}
	_hold(player, peer_id, "bag", int(bag.id), bag)
	catches += 1
	_record_event(catch_events, event)
	return _feedback("Caught bag %d in mid-air." % bag.id)

func _update_flights(delta: float) -> void:
	for bag in bags.values():
		if bag.location != "airborne":
			continue
		var remaining: float = delta
		while remaining > 0.00000001 and bag.location == "airborne":
			var step: float = minf(remaining, FLIGHT_STEP)
			_flight_step(bag, step)
			remaining -= step

func _flight_step(bag: Dictionary, step: float) -> void:
	var from: Vector3 = bag.position
	var velocity: Vector3 = bag.velocity
	var to: Vector3 = from + velocity * step + Vector3.DOWN * (0.5 * GRAVITY * step * step)
	velocity += Vector3.DOWN * GRAVITY * step
	bag.flight_age = float(bag.flight_age) + step
	bag.rotation += bag.angular_velocity * step
	var hit: Dictionary = _room_hit(from, to)
	if collision_query.is_valid():
		var result: Variant = collision_query.call(from, to, bag)
		if result is Dictionary and _valid_position(result.get("position")) and _valid_position(result.get("normal")):
			var normal: Vector3 = result.normal
			# Ignore malformed or backwards contacts rather than corrupting state.
			if normal.length_squared() > 0.0001 and (to - from).dot(normal) < 0.0:
				if hit.is_empty() or from.distance_squared_to(result.position) < from.distance_squared_to(hit.position):
					hit = {"position": result.position, "normal": normal.normalized()}
	if not hit.is_empty():
		var normal: Vector3 = hit.normal
		var destination: Vector3 = to
		to = hit.position
		if normal.y > 0.999 and absf(from.y - to.y) < 0.00001:
			# A supporting floor must not pin a sliding bag's horizontal position.
			to.x = destination.x
			to.z = destination.z
		var incoming: float = velocity.dot(normal)
		if incoming < 0.0:
			systems.impact(self, bag, absf(incoming))
			velocity -= normal * ((1.0 + RESTITUTION) * incoming)
		if normal.y > 0.5:
			# Static friction consumes low rebounds; no endless gravity micro-bounce.
			if absf(velocity.y) < 0.45:
				velocity.y = 0.0
			var lateral: Vector3 = Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, 7.0 * step)
			velocity.x = lateral.x
			velocity.z = lateral.z
			bag.angular_velocity = (bag.angular_velocity as Vector3).move_toward(Vector3.ZERO, 12.0 * step)
			if to.y <= BAG_FLOOR + 0.001:
				_record_landing(bag, to)
			if velocity.length_squared() < 0.0036:
				bag.location = "floor"
				_stop_bag(bag)
				velocity = Vector3.ZERO
		else:
			# Separate from vertical walls before the next sweep.
			to += normal * 0.0001
	# A supporting-floor contact can win the earliest-hit test at a corner;
	# resolve its remaining wall constraints too instead of sticking at the wall.
	if (to.x > 10.0 and velocity.x > 0.0) or (to.x < -10.0 and velocity.x < 0.0):
		velocity.x *= -RESTITUTION
	if (to.z > 6.0 and velocity.z > 0.0) or (to.z < -4.9 and velocity.z < 0.0):
		velocity.z *= -RESTITUTION
	bag.position = Vector3(clampf(to.x, -10.0, 10.0), maxf(to.y, BAG_FLOOR), clampf(to.z, -4.9, 6.0))
	bag.velocity = velocity

func _room_hit(from: Vector3, to: Vector3) -> Dictionary:
	# Earliest segment/plane hit in a bounded room, independent of scene physics.
	var hit: Dictionary = {}
	var earliest: float = 2.0
	for plane in [[Vector3.UP, BAG_FLOOR], [Vector3.RIGHT, -10.0], [Vector3.LEFT, -10.0], [Vector3.BACK, -4.9], [Vector3.FORWARD, -6.0]]:
		var normal: Vector3 = plane[0]
		var start: float = from.dot(normal) - float(plane[1])
		var end: float = to.dot(normal) - float(plane[1])
		if end < 0.0 and end < start:
			var fraction: float = clampf(start / (start - end), 0.0, 1.0)
			if fraction < earliest:
				earliest = fraction
				hit = {"position": from.lerp(to, fraction), "normal": normal}
	return hit

func _record_landing(bag: Dictionary, position: Vector3) -> void:
	if bag.throw_landed:
		return
	bag.throw_landed = true
	landings += 1
	var origin: Vector3 = bag.throw_origin
	var distance: float = Vector2(position.x - origin.x, position.z - origin.z).length()
	_record_event(landing_events, {"bag_id": int(bag.id), "last_thrower": int(bag.last_thrower), "mass_kg": float(bag.mass_kg), "distance": distance, "position": position, "ground_position": position, "serial": landings})

func _valid_position(value: Variant) -> bool:
	return typeof(value) == TYPE_VECTOR3 and value.is_finite()

func _valid_placement(value: Variant, for_dog: bool = false) -> bool:
	if not value is Dictionary or value.get("location", "") not in (["floor", "belt"] if for_dog else ["floor", "belt", "table"]):
		return false
	if value.has("position") and not _valid_position(value.position):
		return false
	if value.location == "floor" and not value.has("position"):
		return false
	if value.has("t") and (typeof(value.t) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value.t)) or value.t < 0.0 or value.t > 0.72):
		return false
	return true

func _place(entity: Dictionary, placement: Dictionary, fallback: Vector3) -> void:
	if entity.has("items"):
		ensure_bag_physics(entity)
		_stop_bag(entity)
		entity.off_belt = placement.location != "belt"
	entity.location = placement.location
	entity.held_by = 0
	entity.position = placement.get("position", fallback)
	entity.t = float(placement.get("t", 0.35 if entity == dog else 0.0))
	if entity.location == "table":
		entity.position = Vector3(2, 1.15, 0)
	elif entity.location == "belt":
		entity.position = Vector3(-8 + 16 * entity.t, 1.14, -2)

func _buy_upgrade(kind: String) -> String:
	if upgrades[kind] > 0:
		return _feedback("Upgrade already purchased.")
	if kind == "kennel" and dog_scan_count < 1:
		return _feedback("Kennel training requires one harmless dog scanner crossing and $35.")
	if kind == "terminal" and (handled < 5 or reputation < 5):
		return _feedback("Terminal requires 5 handled bags and 5 reputation.")
	var cost: int = UPGRADE_COSTS[kind]
	if money < cost:
		return _feedback("Need $%d for %s." % [cost, kind])
	money -= cost
	upgrades[kind] = 1
	if kind == "belt":
		arrival_interval = 7.5
		_arrival_left = minf(_arrival_left, arrival_interval)
	if kind == "terminal":
		airport_level = 2
		_terminal_arrival = true
	return _feedback("Purchased %s. -$%d" % [kind, cost])

func _finish_bag(bag: Dictionary, player: Dictionary) -> String:
	var reward: int = 18
	match bag.category:
		"legal": legals += 1
		"narcotics":
			narcotics += 1
			reward = 32
		"organic":
			organics += 1
			reward = 40 + (20 if upgrades.bio_lab > 0 else 0)
		"safeguarding", "pet", "wildlife":
			rescues += 1
			reward = 50
		"weapons", "explosives", "dangerous", "customs":
			reward = 36
	handled += 1
	correct += 1
	reputation += 1
	money += reward
	bag.position = bag_position(bag)
	bag.location = "sorted"
	bag.held_by = 0
	_clear_hands(player)
	var milestone: int = 0
	for claim in [["legal", legals, 3, 30], ["organic", organics, 2, 35], ["rescue", rescues, 1, 45]]:
		if not contracts[claim[0]] and claim[1] >= claim[2]:
			contracts[claim[0]] = true
			milestone += claim[3]
	money += milestone
	return _feedback("Animal care handoff completed. +$%d" % (reward + milestone) if bag.carrier else "Correct route. +$%d" % (reward + milestone))

func expected_route(bag: Dictionary) -> String:
	match bag.get("category", ""):
		"safeguarding", "pet", "wildlife": return "rescue"
		"narcotics", "weapons", "explosives", "dangerous", "customs": return "security"
		"organic": return "bio"
		"legal":
			if int(bag.get("size", -1)) == 2 and airport_level >= 2:
				return "oversize"
			var flight: int = int(bag.get("flight", -1))
			if flight >= 0 and flight < 3:
				return ["gate_a", "gate_b", "gate_c"][flight]
	return ""

func get_item(id: int) -> Dictionary:
	for bag in bags.values():
		for item in bag.items:
			if int(item.id) == id:
				return item
	return {}

func bag_position(bag: Dictionary) -> Vector3:
	match bag.get("location", "floor"):
		"belt": return Vector3(-8 + 16 * float(bag.t), 1.14, -2)
		"table": return Vector3(2, 1.15, 0)
	return bag.get("position", Vector3.ZERO)

func _belt_space(t: float = 0.0, exclude: int = -1) -> bool:
	var count: int = 0
	for bag in bags.values():
		if bag.location == "belt" and int(bag.id) != exclude:
			count += 1
			if absf(float(bag.t) - t) < 0.075 - 0.000001:
				return false
	return count < (10 if upgrades.belt > 0 else 6)

func _try_arrive() -> bool:
	var active: int = 0
	for bag in bags.values():
		if bag.location != "sorted":
			active += 1
	if active >= 10 or not _belt_space():
		return false
	var id: int = _next_bag_id
	_next_bag_id += 1
	if not fixture_mode:
		bags[id] = _random_bag(id)
		ensure_bag_physics(bags[id])
		return true
	# Explicit deterministic tutorial fixtures; never selected by ordinary gameplay.
	var template: int = id - 1 if id <= 6 else [0, 2, 1][(id - 7) % 3]
	var categories: Array = ["legal", "narcotics", "organic", "pet", "legal", "organic"]
	var category: String = categories[template]
	var lock: String = ["approved", "foreign", "none", "foreign", "approved", "approved"][template]
	var flight: int = [0, 1, 0, 1, 1, 0][template]
	var oversized_contract = airport_level >= 2 and not _terminal_arrival and id > 6 and id % 4 == 0
	if oversized_contract:
		template = 0
		category = "legal"
		lock = "foreign"
		flight = 2
	if _terminal_arrival:
		template = 0
		category = "legal"
		lock = "approved"
		flight = 2
		_terminal_arrival = false
	var contents: Array = [
		[["clothes", "Clothes", "legal"], ["dildo", "Adult personal item (dildo)", "legal"]],
		[["narcotics", "Suspected narcotics", "narcotics"], ["socks", "Socks", "legal"]],
		[["fruit", "Fruit", "organic"], ["vegetable", "Vegetable", "organic"], ["seeds", "Seeds", "organic"]],
		[["pet_cat", "Cat in a ventilated pet carrier", "pet"], ["documents", "Travel documents", "legal"]],
		[["vibrator", "Adult personal item (vibrator)", "legal"], ["electronics", "Electronics", "legal"]],
		[["seeds", "Seeds", "organic"]],
	]
	# Later ordinary legal bags introduce the untrained dog's snack false positive.
	if id > 6 and category == "legal" and flight != 2:
		contents[template].append(["snacks", "Packaged snacks", "legal"])
	var items: Array[Dictionary] = []
	for spec in contents[template]:
		items.append({"id": _next_item_id, "kind": spec[0], "label": spec[1], "category": spec[2], "location": "bag", "position": Vector3(-8, 1.14, -2), "held_by": 0, "deposited": false})
		_next_item_id += 1
	bags[id] = {"id": id, "color": [0, 1, 2, 3, 4, 2][template], "size": [0, 1, 0, 2, 0, 0][template], "kind": [0, 1, 2, 3, 0, 2][template], "flight": flight, "lock": lock, "unlocked": lock == "none", "opened": false, "scanned": false, "scan_left": 0.0, "location": "belt", "t": 0.0, "position": Vector3(-8, 1.14, -2), "held_by": 0, "dog_alert": false, "category": category, "items": items}
	if oversized_contract:
		bags[id].size = 2
		bags[id].kind = 3
	ensure_bag_physics(bags[id])
	if category == "pet":
		bags[id].carrier = true
		bags[id].pet = {"species": "cat", "hunger": 65.0, "thirst": 60.0, "fed": false}
	return true

func _random_bag(id: int) -> Dictionary:
	var items: Array[Dictionary] = []
	var carrier: bool = false
	var pet: Dictionary = {}
	for index in range(rng.randi_range(2, 6)):
		var spec: Dictionary = Catalog.random_spec(rng)
		if carrier and spec.category in ["pet", "wildlife"]:
			spec = Catalog.entry("clothes")
		var item: Dictionary = Catalog.instantiate(spec, rng, _next_item_id)
		_next_item_id += 1
		items.append(item)
		if item.category in ["pet", "wildlife"]:
			carrier = true
			pet = {"species": "cat" if item.kind == "pet_cat" else ("rabbit" if item.kind == "pet_rabbit" else "cloud_lizard"), "hunger": rng.randf_range(45.0, 80.0), "thirst": rng.randf_range(45.0, 80.0), "fed": false}
	var size: int = rng.randi_range(0, 2)
	var lock: String = ["approved", "foreign", "none"][rng.randi_range(0, 2)]
	var flight: int = rng.randi_range(0, 2 if airport_level > 1 else 1)
	if _terminal_arrival:
		flight = 2
		_terminal_arrival = false
	return {"id": id, "color": rng.randi_range(0, 5), "size": size, "kind": 3 if carrier else rng.randi_range(0, 3), "flight": flight, "lock": lock, "unlocked": lock == "none", "opened": false, "inspected": false, "scanned": false, "scan_left": 0.0, "location": "belt", "t": 0.0, "position": Vector3(-8, 1.14, -2), "held_by": 0, "dog_alert": false, "category": "legal", "items": items, "shell_mass_kg": float(snappedf(rng.randf_range(1.5 + size, 3.5 + size * 2.0), 0.01)), "carrier": carrier, "pet": pet, "truth": {"scent_roll": rng.randf()}}

func update(delta: float) -> void:
	if shift_finished or not is_finite(delta) or delta < 0.0:
		return
	var elapsed: float = minf(delta, maxf(time_left, 0.0))
	# Initial arrival also works on update(0). No IDs are consumed while full.
	if belt_running and _arrival_left <= 0.00000001 and _try_arrive():
		_arrival_left = arrival_interval
	var remaining: float = elapsed
	while remaining > 0.00000001:
		var step: float = minf(remaining, 0.05)
		# Stop exactly at scheduled arrivals rather than drifting by a render frame.
		if belt_running and _arrival_left > 0.00000001:
			step = minf(step, _arrival_left)
		if belt_running:
			_move_bags(step)
			_arrival_left = maxf(0.0, _arrival_left - step)
			if _arrival_left <= 0.00000001 and _try_arrive():
				_arrival_left = arrival_interval
		systems.update(self, step)
		for player in players.values():
			if not player.lock_game.is_empty():
				var game: Dictionary = player.lock_game
				game.remaining = maxf(0.0, float(game.remaining) - step)
				if game.remaining <= 0.0 or not _accessible(bags.get(int(game.bag_id), {}), int(players.find_key(player))):
					player.lock_game = {}
					last_event = "Lock challenge expired. Tool use consumed; try again."
			_sync_held(player)
		for entry in bags.values():
			if entry.carrier and entry.location != "sorted":
				entry.pet.hunger = minf(100.0, float(entry.pet.hunger) + step * 0.08)
				entry.pet.thirst = minf(100.0, float(entry.pet.thirst) + step * 0.12)
		_update_flights(step)
		systems.update_dog(self, step)
		remaining -= step
	time_left = maxf(0.0, time_left - elapsed)
	if time_left <= 0.00000001:
		time_left = 0.0
		shift_finished = true
		# A frozen lock modal must not trap the host behind disabled N input.
		# Preserve consumed tool durability, but cancel every pending challenge.
		for player in players.values():
			player.lock_game = {}
		last_event = "Shift finished. Progress is retained between shifts; begin the next shift when ready."

func _move_bags(delta: float) -> void:
	var moving: Array = []
	for bag in bags.values():
		if bag.location == "belt":
			moving.append(bag)
	moving.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.t) > float(b.t) if a.t != b.t else int(a.id) < int(b.id))
	var limit: float = 0.72
	for bag in moving:
		var available: float = delta
		if not bag.scanned:
			if float(bag.t) < 0.45:
				var travel: float = minf(available, maxf(0.0, minf(0.45, limit) - float(bag.t)) / BELT_SPEED)
				bag.t = minf(minf(0.45, limit), float(bag.t) + travel * BELT_SPEED)
				available -= travel
			if float(bag.t) >= 0.45 - 0.00000001:
				if float(bag.scan_left) <= 0.0:
					bag.scan_left = 0.3 if upgrades.scanner > 0 else 1.0
				var scanning: float = minf(available, float(bag.scan_left))
				bag.scan_left = maxf(0.0, float(bag.scan_left) - scanning)
				available -= scanning
				if float(bag.scan_left) <= 0.00000001:
					bag.scan_left = 0.0
					bag.scanned = true
		if bag.scanned:
			bag.t = minf(limit, float(bag.t) + available * BELT_SPEED)
		bag.position = bag_position(bag)
		limit = maxf(0.0, float(bag.t) - 0.075)

func _update_dog(delta: float) -> void:
	systems.update_dog(self, delta)

func next_shift() -> bool:
	if not shift_finished:
		return false
	day += 1
	time_left = SHIFT_SECONDS
	shift_finished = false
	last_event = "Shift %d: airport reopened; baggage and progress preserved." % day
	return true

func snapshot() -> Dictionary:
	var data: Dictionary = {"bags": bags, "players": players}
	for field in STATE_FIELDS:
		data[field] = get(field)
	data._rng_seed = rng.seed
	data._rng_state = rng.state
	data._fixture_mode = fixture_mode
	return data.duplicate(true)

func snapshot_for(peer_id: int) -> Dictionary:
	var data: Dictionary = snapshot()
	data.erase("_rng_seed")
	data.erase("_rng_state")
	data.erase("_fixture_mode")
	data.redacted = true
	for bag in data.bags.values():
		bag.erase("truth")
		if not bag.inspected:
			bag.category = "unknown"
		for item in bag.items:
			item.erase("truth")
			if not bag.inspected and item.location == "bag":
				item.kind = "unknown"
				item.label = "Uninspected item"
				item.category = "unknown"
	# Only the acting inspector needs the input challenge. Its solution is public
	# to that player by design; it is not contraband truth or an RNG seed.
	for id in data.players:
		if int(id) != peer_id:
			data.players[id].lock_game = {}
	return data

func _id_key(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return value if value > 0 else -1
	if typeof(value) == TYPE_STRING and value.is_valid_int() and str(int(value)) == value and int(value) > 0:
		return int(value)
	return -1

func _has_shape(value: Variant, shape: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	for key in shape:
		if not value.has(key) or typeof(value[key]) != typeof(shape[key]):
			return false
		if typeof(value[key]) == TYPE_FLOAT and not is_finite(value[key]):
			return false
		if typeof(value[key]) == TYPE_VECTOR3 and not value[key].is_finite():
			return false
	return true

func apply_snapshot(data: Dictionary) -> void:
	# Validate the complete message before mutating anything. ENet Variant encoding
	# retains Vector3; stringified integer dictionary keys are normalized explicitly.
	if not data.get("bags") is Dictionary or not data.get("players") is Dictionary:
		return
	var redacted: bool = data.get("redacted", false) == true
	if data.has("redacted") and typeof(data.redacted) != TYPE_BOOL:
		return
	if not _valid_expansion_state(data, redacted):
		return
	for field in STATE_FIELDS:
		if not data.has(field) or typeof(data[field]) != typeof(get(field)):
			return
		if typeof(data[field]) == TYPE_FLOAT and not is_finite(data[field]):
			return
	if not _has_shape(data.upgrades, upgrades) or not _has_shape(data.contracts, contracts) or not _has_shape(data.dog, dog) or not _valid_position(data.dog_goal):
		return
	for key in upgrades:
		if data.upgrades[key] not in [0, 1]:
			return
	if data.dog.location not in ["floor", "belt", "held", "airborne"] or data.money < 0 or data.airport_level not in [1, 2] or data.day < 1 or data.time_left < 0.0 or data.arrival_interval <= 0.0:
		return
	var restored_bags: Dictionary = {}
	var restored_players: Dictionary = {}
	var item_ids: Dictionary = {}
	var bag_shape: Dictionary = {"id": 0, "color": 0, "size": 0, "kind": 0, "flight": 0, "lock": "", "unlocked": false, "opened": false, "scanned": false, "scan_left": 0.0, "location": "", "t": 0.0, "position": Vector3.ZERO, "held_by": 0, "dog_alert": false, "category": "", "items": [], "mass_kg": 0.0, "velocity": Vector3.ZERO, "rotation": Vector3.ZERO, "angular_velocity": Vector3.ZERO, "off_belt": false, "flight_age": 0.0, "last_thrower": 0, "throw_origin": Vector3.ZERO, "throw_landed": false}
	var item_shape: Dictionary = {"id": 0, "kind": "", "label": "", "category": "", "location": "", "position": Vector3.ZERO, "held_by": 0, "deposited": false}
	bag_shape.merge({"shell_mass_kg": 0.0, "damage": 0.0, "carry_helpers": [], "carrier": false, "pet": {}, "inspected": false})
	item_shape.merge({"mass_kg": 0.0, "velocity": Vector3.ZERO, "flight_age": 0.0, "last_thrower": 0})
	var allowed_categories: Array = CATEGORIES + (["unknown"] if redacted else [])
	for key in data.bags:
		var id: int = _id_key(key)
		var bag: Variant = data.bags[key]
		if id < 1 or restored_bags.has(id) or not _has_shape(bag, bag_shape):
			return
		if bag.id != id or bag.color < 0 or bag.color > 5 or bag.size not in [0, 1, 2] or bag.kind not in [0, 1, 2, 3] or bag.flight not in [0, 1, 2] or bag.lock not in ["approved", "foreign", "none", "cut"] or bag.category not in allowed_categories or bag.location not in ["belt", "table", "floor", "held", "sorted", "airborne"] or bag.t < 0.0 or bag.t > 1.0 or bag.scan_left < 0.0:
			return
		if bag.mass_kg < 0.1 or bag.flight_age < 0.0 or bag.last_thrower < 0:
			return
		if bag.location == "airborne" and (not bag.off_belt or bag.last_thrower == 0 or bag.category == "safeguarding"):
			return
		if bag.location == "belt" and bag.off_belt:
			return
		if bag.location == "held" and not bag.off_belt:
			return
		if bag.location != "airborne" and (bag.velocity != Vector3.ZERO or bag.angular_velocity != Vector3.ZERO):
			return
		for item in bag.items:
			if not _has_shape(item, item_shape):
				return
			if item.id < 1 or item_ids.has(item.id) or item.category not in allowed_categories or item.location not in ["bag", "held", "floor", "evidence", "disposed", "airborne"] or (item.category in ["safeguarding", "pet", "wildlife"] and item.location != "bag"):
				return
			item_ids[item.id] = true
		restored_bags[id] = bag.duplicate(true)
	for key in data.players:
		var id: int = _id_key(key)
		var player: Variant = data.players[key]
		if id < 1 or restored_players.has(id) or not _has_shape(player, {"held_kind": "", "held_id": -1, "tool": 0, "position": Vector3.ZERO}):
			return
		if player.held_kind not in ["", "bag", "item", "dog"] or player.tool not in [0, 1, 2]:
			return
		restored_players[id] = player.duplicate(true)
	# Cross-check carry references; no dangling or multiply-owned entities.
	var held_items: Dictionary = {}
	for bag in restored_bags.values():
		for item in bag.items:
			if item.location == "held":
				held_items[item.id] = item
	for id in restored_players:
		var player: Dictionary = restored_players[id]
		var entity: Dictionary = {}
		match player.held_kind:
			"bag": entity = restored_bags.get(player.held_id, {})
			"item": entity = held_items.get(player.held_id, {})
			"dog": entity = data.dog
			"":
				if player.held_id != -1:
					return
		if player.held_kind != "" and (entity.is_empty() or entity.location != "held" or entity.held_by != id):
			return
	for bag in restored_bags.values():
		if not _valid_owner(bag, restored_players, "bag", bag.id):
			return
		for item in bag.items:
			if not _valid_owner(item, restored_players, "item", item.id) or (item.deposited != (item.location in ["evidence", "disposed"])):
				return
	if not _valid_owner(data.dog, restored_players, "dog", -1):
		return
	for id in restored_bags:
		if id >= data._next_bag_id:
			return
	for id in item_ids:
		if id >= data._next_item_id:
			return
	if not _valid_event_history(data.throw_events, data.throws, "throw", restored_bags) or not _valid_event_history(data.catch_events, data.catches, "catch", restored_bags) or not _valid_event_history(data.landing_events, data.landings, "landing", restored_bags):
		return
	if data.catches > data.throws or data.landings > data.throws:
		return
	if not _valid_carry_links(restored_bags, restored_players):
		return
	if data.dog.follow_peer != 0 and not restored_players.has(data.dog.follow_peer):
		return
	if data.dog.mode == "follow" and data.dog.follow_peer == 0:
		return
	var challenged_bags: Array = []
	for id in restored_players:
		var game: Dictionary = restored_players[id].lock_game
		if game.is_empty():
			continue
		var challenged: Dictionary = restored_bags.get(game.bag_id, {})
		if challenged.is_empty() or challenged.unlocked or challenged.location in ["sorted", "airborne"] or (challenged.location == "held" and challenged.held_by != id) or game.bag_id in challenged_bags:
			return
		challenged_bags.append(game.bag_id)
	bags = restored_bags
	players = restored_players
	for field in STATE_FIELDS:
		var value: Variant = data[field]
		set(field, value.duplicate(true) if value is Dictionary or value is Array else value)
	if not redacted:
		rng.seed = data._rng_seed
		rng.state = data._rng_state
		fixture_mode = data._fixture_mode

func _in_range(value: Variant, low: float, high: float) -> bool:
	return typeof(value) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(value)) and float(value) >= low and float(value) <= high

func _valid_expansion_state(data: Dictionary, redacted: bool) -> bool:
	if redacted:
		for key in ["_rng_seed", "_rng_state", "_fixture_mode"]:
			if data.has(key):
				return false
	elif not _has_shape(data, {"_rng_seed": 0, "_rng_state": 0, "_fixture_mode": false}):
		return false
	var dog_shape: Dictionary = {"hunger": 0.0, "thirst": 0.0, "xp": 0, "mode": "", "follow_peer": 0, "patrol_index": 0, "velocity": Vector3.ZERO, "flight_age": 0.0, "scent_left": 0.0, "rest_left": 0.0, "last_thrower": 0}
	if not _has_shape(data.get("dog"), dog_shape):
		return false
	var incoming_dog: Dictionary = data.dog
	if not _in_range(incoming_dog.hunger, 0, 100) or not _in_range(incoming_dog.thirst, 0, 100) or incoming_dog.xp < 0 or incoming_dog.mode not in ["follow", "patrol", "stay"] or incoming_dog.follow_peer < 0 or incoming_dog.patrol_index not in [0, 1, 2, 3] or incoming_dog.flight_age < 0.0 or incoming_dog.scent_left < 0.0 or incoming_dog.rest_left < 0.0 or incoming_dog.last_thrower < 0:
		return false
	if incoming_dog.get("location") == "airborne" and incoming_dog.last_thrower < 1:
		return false
	for bag in data.bags.values():
		if not _has_shape(bag, {"shell_mass_kg": 0.0, "mass_kg": 0.0, "damage": 0.0, "carry_helpers": [], "carrier": false, "pet": {}, "inspected": false, "items": [], "category": "", "opened": false}):
			return false
		if not _in_range(bag.shell_mass_kg, 0.1, 50) or not _in_range(bag.damage, 0, 100) or bag.carry_helpers.size() > 1 or (bag.opened and (not bag.inspected or not bag.get("unlocked", false))):
			return false
		if redacted:
			if bag.has("truth") or (not bag.inspected and bag.category != "unknown") or (bag.inspected and bag.category == "unknown"):
				return false
		elif not _has_shape(bag.get("truth"), {"scent_roll": 0.0}) or not _in_range(bag.truth.scent_roll, 0, 1):
			return false
		if bag.carrier:
			if not _has_shape(bag.pet, {"species": "", "hunger": 0.0, "thirst": 0.0, "fed": false}):
				return false
			if bag.pet.species not in ["cat", "rabbit", "cloud_lizard"] or not _in_range(bag.pet.hunger, 0, 100) or not _in_range(bag.pet.thirst, 0, 100):
				return false
		elif not bag.pet.is_empty():
			return false
		var total: float = bag.shell_mass_kg
		var contents_categories: Array = []
		var animals: int = 0
		for item in bag.items:
			if not _has_shape(item, {"mass_kg": 0.0, "velocity": Vector3.ZERO, "flight_age": 0.0, "last_thrower": 0, "location": "", "category": "", "kind": "", "label": ""}):
				return false
			if not _in_range(item.mass_kg, 0.01, 100) or item.flight_age < 0.0 or item.last_thrower < 0:
				return false
			if item.location == "airborne" and item.last_thrower < 1:
				return false
			if item.location != "airborne" and item.velocity != Vector3.ZERO:
				return false
			if item.location == "disposed" and item.category not in Catalog.DISPOSAL_CATEGORIES:
				return false
			if item.location == "evidence" and item.category not in ["narcotics", "organic", "customs"]:
				return false
			if redacted:
				if item.has("truth"):
					return false
				if not bag.inspected and item.location == "bag" and (item.kind != "unknown" or item.category != "unknown" or item.label != "Uninspected item"):
					return false
				if (bag.inspected or item.location != "bag") and item.category == "unknown":
					return false
			else:
				if not _has_shape(item.get("truth"), {"declared_category": "", "restricted": false, "roll": 0.0, "probability": 0.0}):
					return false
				if item.truth.declared_category not in CATEGORIES or not _in_range(item.truth.roll, 0, 1) or not _in_range(item.truth.probability, 0, 1) or item.truth.restricted != (item.category != "legal"):
					return false
			if item.location == "bag":
				total += item.mass_kg
				contents_categories.append(item.category)
				if item.category in ["pet", "wildlife"]:
					animals += 1
		if absf(total - float(bag.mass_kg)) > 0.0001:
			return false
		if not redacted or bag.inspected:
			if animals != (1 if bag.carrier else 0):
				return false
			var actual_category: String = "legal"
			for category in ["safeguarding", "pet", "wildlife", "explosives", "weapons", "dangerous", "narcotics", "organic", "customs"]:
				if category in contents_categories:
					actual_category = category
					break
			if bag.category != actual_category:
				return false
	var player_shape: Dictionary = {"key_durability": 0, "pliers_durability": 0, "seals": 0, "food": 0, "water": 0, "lock_game": {}, "health": 0.0, "stamina": 0.0, "sprinting": false, "crouching": false, "carry_partner": 0, "carry_bag": -1, "moving": false, "movement_left": 0.0, "jump_left": 0.0, "hurt_left": 0.0, "exhausted": false}
	for player in data.players.values():
		if not _has_shape(player, player_shape):
			return false
		if not _in_range(player.key_durability, 0, 8) or not _in_range(player.pliers_durability, 0, 5) or not _in_range(player.seals, 0, 3) or not _in_range(player.food, 0, 3) or not _in_range(player.water, 0, 3) or not _in_range(player.health, 0, 100) or not _in_range(player.stamina, 0, 100) or player.carry_partner < 0 or player.carry_bag < -1 or player.carry_bag == 0:
			return false
		if player.movement_left < 0.0 or player.jump_left < 0.0 or player.hurt_left < 0.0:
			return false
		if not player.lock_game.is_empty():
			var game: Dictionary = player.lock_game
			if not _has_shape(game, {"bag_id": 0, "remaining": 0.0, "sequence": [], "progress": 0, "tool": 0}):
				return false
			if game.bag_id < 1 or not _in_range(game.remaining, 0.000001, 9) or game.tool not in [1, 2] or game.sequence.size() != (3 if game.tool == 1 else 4) or game.progress < 0 or game.progress >= game.sequence.size():
				return false
			if not data.bags.has(game.bag_id) and not data.bags.has(str(game.bag_id)):
				return false
			for symbol in game.sequence:
				if typeof(symbol) != TYPE_INT or symbol not in [0, 1, 2]:
					return false
	return true

func _valid_carry_links(known_bags: Dictionary, peers: Dictionary) -> bool:
	for bag in known_bags.values():
		for helper in bag.carry_helpers:
			if typeof(helper) != TYPE_INT or not peers.has(helper) or bag.location != "held" or helper == bag.held_by or not peers.has(bag.held_by):
				return false
			var player: Dictionary = peers[helper]
			if player.held_kind != "" or player.carry_bag != bag.id or player.carry_partner != bag.held_by or peers[bag.held_by].carry_partner != helper:
				return false
	for id in peers:
		var player: Dictionary = peers[id]
		if player.carry_bag > 0:
			if not known_bags.has(player.carry_bag) or id not in known_bags[player.carry_bag].carry_helpers:
				return false
		if player.carry_partner > 0:
			if not peers.has(player.carry_partner) or peers[player.carry_partner].carry_partner != id:
				return false
			if player.carry_bag == -1:
				if player.held_kind != "bag" or not known_bags.has(player.held_id) or player.carry_partner not in known_bags[player.held_id].carry_helpers:
					return false
		elif player.carry_bag > 0:
			return false
	return true

func _valid_event_history(events: Array, count: int, kind: String, known_bags: Dictionary) -> bool:
	if count < 0 or events.size() != mini(count, EVENT_LIMIT):
		return false
	var shape: Dictionary = {"bag_id": 0, "mass_kg": 0.0, "position": Vector3.ZERO, "serial": 0}
	match kind:
		"throw": shape.merge({"peer_id": 0, "start_position": Vector3.ZERO, "velocity": Vector3.ZERO})
		"catch": shape.merge({"peer_id": 0, "last_thrower": 0, "height": 0.0, "flight_age": 0.0})
		"landing": shape.merge({"last_thrower": 0, "distance": 0.0, "ground_position": Vector3.ZERO})
	var serial: int = count - events.size() + 1
	for event in events:
		if not _has_shape(event, shape):
			return false
		if not known_bags.has(event.bag_id) or event.serial != serial or event.mass_kg < 0.1:
			return false
		if event.has("peer_id") and event.peer_id <= 0:
			return false
		if event.has("last_thrower") and event.last_thrower <= 0:
			return false
		if kind == "catch" and (event.height <= 0.12 or event.flight_age < 0.08):
			return false
		if kind == "landing" and event.distance < 0.0:
			return false
		serial += 1
	return true

func _valid_owner(entity: Dictionary, peers: Dictionary, kind: String, id: int) -> bool:
	if entity.location != "held":
		return entity.held_by == 0
	var owner: Dictionary = peers.get(entity.held_by, {})
	return not owner.is_empty() and owner.held_kind == kind and owner.held_id == id
