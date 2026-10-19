class_name AirportChef
extends SushiChef
## Airport-only movement. Stamina/health are copied from the authoritative model;
## this controller never regenerates or independently spends that shared budget.

const SPRINT_ACTION = "airport_sprint"
const CROUCH_ACTION = "airport_crouch"
const JUMP_ACTION = "airport_jump"
const STAND_HEIGHT = 1.7
const CROUCH_HEIGHT = 1.0
const JUMP_STAMINA = 12.0
const JUMP_SPEED = 6.0
var stamina: float = 100.0
var health: float = 100.0
var sprinting: bool = false
var crouching: bool = false
# Latched until AirportGame reports it to the model and clears it.
var requested_jump: bool = false
var _jump_pressed = false
var _exhausted = false
var _jump_cooldown = 0.0
var _body_shape: CollisionShape3D
var _standing_shape: CapsuleShape3D

func _ready() -> void:
	super._ready()
	_bind_key(SPRINT_ACTION, KEY_SHIFT)
	_bind_key(CROUCH_ACTION, KEY_CTRL)
	_bind_key(JUMP_ACTION, KEY_SPACE)
	for child in get_children():
		if child is CollisionShape3D:
			_body_shape = child
			break
	_standing_shape = _body_shape.shape.duplicate()
	# A small floor clearance prevents the grounded capsule from blocking itself.
	_standing_shape.height = STAND_HEIGHT - 0.02

func _bind_key(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event = InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or automated:
		return
	if event.is_action_pressed(JUMP_ACTION) and not event.is_echo():
		_jump_pressed = true
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity = 0.0025 * float(Engine.get_meta("airport_mouse_sensitivity", 1.0))
		rotation.y -= event.relative.x * sensitivity
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity, -1.15, 1.15)

func _physics_process(delta: float) -> void:
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	if stamina <= 0.0: _exhausted = true
	elif stamina >= 22.0: _exhausted = false
	var direction = Vector3.ZERO
	if input_enabled:
		if automated:
			if walking:
				direction = walk_target - position
				direction.y = 0
				if direction.length() < 0.08:
					walking = false
					direction = Vector3.ZERO
				else:
					direction = direction.normalized()
		else:
			var axes = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			direction = basis * Vector3(axes.x, 0, axes.y)
			rotation.y += Input.get_axis("look_right", "look_left") * delta * 1.7
			camera.rotation.x = clampf(camera.rotation.x + Input.get_axis("look_down", "look_up") * delta, -1.15, 1.15)
	_set_crouching(input_enabled and not automated and Input.is_action_pressed(CROUCH_ACTION))
	sprinting = input_enabled and not automated and not crouching and not _exhausted and stamina > 0.0 and health > 20.0 and direction.length_squared() > 0.01 and Input.is_action_pressed(SPRINT_ACTION)
	var pace = 0.55 if crouching else (1.6 if sprinting else 1.0)
	var injury = lerpf(0.45, 1.0, clampf(health / 100.0, 0.0, 1.0))
	velocity.x = direction.x * SPEED * movement_multiplier * pace * injury
	velocity.z = direction.z * SPEED * movement_multiplier * pace * injury
	if _jump_pressed and input_enabled and not crouching and not _exhausted and _jump_cooldown <= 0.0 and is_on_floor() and stamina >= JUMP_STAMINA and health > 20.0:
		velocity.y = JUMP_SPEED
		requested_jump = true
		_jump_cooldown = 0.75
	_jump_pressed = false
	velocity.y -= 18.0 * delta
	move_and_slide()
	if automated and aiming:
		face(aim_target, minf(1.0, delta * 6.0))

func _set_crouching(wanted: bool) -> void:
	if not wanted and crouching and not _can_stand():
		wanted = true
	if crouching == wanted:
		return
	crouching = wanted
	var height = CROUCH_HEIGHT if crouching else STAND_HEIGHT
	_body_shape.shape.height = height
	_body_shape.position.y = height * 0.5
	camera.position.y = 0.92 if crouching else 1.62

func _can_stand() -> bool:
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = _standing_shape
	query.transform = global_transform.translated(Vector3.UP * (STAND_HEIGHT * 0.5 + 0.01))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
