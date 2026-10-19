class_name SushiSimulation
extends RefCounted
## Deterministic authority-only game state; contains no scene or networking objects.
## The scene owns proximity checks (including access to the loading/clear station).

const RECIPES = ["SALMON", "TUNA", "CUCUMBER"]
const RECIPE_VALUES = [8, 10, 6]
const SHIFT_SECONDS: float = 120.0
const PATIENCE_SECONDS: float = 18.0
const STALE_SECONDS: float = 32.0
const DISCARD_SECONDS: float = 64.0
const UPGRADE_COSTS = {"tray": 24, "prep": 18, "washer": 16}

var money: int = 0
var clean_plates: int = 8
var dirty_plates: int = 0
var served: int = 0
var wasted: int = 0
var missed: int = 0
var day: int = 1
var time_left: float = SHIFT_SECONDS
var shift_finished: bool = false
var belt_speed: float = 0.035
var belt: Array[Dictionary] = []
var customers: Array[Dictionary] = []
var players: Dictionary = {}
var upgrades: Dictionary = {"tray": 0, "prep": 0, "washer": 0}
var last_event: String = "Shift 1: kitchen open!"
var total_earned: int = 0
var shift_earned: int = 0
var _next_plate_id: int = 1

func _init() -> void:
	for index in range(4):
		customers.append({
			"recipe": index % RECIPES.size(),
			"t": 0.125 + 0.25 * index,
			"patience": PATIENCE_SECONDS,
			"served": 0,
		})

func add_player(peer_id: int) -> void:
	if players.has(peer_id):
		return
	var tray: Array[int] = []
	players[peer_id] = {
		"tray": tray, "preparing": -1, "prep_left": 0.0,
		"capacity": 3 if upgrades.tray > 0 else 1,
	}

func remove_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	var player: Dictionary = players[peer_id]
	clean_plates += player.tray.size() + int(player.preparing >= 0)
	players.erase(peer_id)
	last_event = "Player %d left; held plates returned." % peer_id

func act(peer_id: int, action: String, recipe: int = -1) -> String:
	if not players.has(peer_id):
		return _feedback("Join the kitchen before acting.")
	if shift_finished and action not in ["wash", "clear", "upgrade_tray", "upgrade_prep", "upgrade_washer"]:
		return _feedback("Shift finished. Clean up or start the next shift.")
	var player: Dictionary = players[peer_id]
	match action:
		"prepare":
			if recipe < 0 or recipe >= RECIPES.size():
				return _feedback("Choose a valid sushi recipe.")
			if player.preparing >= 0:
				return _feedback("Already preparing sushi.")
			if player.tray.size() >= int(player.capacity):
				return _feedback("Tray full. Load sushi onto the belt first.")
			if clean_plates <= 0:
				return _feedback("No clean plates. Wash dirty plates first.")
			clean_plates -= 1
			player.preparing = recipe
			player.prep_left = 0.65 if upgrades.prep > 0 else 1.5
			return _feedback("Preparing %s." % RECIPES[recipe])
		"load":
			if player.tray.is_empty():
				return _feedback("No ready sushi on your tray.")
			var ready_recipe: int = player.tray.pop_front()
			belt.append({"id": _next_plate_id, "recipe": ready_recipe, "t": 0.75, "age": 0.0, "stale": false})
			_next_plate_id += 1
			return _feedback("Loaded %s onto the belt." % RECIPES[ready_recipe])
		"wash":
			var count: int = dirty_plates if upgrades.washer > 0 else mini(3, dirty_plates)
			if count <= 0:
				return _feedback("No dirty plates to wash.")
			dirty_plates -= count
			clean_plates += count
			return _feedback("Washed %d plates." % count)
		"clear":
			var oldest_index: int = -1
			var oldest_age: float = -1.0
			for index in range(belt.size()):
				if bool(belt[index].stale) and float(belt[index].age) > oldest_age:
					oldest_index = index
					oldest_age = float(belt[index].age)
			if oldest_index < 0:
				return _feedback("No stale sushi to clear.")
			belt.remove_at(oldest_index)
			dirty_plates += 1
			wasted += 1
			return _feedback("Cleared the oldest stale sushi; plate needs washing.")
		"upgrade_tray", "upgrade_prep", "upgrade_washer":
			return _buy_upgrade(action.trim_prefix("upgrade_"))
		_:
			return _feedback("Unknown kitchen action.")

func _buy_upgrade(kind: String) -> String:
	if int(upgrades[kind]) > 0:
		return _feedback("%s upgrade already purchased." % kind.capitalize())
	var cost: int = UPGRADE_COSTS[kind]
	if money < cost:
		return _feedback("Need $%d for the %s upgrade." % [cost, kind])
	money -= cost
	upgrades[kind] = 1
	if kind == "tray":
		for player in players.values():
			player.capacity = 3
	return _feedback("Purchased %s upgrade for $%d." % [kind, cost])

func update(delta: float) -> void:
	if shift_finished or not is_finite(delta) or delta <= 0.0:
		return
	var elapsed: float = minf(delta, maxf(time_left, 0.0))
	for player in players.values():
		if int(player.preparing) >= 0:
			player.prep_left = maxf(0.0, float(player.prep_left) - elapsed)
			if float(player.prep_left) <= 0.0:
				player.tray.append(int(player.preparing))
				player.preparing = -1
				last_event = "Sushi ready! Load it onto the belt."

	# Generate fresh crossings, including every lap, then resolve in time order.
	# This avoids giving customer-array or plate-array order spatial priority.
	var crossings: Array[Dictionary] = []
	if belt_speed > 0.0:
		for plate_index in range(belt.size()):
			var plate: Dictionary = belt[plate_index]
			if bool(plate.stale) or float(plate.age) >= STALE_SECONDS:
				continue
			for customer_index in range(customers.size()):
				var distance: float = fposmod(float(customers[customer_index].t) - float(plate.t), 1.0)
				# Starting on a seat is not a new crossing until the next lap.
				if distance == 0.0:
					distance = 1.0
				var at: float = distance / belt_speed
				while at <= elapsed and float(plate.age) + at < STALE_SECONDS:
					crossings.append({"at": at, "plate": plate_index, "customer": customer_index})
					at += 1.0 / belt_speed
	crossings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.at) != float(b.at):
			return float(a.at) < float(b.at)
		if int(a.plate) != int(b.plate):
			return int(a.plate) < int(b.plate)
		return int(a.customer) < int(b.customer)
	)
	var consumed: Dictionary = {}
	var served_this_update: Dictionary = {}
	var cursor: float = 0.0
	for crossing in crossings:
		_advance_patience(float(crossing.at) - cursor)
		cursor = float(crossing.at)
		var plate_index: int = crossing.plate
		var customer_index: int = crossing.customer
		if consumed.has(plate_index) or served_this_update.has(customer_index):
			continue
		var plate: Dictionary = belt[plate_index]
		var customer: Dictionary = customers[customer_index]
		if int(plate.recipe) != int(customer.recipe):
			continue
		consumed[plate_index] = true
		served_this_update[customer_index] = true
		var value: int = RECIPE_VALUES[int(plate.recipe)]
		money += value
		total_earned += value
		shift_earned += value
		served += 1
		dirty_plates += 1
		customer.served = int(customer.served) + 1
		customer.patience = PATIENCE_SECONDS
		customer.recipe = (int(customer.recipe) + 1) % RECIPES.size()
		last_event = "Served %s! +$%d" % [RECIPES[int(plate.recipe)], value]
	_advance_patience(elapsed - cursor)

	# Remove backwards so the crossing indices stay valid until resolution ends.
	for index in range(belt.size() - 1, -1, -1):
		if consumed.has(index):
			belt.remove_at(index)
			continue
		var plate: Dictionary = belt[index]
		plate.t = fposmod(float(plate.t) + maxf(belt_speed, 0.0) * elapsed, 1.0)
		plate.age = float(plate.age) + elapsed
		plate.stale = bool(plate.stale) or float(plate.age) >= STALE_SECONDS
		if float(plate.age) >= DISCARD_SECONDS:
			belt.remove_at(index)
			dirty_plates += 1
			wasted += 1
			last_event = "Old sushi discarded; wash the dirty plate."

	time_left = maxf(0.0, time_left - elapsed)
	if time_left <= 0.0:
		shift_finished = true
		last_event = "Shift %d finished! Earned $%d. Clean up or begin the next shift." % [day, shift_earned]

func _advance_patience(delta: float) -> void:
	if delta <= 0.0:
		return
	for customer in customers:
		customer.patience = float(customer.patience) - delta
		while float(customer.patience) <= 0.0:
			customer.recipe = (int(customer.recipe) + 1) % RECIPES.size()
			customer.patience = float(customer.patience) + PATIENCE_SECONDS
			missed += 1

func next_shift() -> bool:
	if not shift_finished:
		return false
	day += 1
	time_left = SHIFT_SECONDS
	shift_finished = false
	shift_earned = 0
	last_event = "Shift %d: kitchen open!" % day
	return true

func snapshot() -> Dictionary:
	return {
		"money": money, "clean_plates": clean_plates, "dirty_plates": dirty_plates,
		"served": served, "wasted": wasted, "missed": missed, "day": day,
		"time_left": time_left, "shift_finished": shift_finished, "belt_speed": belt_speed,
		"belt": belt.duplicate(true), "customers": customers.duplicate(true),
		"players": players.duplicate(true), "upgrades": upgrades.duplicate(true),
		"last_event": last_event, "total_earned": total_earned, "shift_earned": shift_earned,
		"next_plate_id": _next_plate_id,
	}

func apply_snapshot(data: Dictionary) -> void:
	money = int(data.get("money", money))
	clean_plates = int(data.get("clean_plates", clean_plates))
	dirty_plates = int(data.get("dirty_plates", dirty_plates))
	served = int(data.get("served", served))
	wasted = int(data.get("wasted", wasted))
	missed = int(data.get("missed", missed))
	day = int(data.get("day", day))
	time_left = float(data.get("time_left", time_left))
	shift_finished = bool(data.get("shift_finished", shift_finished))
	belt_speed = float(data.get("belt_speed", belt_speed))
	last_event = str(data.get("last_event", last_event))
	total_earned = int(data.get("total_earned", total_earned))
	shift_earned = int(data.get("shift_earned", shift_earned))
	_next_plate_id = int(data.get("next_plate_id", _next_plate_id))
	if data.has("belt"):
		belt.assign(data.belt.duplicate(true))
	if data.has("customers"):
		customers.assign(data.customers.duplicate(true))
	if data.has("upgrades"):
		upgrades = data.upgrades.duplicate(true)
	if data.has("players"):
		players = {}
		for key in data.players:
			var player: Dictionary = data.players[key].duplicate(true)
			var tray: Array[int] = []
			for recipe in player.tray:
				tray.append(int(recipe))
			player.tray = tray
			player.preparing = int(player.preparing)
			player.prep_left = float(player.prep_left)
			player.capacity = int(player.capacity)
			players[int(key)] = player

func _feedback(message: String) -> String:
	last_event = message
	return message
