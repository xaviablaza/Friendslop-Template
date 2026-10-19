class_name SushiRoom
extends Node3D
## Primitive-only restaurant geometry and reusable sushi meshes.

const FOOD_COLORS = [Color("ef977b"), Color("ba6674"), Color("91b99a")]
const INK = Color("293c43")
const STEEL = Color("a1afb1")
const CREAM = Color("e4dfd0")
const STATIONS = [Vector3(-2.35, 1.0, -1.4), Vector3(-2.35, 1.0, 0), Vector3(-2.35, 1.0, 1.4)]
const LOAD_POINT = Vector3(0, 1.1, -3.6)
const WASH_POINT = Vector3(2.25, 1, -0.3)
const SHOP_POINT = Vector3(2.15, 1, 1.6)
var customer_labels: Array[Label3D] = []
var customer_lights: Array[MeshInstance3D] = []
var belt_markers: Array[Node3D] = []
var wash_stack: Node3D

static func belt_position(t: float) -> Vector3:
	return Vector3(cos(t * TAU) * 5.0, 1.14, sin(t * TAU) * 3.6)

static func material(color: Color) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	return result

func box(at: Vector3, size: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var mesh_node = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh_node.mesh = shape
	mesh_node.material_override = material(color)
	mesh_node.position = at
	add_child(mesh_node)
	if solid:
		var body = StaticBody3D.new()
		var collision = CollisionShape3D.new()
		var bounds = BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		body.add_child(collision)
		mesh_node.add_child(body)
	return mesh_node

func cylinder(at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	node.mesh = mesh
	node.material_override = material(color)
	node.position = at
	add_child(node)
	return node

func sign_at(text: String, at: Vector3, size: int = 36, color: Color = CREAM) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.position = at
	label.font_size = size
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_modulate = INK
	label.outline_size = 5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	add_child(label)
	return label

func build() -> void:
	var world = WorldEnvironment.new()
	var environment_settings = Environment.new()
	environment_settings.background_mode = Environment.BG_COLOR
	environment_settings.background_color = Color("c0c8c5")
	environment_settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_settings.ambient_light_color = Color("e4ecea")
	environment_settings.ambient_light_energy = 0.35
	environment_settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment_settings
	add_child(world)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-65, -30, 0)
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	add_child(sun)
	box(Vector3(0, -0.12, 0), Vector3(19, 0.24, 15), Color("c8cbc3"), true)
	for x in range(-9, 10):
		box(Vector3(x, 0.005, 0), Vector3(0.012, 0.01, 15), Color("acb3ad"))
	for z in range(-7, 8):
		box(Vector3(0, 0.005, z), Vector3(19, 0.01, 0.012), Color("acb3ad"))
	box(Vector3(0, 1.8, -7.4), Vector3(19, 3.6, 0.2), CREAM, true)
	box(Vector3(-9.4, 1.8, 0), Vector3(0.2, 3.6, 15), CREAM, true)
	box(Vector3(9.4, 1.8, 0), Vector3(0.2, 3.6, 15), CREAM, true)
	box(Vector3(0, 1.8, 7.4), Vector3(19, 3.6, 0.2), CREAM, true)
	box(Vector3(0, 1.0, -7.23), Vector3(18.8, 0.15, 0.05), INK)
	box(Vector3(0, 2.8, -7.23), Vector3(8, 0.75, 0.05), INK)
	sign_at("BELT BEHAVIOUR", Vector3(0, 2.85, -7.1), 70)
	sign_at("REVOLVING SUSHI / GRAYBOX 01", Vector3(0, 2.35, -7.1), 26, INK)
	for i in range(96):
		var t = float(i) / 96.0
		var at = belt_position(t)
		var tangent = (belt_position(t + 0.001) - at).normalized()
		var segment = box(at - Vector3(0, 0.22, 0), Vector3(0.9, 0.35, 0.39), STEEL, true)
		segment.rotation.y = atan2(tangent.x, tangent.z)
		var belt = box(at - Vector3(0, 0.025, 0), Vector3(0.76, 0.04, 0.4), INK.lightened(0.08 if i % 2 == 0 else 0.0))
		belt.rotation.y = segment.rotation.y
		if i % 8 == 0:
			cylinder(at - Vector3(0, 0.69, 0), 0.10, 0.85, INK)
	for i in range(24):
		var marker = box(Vector3.ZERO, Vector3(0.11, 0.018, 0.32), Color("d7b966"))
		belt_markers.append(marker)
	for i in range(3):
		var at: Vector3 = STATIONS[i]
		box(at - Vector3(0, 0.53, 0), Vector3(1.0, 0.92, 1.12), STEEL, true)
		box(at, Vector3(1.08, 0.1, 1.18), INK)
		box(at + Vector3(0, 0.1, 0), Vector3(0.65, 0.13, 0.75), FOOD_COLORS[i])
		sign_at(["SALMON / $8", "TUNA / $10", "CUCUMBER / $6"][i], at + Vector3(0, 0.65, 0), 29, FOOD_COLORS[i])
		var sample = plate(i)
		sample.position = at + Vector3(0, 0.2, 0)
		add_child(sample)
	box(WASH_POINT - Vector3(0, 0.5, 0), Vector3(1.3, 1, 1.3), STEEL, true)
	box(WASH_POINT, Vector3(1.16, 0.06, 1.1), INK)
	box(WASH_POINT + Vector3(0, 0.03, 0), Vector3(0.85, 0.035, 0.8), Color("81aab2"))
	sign_at("PLATE RETURN\nWASH / REUSE", WASH_POINT + Vector3(0, 0.85, 0), 31)
	wash_stack = Node3D.new()
	wash_stack.position = WASH_POINT + Vector3(0, 0.12, 0)
	add_child(wash_stack)
	box(SHOP_POINT - Vector3(0, 0.5, 0), Vector3(1.1, 1.0, 0.8), STEEL, true)
	box(SHOP_POINT + Vector3(0, 0.2, 0), Vector3(0.8, 0.5, 0.12), INK)
	sign_at("UPGRADES", SHOP_POINT + Vector3(0, 0.75, 0), 34, Color("e3c575"))
	sign_at("LOAD BELT [E]\nCLEAR STALE [F]", LOAD_POINT + Vector3(0, 0.65, 0), 32, Color("e3c575"))
	for i in range(4):
		var at = belt_position([0.125, 0.375, 0.625, 0.875][i])
		var outward = Vector3(at.x, 0, at.z).normalized()
		var seat = at + outward * 1.05
		cylinder(Vector3(seat.x, 0.55, seat.z), 0.32, 0.12, INK)
		cylinder(Vector3(seat.x, 0.28, seat.z), 0.07, 0.5, STEEL)
		var body = cylinder(Vector3(seat.x, 1.05, seat.z), 0.23, 0.65, Color("778e92"))
		body.name = "Customer%d" % (i + 1)
		cylinder(Vector3(seat.x, 1.58, seat.z), 0.2, 0.32, Color("c9b5a3"))
		var label = sign_at("", Vector3(seat.x, 2.35, seat.z), 34)
		customer_labels.append(label)
		customer_lights.append(cylinder(at + Vector3(0, 0.015, 0), 0.09, 0.04, FOOD_COLORS[i % 3]))

static func plate(recipe: int, stale: bool = false) -> Node3D:
	var root = Node3D.new()
	var dish = MeshInstance3D.new()
	var disc = CylinderMesh.new()
	disc.top_radius = 0.28
	disc.bottom_radius = 0.24
	disc.height = 0.045
	disc.radial_segments = 24
	dish.mesh = disc
	dish.material_override = material(Color("777c73") if stale else FOOD_COLORS[recipe].lightened(0.4))
	root.add_child(dish)
	for offset in [-0.12, 0.12]:
		var rice = MeshInstance3D.new()
		var rice_mesh = BoxMesh.new()
		rice_mesh.size = Vector3(0.18, 0.10, 0.30)
		rice.mesh = rice_mesh
		rice.material_override = material(Color("d9d4bd"))
		rice.position = Vector3(offset, 0.07, 0)
		root.add_child(rice)
		var topping = MeshInstance3D.new()
		var topping_mesh = BoxMesh.new()
		topping_mesh.size = Vector3(0.20, 0.045, 0.32)
		topping.mesh = topping_mesh
		topping.material_override = material(Color("64705e") if stale else FOOD_COLORS[recipe])
		topping.position = Vector3(offset, 0.14, 0)
		root.add_child(topping)
	return root

func animate_belt(clock: float, speed: float) -> void:
	for i in range(belt_markers.size()):
		var t = fposmod(float(i) / belt_markers.size() + clock * speed, 1.0)
		belt_markers[i].position = belt_position(t) + Vector3(0, -0.015, 0)
		var tangent = belt_position(t + 0.001) - belt_position(t)
		belt_markers[i].rotation.y = atan2(tangent.x, tangent.z)
