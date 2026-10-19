class_name SushiChef
extends CharacterBody3D
## Local first-person controller; remote chefs are presentation-only avatars.

var camera: Camera3D
var hand: Node3D
var input_enabled = true
var movement_multiplier: float = 1.0
var automated = false
var walk_target = Vector3.ZERO
var walking = false
var aim_target = Vector3.ZERO
var aiming = false
const SPEED = 3.4

func _ready() -> void:
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.85
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.fov = 80
	camera.near = 0.05
	add_child(camera)
	camera.current = true
	hand = Node3D.new()
	hand.position = Vector3(0.38, -0.38, -0.72)
	hand.rotation.x = 0.12
	camera.add_child(hand)
	if not automated:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or automated:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.0025
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.0025, -1.15, 1.15)

func _physics_process(delta: float) -> void:
	var direction = Vector3.ZERO
	if input_enabled:
		if automated:
			if walking:
				direction = walk_target - position
				direction.y = 0
				if direction.length() < 0.08:
					walking = false
				else:
					direction = direction.normalized()
		else:
			var axes = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			direction = basis * Vector3(axes.x, 0, axes.y)
			rotation.y += Input.get_axis("look_right", "look_left") * delta * 1.7
			camera.rotation.x = clampf(camera.rotation.x + Input.get_axis("look_down", "look_up") * delta, -1.15, 1.15)
	velocity.x = direction.x * SPEED * movement_multiplier
	velocity.z = direction.z * SPEED * movement_multiplier
	velocity.y -= 18.0 * delta
	move_and_slide()
	if automated and aiming:
		face(aim_target, minf(1, delta * 6.0))

func face(at: Vector3, blend: float = 1.0) -> void:
	var direction = (at - camera.global_position).normalized()
	var target_yaw = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, blend)
	camera.rotation.x = lerp_angle(camera.rotation.x, asin(clampf(direction.y, -1, 1)), blend)

func navigate(at: Vector3, look_at_point: Vector3) -> void:
	walk_target = at
	walking = true
	aim_target = look_at_point
	aiming = true
