extends RefCounted
## Host-only care/physical rules. No simulation reference or hidden gameplay state.
## Every timer, intent and ownership link lives in the snapshotted dictionaries.
const FIRST_AID_POINT = Vector3(7.7, 1, 0)
const DOG_CARE_POINT = Vector3(-7.5, 0.5, 0.5)
const HEAVY_KG = 24.0
const HELPER_REACH = 2.6
const FLOOR = 0.04
const DOG_FLOOR = 0.3
const PATROL = [Vector3(-5, 0.3, 1.5), Vector3(0, 0.3, 2.5), Vector3(5, 0.3, 1.5), Vector3(0, 0.3, 0.5)]

func initialize(sim) -> void:
	_defaults(sim.dog, {"hunger": 15.0, "thirst": 15.0, "xp": 0, "mode": "stay", "follow_peer": 0, "patrol_index": 0, "velocity": Vector3.ZERO, "flight_age": 0.0, "scent_left": 0.0, "rest_left": 0.0, "last_thrower": 0})
	for player in sim.players.values():
		ensure_player(player)
	for bag in sim.bags.values():
		ensure_bag(bag)

func _defaults(entity: Dictionary, values: Dictionary) -> void:
	for key in values:
		if not entity.has(key):
			entity[key] = values[key]

func ensure_player(player: Dictionary) -> void:
	_defaults(player, {"health": 100.0, "stamina": 100.0, "sprinting": false, "crouching": false, "food": 0, "water": 0, "carry_partner": 0, "carry_bag": -1, "moving": false, "movement_left": 0.0, "jump_left": 0.0, "hurt_left": 0.0, "exhausted": false})

func ensure_bag(bag: Dictionary) -> void:
	_defaults(bag, {"carry_helpers": [], "damage": 0.0})

func _near(position: Vector3, target: Vector3, radius: float = 2.5) -> bool:
	return position.distance_to(target) <= radius

func _say(sim, message: String) -> String:
	sim.last_event = message
	return message

func act(sim, peer_id: int, action: String, target_id: int, extra: Variant) -> Variant:
	if not sim.players.has(peer_id):
		return null
	var player: Dictionary = sim.players[peer_id]
	ensure_player(player)
	match action:
		"movement":
			if not extra is Dictionary:
				return _say(sim, "Movement requires boolean intent.")
			for key in ["sprinting", "crouching", "jump", "moving"]:
				if typeof(extra.get(key)) != TYPE_BOOL:
					return _say(sim, "Movement requires boolean intent.")
			player.moving = extra.moving
			player.crouching = extra.crouching
			player.sprinting = extra.sprinting and extra.moving and not extra.crouching and not player.exhausted and player.stamina > 0.0 and player.health > 20.0
			player.movement_left = 0.4
			if extra.jump and player.jump_left <= 0.0 and player.stamina >= 12.0 and not player.crouching and player.health > 20.0:
				player.stamina = maxf(0.0, player.stamina - 12.0)
				player.jump_left = 0.75
			return "Movement accepted."
		"first_aid":
			if not _near(player.position, FIRST_AID_POINT):
				return _say(sim, "Visit the first-aid station.")
			player.health = 100.0
			player.hurt_left = 0.0
			return _say(sim, "First aid complete. Fit for baggage duty.")
		"take_food", "take_water":
			if not _near(player.position, DOG_CARE_POINT):
				return _say(sim, "Collect supplies at the dog care station.")
			var key: String = "food" if action == "take_food" else "water"
			# Finite carried portions, replenished at the rest station only.
			if int(player[key]) >= 3:
				return _say(sim, "You already carry three portions.")
			player[key] += 1
			return _say(sim, "Collected one %s portion." % key)
		"feed_dog", "water_dog", "rest_dog":
			if not _near(player.position, sim.dog.position, 2.7) or sim.dog.location == "airborne" or (sim.dog.location == "held" and int(sim.dog.held_by) != peer_id):
				return _say(sim, "Bring the available dog within reach.")
			if action == "rest_dog":
				if not _near(player.position, DOG_CARE_POINT) or sim.dog.location != "floor":
					return _say(sim, "Rest the dog on the floor at the care station.")
				sim.dog.rest_left = 8.0
				sim.dog.mode = "stay"
				sim.dog_goal = sim.dog.position
				return _say(sim, "Dog resting safely. Food and water still require portions.")
			var supply: String = "food" if action == "feed_dog" else "water"
			var need: String = "hunger" if action == "feed_dog" else "thirst"
			if int(player[supply]) <= 0:
				return _say(sim, "Collect a %s portion first." % supply)
			if float(sim.dog[need]) <= 0.0:
				return _say(sim, "The dog does not need that yet.")
			player[supply] -= 1
			sim.dog[need] = maxf(0.0, float(sim.dog[need]) - 55.0)
			return _say(sim, "Dog cared for; one %s portion consumed." % supply)
		"dog_mode":
			if typeof(extra) != TYPE_STRING or extra not in ["follow", "patrol", "stay"]:
				return _say(sim, "Choose dog follow, patrol, or stay.")
			sim.dog.mode = extra
			sim.dog.follow_peer = peer_id if extra == "follow" else 0
			sim.dog_goal = sim.dog.position
			return _say(sim, "Dog mode: %s." % extra)
		"throw_item", "throw_dog":
			return _throw(sim, peer_id, action, target_id, extra)
		"pickup_dog":
			if int(player.carry_bag) > 0:
				return _say(sim, "Leave the shared carry before using your hands.")
			if sim.dog.location == "airborne":
				return _say(sim, "Let the gentle dog arc land first.")
		"join_carry":
			return _join_carry(sim, peer_id, target_id)
		"leave_carry":
			var carried: Dictionary = _carried_bag(sim, player)
			if carried.is_empty():
				return _say(sim, "No shared carry to leave.")
			_release_carry(sim, carried)
			return _say(sim, "Shared bag lowered safely; both carriers released.")
		"pickup_bag", "pickup_item", "take_item", "catch_bag":
			if int(player.carry_bag) > 0:
				return _say(sim, "Leave the shared carry before using your hands.")
		"throw_bag":
			var held: Dictionary = _carried_bag(sim, player)
			if not held.is_empty() and (not held.get("carry_helpers", []).is_empty() or (float(held.get("mass_kg", 0.0)) > HEAVY_KG and sim.players.size() > 1)):
				return _say(sim, "Lower heavy shared baggage gently; no two-person throws.")
		"route":
			var held: Dictionary = _carried_bag(sim, player)
			if not held.is_empty() and not held.get("carry_helpers", []).is_empty():
				# Core alone validates/rewards routing; remove links atomically only
				# after a successful route, before its resulting snapshot is sent.
				var response: String = sim._core_act(peer_id, action, target_id, extra)
				if held.location != "held":
					_unlink_helpers(sim, held)
				return response
		"place_bag":
			var held: Dictionary = _carried_bag(sim, player)
			if int(player.carry_bag) > 0:
				_release_carry(sim, held)
				return _say(sim, "Shared bag lowered safely.")
			if not held.is_empty() and extra is Dictionary and sim._valid_placement(extra):
				_unlink_helpers(sim, held)
	return null

func _carried_bag(sim, player: Dictionary) -> Dictionary:
	if int(player.get("carry_bag", -1)) > 0:
		return sim.bags.get(int(player.carry_bag), {})
	if player.get("held_kind", "") == "bag":
		return sim.bags.get(int(player.held_id), {})
	return {}

func _join_carry(sim, peer_id: int, bag_id: int) -> String:
	var bag: Dictionary = sim.bags.get(bag_id, {})
	var player: Dictionary = sim.players[peer_id]
	if bag.is_empty() or bag.location != "held" or float(bag.mass_kg) <= HEAVY_KG:
		return _say(sim, "A primary carrier must lift a bag over 24 kg first.")
	ensure_bag(bag)
	var owner: int = int(bag.held_by)
	if owner == peer_id or not sim.players.has(owner) or player.held_kind != "" or int(player.carry_bag) > 0 or not bag.carry_helpers.is_empty():
		return _say(sim, "Use empty hands; this bag needs exactly two distinct carriers.")
	var primary: Dictionary = sim.players[owner]
	if primary.held_kind != "bag" or int(primary.held_id) != bag_id or not _near(player.position, primary.position, HELPER_REACH):
		return _say(sim, "Stand beside the bag's primary carrier.")
	bag.carry_helpers.append(peer_id)
	primary.carry_partner = peer_id
	player.carry_partner = owner
	player.carry_bag = bag_id
	return _say(sim, "Two-person carry ready. Stay close; either carrier can lower it.")

func _unlink_helpers(sim, bag: Dictionary) -> void:
	for id in bag.get("carry_helpers", []):
		if sim.players.has(id):
			var primary_id: int = int(sim.players[id].get("carry_partner", 0))
			if sim.players.has(primary_id) and int(sim.players[primary_id].get("carry_partner", 0)) == int(id):
				sim.players[primary_id].carry_partner = 0
			sim.players[id].carry_partner = 0
			sim.players[id].carry_bag = -1
	bag.carry_helpers = []
	var owner: int = int(bag.get("held_by", 0))
	if sim.players.has(owner):
		sim.players[owner].carry_partner = 0

func _release_carry(sim, bag: Dictionary) -> void:
	if bag.is_empty():
		return
	var owner: int = int(bag.get("held_by", 0))
	_unlink_helpers(sim, bag)
	if bag.location == "held" and sim.players.has(owner):
		var player: Dictionary = sim.players[owner]
		if player.held_kind == "bag" and int(player.held_id) == int(bag.id):
			player.held_kind = ""
			player.held_id = -1
			bag.position = _bounded(player.position, FLOOR)
			bag.location = "floor"
			bag.held_by = 0
			bag.velocity = Vector3.ZERO
			bag.angular_velocity = Vector3.ZERO
			bag.off_belt = true

func remove_player(sim, peer_id: int) -> void:
	if sim.players.has(peer_id):
		var bag: Dictionary = _carried_bag(sim, sim.players[peer_id])
		if not bag.is_empty():
			_release_carry(sim, bag)
	if int(sim.dog.get("follow_peer", 0)) == peer_id:
		sim.dog.follow_peer = 0
		sim.dog.mode = "stay"
		sim.dog_goal = sim.dog.position

func carry_multiplier(sim, peer_id: int) -> float:
	var player: Dictionary = sim.players.get(peer_id, {})
	if player.is_empty():
		return 1.0
	var result: float = 0.65 if float(player.get("health", 100.0)) < 35.0 else 1.0
	var bag: Dictionary = _carried_bag(sim, player)
	if bag.is_empty() or float(bag.get("mass_kg", 0.0)) <= HEAVY_KG:
		return result
	if sim.players.size() == 1:
		return result * 0.3 # Honest solo slow drag fallback, not a fictitious helper.
	if bag.get("carry_helpers", []).size() != 1:
		return 0.0
	var owner: Dictionary = sim.players.get(int(bag.held_by), {})
	var helper: Dictionary = sim.players.get(int(bag.carry_helpers[0]), {})
	if owner.is_empty() or helper.is_empty() or not _near(owner.position, helper.position, HELPER_REACH):
		return 0.0
	# Core applies mass drag to the primary's held bag, but a helper keeps
	# empty hands. Apply that same factor here so both walk at equal speed.
	if int(player.get("carry_bag", -1)) > 0:
		result *= clampf(1.0 - float(bag.mass_kg) / 70.0, 0.55, 0.92)
	return result * 0.85

func update(sim, delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	for player in sim.players.values():
		ensure_player(player)
		var intent_time: float = minf(delta, float(player.movement_left))
		player.movement_left = maxf(0.0, float(player.movement_left) - delta)
		player.jump_left = maxf(0.0, float(player.jump_left) - delta)
		player.hurt_left = maxf(0.0, float(player.hurt_left) - delta)
		var drain: float = 0.0
		if player.moving:
			drain = 19.0 if player.sprinting else (4.0 if not _carried_bag(sim, player).is_empty() else 0.0)
		if drain > 0.0:
			player.stamina = clampf(float(player.stamina) - drain * intent_time + 13.0 * (delta - intent_time), 0.0, 100.0)
		else:
			player.stamina = minf(100.0, float(player.stamina) + 13.0 * delta)
		if player.stamina <= 0.0:
			player.exhausted = true
		if player.stamina >= 22.0:
			player.exhausted = false
		if player.exhausted or player.movement_left <= 0.0:
			player.sprinting = false
		if player.movement_left <= 0.0:
			player.moving = false
	for bag in sim.bags.values():
		ensure_bag(bag)
		if not bag.carry_helpers.is_empty():
			var owner: Dictionary = sim.players.get(int(bag.held_by), {})
			var helper: Dictionary = sim.players.get(int(bag.carry_helpers[0]), {})
			if bag.location != "held":
				_unlink_helpers(sim, bag)
			elif owner.is_empty() or helper.is_empty() or not _near(owner.position, helper.position, HELPER_REACH):
				_release_carry(sim, bag)
		for item in bag.get("items", []):
			if item.get("location", "") == "airborne":
				_update_prop(sim, item, delta, false)
	_update_piles(sim, delta)

func _valid_vector(value: Variant) -> bool:
	return typeof(value) == TYPE_VECTOR3 and value.is_finite()

func _throw(sim, peer_id: int, action: String, target_id: int, extra: Variant) -> String:
	var player: Dictionary = sim.players[peer_id]
	var kind: String = "dog" if action == "throw_dog" else "item"
	if player.held_kind != kind or int(player.carry_bag) > 0 or (kind == "item" and target_id != -1 and target_id != int(player.held_id)):
		return _say(sim, "Only your own held %s can be tossed." % kind)
	var entity: Dictionary = sim.dog if kind == "dog" else sim.get_item(int(player.held_id))
	if entity.is_empty() or entity.location != "held" or int(entity.held_by) != peer_id:
		return _say(sim, "Carry your own %s first." % kind)
	if kind == "item" and entity.get("category", "") in ["pet", "wildlife", "safeguarding"]:
		return _say(sim, "Keep animal carriers and safeguarding cases safe.")
	if not extra is Dictionary or not _valid_vector(extra.get("origin")) or not _valid_vector(extra.get("direction")):
		return _say(sim, "Throw requires a finite origin and unit aim direction.")
	var origin: Vector3 = extra.origin
	var direction: Vector3 = extra.direction
	if absf(direction.length_squared() - 1.0) > 0.001 or origin.distance_to(player.position) > 2.0 or absf(origin.x) > 10.0 or origin.z < -4.9 or origin.z > 6.0 or origin.y < 0.04 or origin.y > 3.0:
		return _say(sim, "Throw from your own reachable position with a unit direction.")
	var mass: float = maxf(0.1, float(entity.get("mass_kg", 1.0)))
	entity.position = _bounded(origin, DOG_FLOOR if kind == "dog" else FLOOR)
	entity.velocity = direction * minf(8.0, 13.0 / mass) + Vector3.UP * 2.6
	if kind == "dog":
		# Fictional harmless cartoon hop: no animal damage, no client strength.
		entity.velocity = Vector3(direction.x, 0, direction.z).limit_length(1.0) * 2.2 + Vector3.UP * 2.8
		entity.rest_left = 0.0
	entity.location = "airborne"
	entity.held_by = 0
	entity.flight_age = 0.0
	entity.last_thrower = peer_id
	player.held_kind = ""
	player.held_id = -1
	return _say(sim, "Gentle harmless cartoon dog hop!" if kind == "dog" else "Item thrown; watch your colleagues.")

func _bounded(point: Vector3, floor_y: float) -> Vector3:
	return Vector3(clampf(point.x, -9.8, 9.8), maxf(point.y, floor_y), clampf(point.z, -4.7, 5.8))

func _sweep(sim, from: Vector3, to: Vector3, entity: Dictionary) -> Dictionary:
	if sim.collision_query.is_valid():
		var result: Variant = sim.collision_query.call(from, to, entity)
		if result is Dictionary and _valid_vector(result.get("position")) and _valid_vector(result.get("normal")):
			var normal: Vector3 = result.normal
			if normal.length_squared() > 0.001 and (to - from).dot(normal) < -0.000001:
				return {"position": result.position, "normal": normal.normalized()}
	return {}

func _update_prop(sim, entity: Dictionary, delta: float, harmless: bool) -> void:
	var remaining: float = delta
	var floor_y: float = DOG_FLOOR if harmless else FLOOR
	while remaining > 0.0000001 and entity.location == "airborne":
		var step: float = minf(remaining, 1.0 / 120.0)
		remaining -= step
		var from: Vector3 = entity.position
		var velocity: Vector3 = entity.get("velocity", Vector3.ZERO)
		var to: Vector3 = from + velocity * step + Vector3.DOWN * 4.905 * step * step
		velocity.y -= 9.81 * step
		entity.flight_age = float(entity.get("flight_age", 0.0)) + step
		if not harmless:
			_hurt_on_path(sim, entity, from, to, velocity.length())
		var hit: Dictionary = _sweep(sim, from, to, entity)
		if not hit.is_empty():
			to = hit.position + hit.normal * 0.01
			velocity = velocity.slide(hit.normal) * 0.35
			if hit.normal.y > 0.5:
				entity.location = "floor"
		var bounded: Vector3 = _bounded(to, floor_y)
		if bounded.x != to.x:
			velocity.x = -velocity.x * 0.2
		if bounded.z != to.z:
			velocity.z = -velocity.z * 0.2
		if to.y <= floor_y:
			entity.location = "floor"
		entity.position = bounded
		entity.velocity = velocity if entity.location == "airborne" else Vector3.ZERO
		if harmless and entity.location == "floor":
			sim.dog_goal = bounded

func _hurt_on_path(sim, entity: Dictionary, from: Vector3, to: Vector3, speed: float) -> void:
	if speed < 3.5:
		return
	for id in sim.players:
		var player: Dictionary = sim.players[id]
		ensure_player(player)
		if player.hurt_left > 0.0 or (id == int(entity.get("last_thrower", 0)) and float(entity.get("flight_age", 0.0)) < 0.35):
			continue
		var center: Vector3 = player.position + Vector3.UP * 0.65
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(center, from, to)
		if center.distance_to(closest) <= 0.8:
			var loss: float = clampf((speed - 3.0) * sqrt(maxf(0.1, float(entity.get("mass_kg", 1.0)))) * 1.8, 1.0, 42.0)
			player.health = maxf(0.0, float(player.health) - loss)
			player.hurt_left = 0.8
			player.sprinting = false

func impact(sim, bag: Dictionary, speed: float) -> void:
	if not is_finite(speed) or speed <= 0.0:
		return
	ensure_bag(bag)
	bag.damage = clampf(float(bag.damage) + maxf(0.0, speed - 2.8) * sqrt(maxf(1.0, float(bag.get("mass_kg", 8.0)))) * 0.7, 0.0, 100.0)
	var point: Vector3 = bag.get("position", Vector3.ZERO)
	_hurt_on_path(sim, bag, point, point, speed)

func _extent(bag: Dictionary) -> Vector3:
	var size: int = clampi(int(bag.get("size", 0)), 0, 2)
	return [Vector3(0.35, 0.48, 0.25), Vector3(0.43, 0.58, 0.3), Vector3(0.55, 0.72, 0.35)][size]

func _update_piles(sim, delta: float) -> void:
	var bodies: Array = []
	for bag in sim.bags.values():
		if bag.location in ["floor", "airborne"]:
			bodies.append(bag)
		if bag.location == "airborne":
			var from: Vector3 = bag.position
			_hurt_on_path(sim, bag, from, from + bag.velocity * delta, (bag.velocity as Vector3).length())
	bodies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.position.y < b.position.y if a.position.y != b.position.y else int(a.id) < int(b.id))
	for iteration in range(3):
		for i in range(bodies.size()):
			var a: Dictionary = bodies[i]
			var ea: Vector3 = _extent(a)
			for j in range(i + 1, bodies.size()):
				var b: Dictionary = bodies[j]
				var eb: Vector3 = _extent(b)
				var difference: Vector3 = b.position - a.position
				var overlap_x: float = ea.x + eb.x - absf(difference.x)
				var overlap_z: float = ea.z + eb.z - absf(difference.z)
				if overlap_x <= 0.0 or overlap_z <= 0.0 or difference.y >= ea.y or difference.y + eb.y <= 0.0:
					continue
				if difference.y > 0.18:
					impact(sim, b, absf((b.velocity as Vector3).y))
					b.position.y = a.position.y + ea.y
					b.velocity = Vector3.ZERO
					b.angular_velocity = Vector3.ZERO
					b.location = "floor"
				else:
					var axis: Vector3 = Vector3.RIGHT if overlap_x < overlap_z else Vector3.BACK
					var sign_value: float = 1.0 if difference.dot(axis) >= 0.0 else -1.0
					var normal: Vector3 = axis * sign_value
					var relative_speed: float = maxf(0.0, ((a.velocity as Vector3) - (b.velocity as Vector3)).dot(normal))
					if relative_speed > 0.0:
						impact(sim, a, relative_speed)
						impact(sim, b, relative_speed)
						if a.location == "airborne" and (a.velocity as Vector3).dot(normal) > 0.0:
							a.velocity -= normal * (a.velocity as Vector3).dot(normal) * 1.2
						if b.location == "airborne" and (b.velocity as Vector3).dot(normal) < 0.0:
							b.velocity -= normal * (b.velocity as Vector3).dot(normal) * 1.2
					var shift: Vector3 = normal * (minf(overlap_x, overlap_z) + 0.002) * 0.5
					a.position = _bounded(a.position - shift, FLOOR)
					b.position = _bounded(b.position + shift, FLOOR)
	# Unsupported pile members really fall when the supporting bag is removed.
	for bag in bodies:
		if bag.location != "floor":
			continue
		var support: float = FLOOR
		# Reuse the host's room sweep: a bag resting on a desk is not an
		# unsupported stack. A short upward margin retains its contact skin.
		var fall_to: Vector3 = Vector3(bag.position.x, maxf(FLOOR - 0.01, bag.position.y - 3.5 * delta), bag.position.z)
		var surface: Dictionary = _sweep(sim, bag.position + Vector3.UP * 0.03, fall_to, bag)
		if not surface.is_empty() and surface.normal.y > 0.5 and surface.position.y <= bag.position.y + 0.03:
			support = maxf(support, float(surface.position.y))
		for other in bodies:
			if other == bag or other.position.y >= bag.position.y:
				continue
			var d: Vector3 = bag.position - other.position
			var ext: Vector3 = _extent(other)
			var own: Vector3 = _extent(bag)
			if absf(d.x) < ext.x + own.x and absf(d.z) < ext.z + own.z and other.position.y + ext.y <= bag.position.y + 0.01:
				support = maxf(support, other.position.y + ext.y)
		bag.position.y = move_toward(float(bag.position.y), support, 3.5 * delta)

func update_dog(sim, delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	var dog: Dictionary = sim.dog
	var resting: bool = float(dog.rest_left) > 0.0
	dog.hunger = minf(100.0, float(dog.hunger) + delta * (0.06 if resting else 0.16))
	dog.thirst = minf(100.0, float(dog.thirst) + delta * (0.1 if resting else 0.24))
	dog.rest_left = maxf(0.0, float(dog.rest_left) - delta)
	dog.bark_left = maxf(0.0, float(dog.bark_left) - delta)
	dog.scent_left = maxf(0.0, float(dog.scent_left) - delta)
	if dog.location == "airborne":
		_update_prop(sim, dog, delta, true)
	elif dog.location == "belt" and sim.belt_running:
		dog.t = float(dog.t) + sim.BELT_SPEED * delta
		dog.position = Vector3(-8 + 16 * float(dog.t), 1.14, -2)
		if not dog.scanned and float(dog.t) >= 0.45:
			dog.scanned = true
			sim.dog_scan_count += 1
			dog.xp += 10
			sim.last_event = "VERY GOOD BOY — harmless training scan! +10 dog XP."
		if float(dog.t) > 0.75:
			dog.location = "floor"
			dog.position = Vector3(4, DOG_FLOOR, -1)
			sim.dog_goal = dog.position
	elif dog.location == "floor" and not resting:
		_dog_walk(sim, delta)
	if dog.location not in ["floor", "belt"] or resting or dog.scent_left > 0.0:
		return
	dog.scent_left = 2.0
	var training: float = clampf(float(dog.xp) / 100.0, 0.0, 1.0)
	var kennel: float = float(sim.upgrades.get("kennel", 0))
	var needs: float = (float(dog.hunger) + float(dog.thirst)) / 200.0
	var radius: float = 3.0 + kennel * 2.0
	for bag in sim.bags.values():
		if bag.location == "sorted" or bag.get("dog_alert", false) or (dog.position as Vector3).distance_to(sim.bag_position(bag)) > radius:
			continue
		var truth: bool = bag.get("category", "legal") in ["narcotics", "organic", "weapons", "explosives", "dangerous", "wildlife", "pet", "safeguarding"]
		var probability: float = clampf(0.58 + 0.25 * training + 0.12 * kennel - 0.35 * needs, 0.12, 0.95) if truth else clampf(0.18 - 0.12 * training - 0.06 * kennel + 0.27 * needs, 0.015, 0.55)
		if _scent_roll(sim) < probability:
			bag.dog_alert = true
			dog.alerts += 1
			dog.alert_bag = bag.id
			dog.bark_left = 1.5
			sim.last_event = "Woof! Inspect bag %d; an alert is not a conviction." % bag.id

func _scent_roll(sim) -> float:
	# Prefer the core's seedable RNG. Fallback has no persistent helper state.
	for property in sim.get_property_list():
		if property.name in ["rng", "_rng"]:
			var generator: Variant = sim.get(property.name)
			if generator is RandomNumberGenerator:
				return generator.randf()
	var fallback = RandomNumberGenerator.new()
	fallback.randomize()
	return fallback.randf()

func _dog_walk(sim, delta: float) -> void:
	var dog: Dictionary = sim.dog
	var goal: Vector3 = sim.dog_goal
	if dog.mode == "follow":
		var player: Dictionary = sim.players.get(int(dog.follow_peer), {})
		if player.is_empty():
			dog.mode = "stay"
		else:
			goal = _bounded(player.position + Vector3(0, 0, 1.0), DOG_FLOOR)
	elif dog.mode == "patrol":
		goal = PATROL[int(dog.patrol_index) % PATROL.size()]
		if (dog.position as Vector3).distance_to(goal) < 0.3:
			dog.patrol_index = (int(dog.patrol_index) + 1) % PATROL.size()
			goal = PATROL[int(dog.patrol_index)]
	goal = _bounded(goal, DOG_FLOOR)
	goal.y = DOG_FLOOR
	sim.dog_goal = goal
	var from: Vector3 = dog.position
	var speed: float = 1.8 * (0.6 if maxf(float(dog.hunger), float(dog.thirst)) > 75.0 else 1.0)
	var to: Vector3 = from.move_toward(goal, speed * delta)
	var hit: Dictionary = _sweep(sim, from, to, dog)
	if not hit.is_empty():
		to = from # No wall-crossing teleport; patrol chooses its next safe waypoint.
		if dog.mode == "patrol":
			dog.patrol_index = (int(dog.patrol_index) + 1) % PATROL.size()
	# Without a scene sweep, patrol stays in the room's known clear operator lane.
	elif not sim.collision_query.is_valid() and dog.mode == "follow":
		to.z = maxf(to.z, 0.5)
	dog.velocity = (to - from) / delta if delta > 0.0 else Vector3.ZERO
	dog.position = _bounded(to, DOG_FLOOR)
