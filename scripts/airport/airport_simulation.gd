class_name AirportSimulation
extends RefCounted
## Deterministic, scene-free, host-owned state. The scene supplies proximity checks.
## Scanner is a fictional non-ionizing training device, including the dog gag.

const SHIFT_SECONDS: float = 240.0
const BELT_SPEED: float = 0.065
const UPGRADE_COSTS: Dictionary = {"scanner": 45, "kennel": 35, "evidence": 30, "bio_lab": 70, "belt": 55, "terminal": 120}
const ROUTES: Array = ["gate_a", "gate_b", "gate_c", "oversize", "security", "bio", "rescue"]
const CATEGORIES: Array = ["legal", "narcotics", "organic", "safeguarding"]
const STATE_FIELDS: Array = ["money", "reputation", "handled", "correct", "mistakes", "organics", "narcotics", "rescues", "legals", "items_seized", "airport_level", "day", "time_left", "shift_finished", "belt_running", "arrival_interval", "last_event", "upgrades", "contracts", "dog_scan_count", "dog", "dog_goal", "_next_bag_id", "_next_item_id", "_arrival_left", "_terminal_arrival"]

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

func add_player(peer_id: int) -> void:
	if peer_id > 0 and not players.has(peer_id):
		players[peer_id] = {"held_kind": "", "held_id": -1, "tool": 0, "position": Vector3.ZERO}

func set_player_position(peer_id: int, position: Vector3) -> void:
	if players.has(peer_id) and position.is_finite():
		players[peer_id].position = position
		_sync_held(players[peer_id])

func remove_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	var player: Dictionary = players[peer_id]
	var entity: Dictionary = _held_entity(player)
	if not entity.is_empty():
		entity.location = "floor"
		entity.position = player.position
		entity.held_by = 0
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
	player.held_kind = kind
	player.held_id = id
	entity.location = "held"
	entity.held_by = peer_id
	entity.position = player.position

func _accessible(bag: Dictionary, peer_id: int) -> bool:
	return not bag.is_empty() and bag.location != "sorted" and (bag.location != "held" or int(bag.held_by) == peer_id)

func _feedback(message: String) -> String:
	last_event = message
	return message

func act(peer_id: int, action: String, target_id: int = -1, extra: Variant = null) -> String:
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
			if player.held_kind != "" or bag.is_empty() or bag.location in ["held", "sorted"]:
				return _feedback("Need empty hands and an available bag.")
			_hold(player, peer_id, "bag", target_id, bag)
			return _feedback("Carrying bag %d." % target_id)
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
			if not _accessible(bag, peer_id):
				return _feedback("Bag unavailable.")
			if bag.unlocked:
				return _feedback("Bag already unlocked.")
			if player.tool == 2:
				bag.lock = "cut"
				bag.unlocked = true
			elif player.tool == 1 and bag.lock == "approved":
				bag.unlocked = true
			else:
				return _feedback("Approved key opens approved locks; foreign locks require pliers.")
			return _feedback("Bag unlocked.")
		"open":
			if not _accessible(bag, peer_id) or not bag.unlocked:
				return _feedback("Unlock an available bag first.")
			bag.opened = true
			return _feedback("Bag opened for inspection.")
		"take_item":
			if player.held_kind != "" or not _accessible(bag, peer_id) or not bag.opened:
				return _feedback("Open the bag and use empty hands.")
			if typeof(extra) != TYPE_INT or extra < 0 or extra >= bag.items.size():
				return _feedback("Choose an item in the bag.")
			var item: Dictionary = bag.items[extra]
			if item.category == "safeguarding":
				return _feedback("A person is not an item. Route the bag to safeguarding rescue.")
			if item.location != "bag" or item.deposited:
				return _feedback("Item already removed.")
			_hold(player, peer_id, "item", item.id, item)
			return _feedback("Carrying %s." % item.label)
		"pickup_item":
			var item: Dictionary = get_item(target_id)
			if player.held_kind != "" or item.is_empty() or item.location != "floor" or item.deposited or item.category == "safeguarding":
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
				return _feedback("Return a held item to its open source bag.")
			var item: Dictionary = get_item(player.held_id)
			if not bag.items.has(item):
				return _feedback("That is not the item's source bag.")
			item.location = "bag"
			item.position = bag_position(bag)
			item.held_by = 0
			_clear_hands(player)
			return _feedback("Item returned to source bag.")
		"seize_item":
			if player.held_kind != "item":
				return _feedback("Carry a restricted item to evidence first.")
			var item: Dictionary = get_item(player.held_id)
			if item.category not in ["narcotics", "organic"] or item.deposited:
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
			if bag.category != "legal" and not bag.opened:
				return _feedback("Open restricted baggage and inspect before routing.")
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
			if player.held_kind != "" or dog.location == "held":
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
		"safeguarding":
			rescues += 1
			reward = 50
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
	return _feedback("Safeguarding rescue completed. +$%d" % (reward + milestone) if bag.category == "safeguarding" else "Correct route. +$%d" % (reward + milestone))

func expected_route(bag: Dictionary) -> String:
	match bag.get("category", ""):
		"safeguarding": return "rescue"
		"narcotics": return "security"
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
	# Deterministic first six cases, then a repeating legal/organic/narcotics cycle.
	var template: int = id - 1 if id <= 6 else [0, 2, 1][(id - 7) % 3]
	var categories: Array = ["legal", "narcotics", "organic", "safeguarding", "legal", "organic"]
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
		[["adult_silhouette", "Adult safeguarding silhouette — seek rescue", "safeguarding"], ["documents", "Travel documents", "legal"]],
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
	return true

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
		for player in players.values():
			_sync_held(player)
		_update_dog(step)
		remaining -= step
	time_left = maxf(0.0, time_left - elapsed)
	if time_left <= 0.00000001:
		time_left = 0.0
		shift_finished = true
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
	dog.bark_left = maxf(0.0, float(dog.bark_left) - delta)
	if dog.location == "floor":
		dog.position = (dog.position as Vector3).move_toward(dog_goal, 1.8 * delta)
	elif dog.location == "belt" and belt_running:
		dog.t = float(dog.t) + BELT_SPEED * delta
		dog.position = Vector3(-8 + 16 * float(dog.t), 1.14, -2)
		if not dog.scanned and float(dog.t) >= 0.45:
			dog.scanned = true
			dog_scan_count += 1
			last_event = "VERY GOOD BOY — harmless non-ionizing training scan!"
		if float(dog.t) > 0.75:
			dog.location = "floor"
			dog.position = Vector3(4, 0.3, -1)
			dog_goal = dog.position
	var radius: float = 6.0 if upgrades.kennel > 0 else 3.0
	for bag in bags.values():
		if bag.location == "sorted" or bag.dog_alert or (dog.position as Vector3).distance_to(bag_position(bag)) > radius:
			continue
		var suspicious: bool = bag.category in ["narcotics", "organic", "safeguarding"]
		if upgrades.kennel == 0:
			for item in bag.items:
				if item.kind == "snacks" and item.category == "legal":
					suspicious = true
		if suspicious:
			bag.dog_alert = true
			dog.alerts += 1
			dog.alert_bag = bag.id
			dog.bark_left = 1.5
			last_event = "Woof! Inspect bag %d; an alert is not a conviction." % bag.id

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
	return data.duplicate(true)

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
	if data.dog.location not in ["floor", "belt", "held"] or data.money < 0 or data.airport_level not in [1, 2] or data.day < 1 or data.time_left < 0.0 or data.arrival_interval <= 0.0:
		return
	var restored_bags: Dictionary = {}
	var restored_players: Dictionary = {}
	var item_ids: Dictionary = {}
	var bag_shape: Dictionary = {"id": 0, "color": 0, "size": 0, "kind": 0, "flight": 0, "lock": "", "unlocked": false, "opened": false, "scanned": false, "scan_left": 0.0, "location": "", "t": 0.0, "position": Vector3.ZERO, "held_by": 0, "dog_alert": false, "category": "", "items": []}
	var item_shape: Dictionary = {"id": 0, "kind": "", "label": "", "category": "", "location": "", "position": Vector3.ZERO, "held_by": 0, "deposited": false}
	for key in data.bags:
		var id: int = _id_key(key)
		var bag: Variant = data.bags[key]
		if id < 1 or restored_bags.has(id) or not _has_shape(bag, bag_shape):
			return
		if bag.id != id or bag.color < 0 or bag.color > 5 or bag.size not in [0, 1, 2] or bag.kind not in [0, 1, 2, 3] or bag.flight not in [0, 1, 2] or bag.lock not in ["approved", "foreign", "none", "cut"] or bag.category not in CATEGORIES or bag.location not in ["belt", "table", "floor", "held", "sorted"] or bag.t < 0.0 or bag.t > 1.0 or bag.scan_left < 0.0:
			return
		for item in bag.items:
			if not _has_shape(item, item_shape):
				return
			if item.id < 1 or item_ids.has(item.id) or item.category not in CATEGORIES or item.location not in ["bag", "held", "floor", "evidence"] or (item.category == "safeguarding" and item.location != "bag"):
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
			if not _valid_owner(item, restored_players, "item", item.id) or (item.deposited != (item.location == "evidence")):
				return
	if not _valid_owner(data.dog, restored_players, "dog", -1):
		return
	for id in restored_bags:
		if id >= data._next_bag_id:
			return
	for id in item_ids:
		if id >= data._next_item_id:
			return
	bags = restored_bags
	players = restored_players
	for field in STATE_FIELDS:
		var value: Variant = data[field]
		set(field, value.duplicate(true) if value is Dictionary or value is Array else value)

func _valid_owner(entity: Dictionary, peers: Dictionary, kind: String, id: int) -> bool:
	if entity.location != "held":
		return entity.held_by == 0
	var owner: Dictionary = peers.get(entity.held_by, {})
	return not owner.is_empty() and owner.held_kind == kind and owner.held_id == id
