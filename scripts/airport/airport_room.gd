class_name AirportRoom
extends SushiRoom
## Primitive-only airport. Gameplay owns all bags, interactions and authority.
## Mesh origins sit at their support surface; contents are only shown when opened.

const TABLE_POINT = Vector3(2, 1.1, 0)
const SCAN_POINT = Vector3(-1.2, 1.1, -2)
const SCAN_CONSOLE = Vector3(-1.2, 1, 0.1)
const TOOL_POINT = Vector3(-3, 1, 0.5)
const EVIDENCE_POINT = Vector3(4.6, 1, 0)
# SushiRoom already owns SHOP_POINT: GDScript disallows shadowing constants.
const AIRPORT_SHOP_POINT = Vector3(-3, 1, 3)
const ROUTES: Dictionary = {
	"gate_a": Vector3(-7, 1, 4.6),
	"gate_b": Vector3(-4.5, 1, 4.6),
	"security": Vector3(-2, 1, 4.6),
	"bio": Vector3(0.5, 1, 4.6),
	"rescue": Vector3(3, 1, 4.6),
	"gate_c": Vector3(5.5, 1, 4.6),
	"oversize": Vector3(8, 1, 4.6),
}
const BAG_COLORS = [Color("ab6264"), Color("6284ab"), Color("6f957c"), Color("c5aa63"), Color("977da9"), Color("67a3a3")]
const FLIGHTS = ["A / NW101", "B / SE202", "C / INT303"]
const AIRPORT_STEEL = Color("718587")
const WALL_COLOR = Color("8e9894")
const ROUTE_COLORS: Dictionary = {
	"gate_a": Color("6284ab"), "gate_b": Color("c5aa63"),
	"security": Color("ab6264"), "bio": Color("6f957c"),
	"rescue": Color("67a3a3"), "gate_c": Color("977da9"),
	"oversize": Color("a58c74"),
}

var scan_display: Node3D
var expansion_label: Label3D
var bay_labels: Dictionary = {}
var _expansion_barriers: Array[Node3D] = []
var _expanded := false

static func belt_position(t: float) -> Vector3:
	return Vector3(lerpf(-8.0, 8.0, clampf(t, 0.0, 1.0)), 1.1, -2)

func build() -> void:
	var world := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("9daeb5")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("e4ecea")
	settings.ambient_light_energy = 0.35
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_exposure = 0.75
	world.environment = settings
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-65, -30, 0)
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	add_child(sun)
	box(Vector3(0, -0.12, 0.5), Vector3(21, 0.24, 11.6), Color("68736f"), true)
	for x in range(-10, 11):
		box(Vector3(x, 0.006, 0.5), Vector3(0.012, 0.012, 11.5), Color("a7b2af"))
	for z in range(-5, 7):
		box(Vector3(0, 0.006, z), Vector3(21, 0.012, 0.012), Color("a7b2af"))
	box(Vector3(0, 1.9, -5.3), Vector3(21, 3.8, 0.2), WALL_COLOR, true)
	box(Vector3(-10.5, 1.9, 0.5), Vector3(0.2, 3.8, 11.6), WALL_COLOR, true)
	box(Vector3(10.5, 1.9, 0.5), Vector3(0.2, 3.8, 11.6), WALL_COLOR, true)
	box(Vector3(0, 1.1, 6.3), Vector3(21, 2.2, 0.2), WALL_COLOR, true)
	box(Vector3(-3.8, 3.3, -5.15), Vector3(10.8, 0.85, 0.12), INK)
	_room_sign("CHECKED CHAOS", Vector3(-3.8, 3.48, -5.02), 48).billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_room_sign("AIRPORT BAGGAGE / ARRIVALS CONTROL", Vector3(-3.8, 3.10, -5.01), 25).billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_build_window()
	_build_belt()
	_build_stations()
	_build_bays()
	# Continuous 1.25 m operator corridor, with no solid station at z=2.
	for z in [1.36, 2.64]:
		box(Vector3(0, 0.018, z), Vector3(17.8, 0.025, 0.045), Color("d8c68a"))
	for x in [-7.0, 0.0, 6.5]:
		_floor_arrow(Vector3(x, 0.025, 2), Color("718783"))
	_room_sign("KEEP OPERATOR AISLE CLEAR", Vector3(7, 0.18, 2), 20, INK)
	_build_cart(Vector3(-9.1, 0, 0.6))
	_build_cart(Vector3(9.3, 0, -4))
	set_expanded(1)
	animate_belt(0)

func _room_sign(text: String, at: Vector3, size: int = 28, color: Color = CREAM) -> Label3D:
	var label := sign_at(text, at, size, color)
	label.pixel_size = 0.0035
	label.outline_size = 3
	return label

func _build_belt() -> void:
	box(Vector3(0, 0.82, -2), Vector3(16.6, 0.42, 1.35), AIRPORT_STEEL, true)
	box(Vector3(0, 1.065, -2), Vector3(16.3, 0.06, 1.16), INK)
	for x in range(-8, 9, 2):
		for z in [-2.48, -1.52]:
			box(Vector3(x, 0.4, z), Vector3(0.12, 0.8, 0.12), INK)
	for z in [-2.65, -1.35]:
		box(Vector3(0, 1.13, z), Vector3(16.5, 0.13, 0.07), AIRPORT_STEEL)
	for i in range(48):
		var marker := box(Vector3.ZERO, Vector3(0.035, 0.014, 1.06), Color("637276"))
		belt_markers.append(marker)
	# Distinct intake chute and pickup queue; neither blocks the operator aisle.
	box(Vector3(-8.7, 1.3, -2), Vector3(1.2, 0.18, 1.32), Color("78898e"), true)
	for z in [-2.72, -1.28]:
		box(Vector3(-8.7, 1.52, z), Vector3(1.25, 0.44, 0.08), AIRPORT_STEEL)
	_room_sign("ARRIVALS / INTAKE  >", Vector3(-6.4, 2.1, -2.35), 31)
	_room_sign("SCANNED QUEUE\nPICK UP BAG", Vector3(5.7, 2.15, -2.3), 28, Color("d9c98c"))
	for x in [2.6, 3.6, 4.6, 5.6, 6.6, 7.6]:
		box(Vector3(x, 1.105, -1.53), Vector3(0.025, 0.015, 0.18), Color("d2ba70"))
	# Fictional, harmless dog-compatible training tunnel: open along belt X.
	for z in [-2.77, -1.23]:
		box(Vector3(-1.2, 1.57, z), Vector3(1.9, 1.15, 0.16), Color("7d9498"), true)
	box(Vector3(-1.2, 2.18, -2), Vector3(2.05, 0.17, 1.7), Color("7d9498"), true)
	for x in [-2.2, -0.2]:
		for z in [-2.65, -1.35]:
			box(Vector3(x, 1.61, z), Vector3(0.06, 1.0, 0.08), Color("83b6aa"))
	_room_sign("TRAINING SCANNER\nNON-IONIZING", Vector3(-1.2, 2.56, -1.94), 25)

func _build_stations() -> void:
	# Inspection surface is exactly 1.1 m, leaving opened bags in easy reach.
	box(TABLE_POINT - Vector3(0, 0.08, 0), Vector3(1.6, 0.16, 1.0), AIRPORT_STEEL, true)
	box(TABLE_POINT + Vector3(0, 0.008, 0), Vector3(1.43, 0.015, 0.85), Color("758f87"))
	for x in [-0.64, 0.64]:
		for z in [-0.36, 0.36]:
			box(TABLE_POINT + Vector3(x, -0.61, z), Vector3(0.1, 0.98, 0.1), INK, true)
	_room_sign("INSPECTION / OPEN & CHECK", TABLE_POINT + Vector3(0, 0.83, 0), 26)
	box(SCAN_CONSOLE - Vector3(0, 0.51, 0), Vector3(0.82, 0.98, 0.65), AIRPORT_STEEL, true)
	box(SCAN_CONSOLE + Vector3(0, 0.27, -0.12), Vector3(1.08, 0.72, 0.12), INK)
	box(SCAN_CONSOLE + Vector3(0, 0.27, -0.045), Vector3(0.96, 0.60, 0.025), Color("426365"))
	scan_display = Node3D.new()
	scan_display.name = "ScanDisplay"
	scan_display.position = SCAN_CONSOLE + Vector3(0, 0.27, 0.01)
	add_child(scan_display)
	_room_sign("X-RAY / TRAINING DISPLAY", SCAN_CONSOLE + Vector3(0, 0.88, 0), 24)
	_room_sign("KEY  /  PLIERS", TOOL_POINT + Vector3(0, 0.70, 0), 27, Color("d9c98c"))
	box(TOOL_POINT - Vector3(0, 0.53, 0), Vector3(0.85, 0.94, 0.5), AIRPORT_STEEL, true)
	box(TOOL_POINT, Vector3(0.92, 0.1, 0.58), INK)
	# Oversized greybox tools, not actual inventory instances.
	cylinder(TOOL_POINT + Vector3(-0.2, 0.09, 0), 0.10, 0.03, Color("c7b47b"))
	box(TOOL_POINT + Vector3(-0.2, 0.09, 0.18), Vector3(0.04, 0.04, 0.22), Color("c7b47b"))
	for offset in [-0.09, 0.09]:
		var handle := box(TOOL_POINT + Vector3(0.22 + offset, 0.1, 0.04), Vector3(0.05, 0.05, 0.36), Color("ac7066"))
		handle.rotation.y = offset * 3
	box(EVIDENCE_POINT - Vector3(0, 0.55, 0), Vector3(0.98, 0.9, 0.8), Color("7f6968"), true)
	box(EVIDENCE_POINT - Vector3(0, 0.04, 0), Vector3(1.04, 0.14, 0.86), INK)
	box(EVIDENCE_POINT + Vector3(0, 0.04, 0), Vector3(0.75, 0.025, 0.55), Color("4c5557"))
	_room_sign("SEALED EVIDENCE\nSECURE CHAIN OF CUSTODY", EVIDENCE_POINT + Vector3(0, 0.90, 0), 25)
	box(AIRPORT_SHOP_POINT - Vector3(0, 0.5, 0), Vector3(0.8, 1, 0.6), AIRPORT_STEEL, true)
	box(AIRPORT_SHOP_POINT + Vector3(0, 0.21, 0), Vector3(0.78, 0.5, 0.09), INK)
	box(AIRPORT_SHOP_POINT + Vector3(0, 0.21, 0.055), Vector3(0.66, 0.38, 0.025), Color("5c7c80"))
	_room_sign("AIRPORT UPGRADES", AIRPORT_SHOP_POINT + Vector3(0, 0.77, 0), 25, Color("d9c98c"))

func _build_bays() -> void:
	var names := {
		"gate_a": "GATE A / NW101", "gate_b": "GATE B / SE202",
		"security": "SECURITY / SEIZURES", "bio": "BIOSECURITY / ORGANICS",
		"rescue": "SAFEGUARDING\nCALL RESPONSE TEAM",
		"gate_c": "GATE C / INT303", "oversize": "OVERSIZE / SPECIAL HANDLING",
	}
	for key in ROUTES:
		var at: Vector3 = ROUTES[key]
		var color: Color = ROUTE_COLORS[key]
		box(at - Vector3(0, 0.55, 0), Vector3(1.88, 0.9, 0.96), color.darkened(0.18), true)
		box(at - Vector3(0, 0.06, 0), Vector3(1.98, 0.12, 1.06), color)
		box(at + Vector3(0, 0.42, 0.48), Vector3(1.98, 1.0, 0.08), INK)
		bay_labels[key] = _room_sign(names[key], at + Vector3(0, 0.71, 0.35), 23, color.lightened(0.45))
		box(Vector3(at.x, 0.018, 3.91), Vector3(1.95, 0.025, 0.12), color)
		if key in ["gate_c", "oversize"]:
			# Visual ribbons only: deliberately NO collision to trap a player.
			var ribbon := box(at + Vector3(0, 0.24, -0.55), Vector3(1.98, 0.16, 0.035), Color("c7ad6b"))
			_expansion_barriers.append(ribbon)
	expansion_label = _room_sign("", Vector3(6.7, 2.72, 5.03), 30, Color("d9c98c"))

func set_expanded(level: int) -> void:
	_expanded = level >= 2
	for ribbon in _expansion_barriers:
		ribbon.visible = not _expanded
	if is_instance_valid(expansion_label):
		expansion_label.text = "INTERNATIONAL WING / OPEN" if _expanded else "INTERNATIONAL WING / LOCKED"
		expansion_label.modulate = Color("b9d3c6") if _expanded else Color("d9c98c")
	if bay_labels.has("gate_c"):
		bay_labels["gate_c"].text = "GATE C / INT303" if _expanded else "GATE C / LOCKED"
	if bay_labels.has("oversize"):
		bay_labels["oversize"].text = "OVERSIZE / SPECIAL HANDLING" if _expanded else "OVERSIZE / LOCKED"

func animate_belt(clock: float, speed: float = 0.065) -> void:
	for i in range(belt_markers.size()):
		var t := fposmod(float(i) / belt_markers.size() + clock * speed, 1.0)
		belt_markers[i].position = belt_position(t) - Vector3(0, 0.004, 0)
	# Optional animated tail survives any gameplay-owned positioning/rotation.
	for dog in get_tree().get_nodes_in_group("airport_dog_visual") if is_inside_tree() else []:
		var tail: Node3D = dog.get_node_or_null("TailPivot")
		if tail != null:
			tail.rotation.z = sin(clock * 7.0) * 0.32

func _floor_arrow(at: Vector3, color: Color) -> void:
	box(at, Vector3(0.7, 0.018, 0.07), color)
	for s in [-1.0, 1.0]:
		var tip := box(at + Vector3(0.28, 0, s * 0.09), Vector3(0.25, 0.018, 0.06), color)
		tip.rotation.y = s * 0.65

func _build_window() -> void:
	box(Vector3(5.8, 2.35, -5.17), Vector3(7.5, 2.3, 0.05), Color("829da9"))
	for x in [2.05, 4.55, 7.05, 9.55]:
		box(Vector3(x, 2.35, -5.07), Vector3(0.07, 2.4, 0.08), INK)
	box(Vector3(5.8, 1.9, -5.1), Vector3(7.5, 0.04, 0.03), Color("637d84"))
	# Stylized side-profile aircraft beyond the apron window.
	box(Vector3(5.8, 2.38, -5.04), Vector3(4.0, 0.27, 0.035), CREAM)
	var wing := box(Vector3(5.8, 2.23, -5.01), Vector3(1.4, 0.16, 0.04), AIRPORT_STEEL)
	wing.rotation.z = 0.25
	var fin := box(Vector3(7.38, 2.64, -5.01), Vector3(0.38, 0.62, 0.04), Color("6c889f"))
	fin.rotation.z = -0.25
	for x in [4.25, 4.65, 5.05, 5.45, 5.85, 6.25, 6.65]:
		box(Vector3(x, 2.43, -5.005), Vector3(0.12, 0.065, 0.02), INK)
	_room_sign("APRON 03 / ARRIVALS", Vector3(5.8, 3.37, -4.99), 24, INK)

func _build_cart(at: Vector3) -> void:
	box(at + Vector3(0, 0.35, 0), Vector3(0.92, 0.08, 1.25), AIRPORT_STEEL)
	for x in [-0.38, 0.38]:
		for z in [-0.49, 0.49]:
			var wheel := cylinder(at + Vector3(x, 0.18, z), 0.14, 0.09, INK)
			wheel.rotation.z = PI / 2
	for x in [-0.43, 0.43]:
		box(at + Vector3(x, 0.68, -0.55), Vector3(0.04, 0.65, 0.04), AIRPORT_STEEL)
	box(at + Vector3(0, 0.99, -0.55), Vector3(0.9, 0.04, 0.04), INK)
	box(at + Vector3(0, 0.59, 0.08), Vector3(0.65, 0.42, 0.67), Color("8e8376"))

# The static constructors below intentionally create no collision bodies. The
# authoritative game attaches/targets its own bag or item interaction roots.
static func _mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.position = at
	node.material_override = material(color)
	parent.add_child(node)
	return node

static func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(parent, shape, at, color)

static func _capsule(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = maxf(height, radius * 2)
	shape.radial_segments = 12
	shape.rings = 4
	return _mesh(parent, shape, at, color)

static func _round(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 12
	return _mesh(parent, shape, at, color)

static func _tag(parent: Node3D, text: String, at: Vector3, size: int = 22, color: Color = CREAM) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = size
	label.pixel_size = 0.0028
	label.modulate = color
	label.outline_modulate = INK
	label.outline_size = 3
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label

static func bag_mesh(bag: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "BaggageVisual"
	var raw_color: Variant = bag.get("color", bag.get("color_index", 0))
	var color: Color = BAG_COLORS[posmod(int(raw_color), BAG_COLORS.size())] if raw_color is int or raw_color is float else Color.from_string(str(raw_color), BAG_COLORS[0])
	if raw_color is Color:
		color = raw_color
	var raw_kind: Variant = bag.get("type", bag.get("kind", "suitcase"))
	var kind := str(raw_kind).to_lower()
	if raw_kind is int:
		kind = ["suitcase", "duffel", "backpack", "trunk"][posmod(int(raw_kind), 4)]
	var size_value: Variant = bag.get("size", "medium")
	var factor := 1.0
	if size_value is int:
		factor = [0.82, 1.0, 1.3][clampi(int(size_value), 0, 2)]
	elif size_value is float:
		factor = clampf(float(size_value), 0.7, 1.45)
	elif str(size_value).to_lower() in ["small", "s", "compact"]:
		factor = 0.78
	elif str(size_value).to_lower() in ["large", "l", "oversize"]:
		factor = 1.3
	var width := 0.68 * factor
	var height := 0.55 * factor
	var depth := 0.45 * factor
	if kind in ["duffel", "duffle", "sports"]:
		width *= 1.25
		height *= 0.72
	elif kind in ["backpack", "rucksack"]:
		width *= 0.75
		height *= 1.16
	elif kind in ["crate", "trunk", "oversize"]:
		width *= 1.2
		depth *= 1.18
	var opened := bool(bag.get("opened", bag.get("open", false)))
	var body_height := height * 0.76 if opened else height
	_box(root, Vector3(0, 0.10 + body_height / 2, 0), Vector3(width, body_height, depth), color)
	# Beading, recessed front panel, and distinctive pockets/straps.
	_box(root, Vector3(0, 0.10 + height * 0.5, depth / 2 + 0.008), Vector3(width * 0.86, height * 0.76, 0.025), color.darkened(0.14))
	if kind in ["duffel", "duffle", "sports", "crate", "trunk", "oversize"]:
		for x in [-width * 0.3, width * 0.3]:
			_box(root, Vector3(x, 0.10 + body_height / 2, depth / 2 + 0.027), Vector3(0.045, body_height, 0.025), INK)
	elif kind in ["backpack", "rucksack"]:
		_box(root, Vector3(0, 0.1 + height * 0.28, depth / 2 + 0.07), Vector3(width * 0.75, height * 0.36, 0.14), color.lightened(0.1))
	else:
		for x in [-width * 0.3, 0, width * 0.3]:
			_box(root, Vector3(x, 0.1 + height / 2, depth / 2 + 0.03), Vector3(0.022, height * 0.7, 0.018), color.lightened(0.18))
	for x in [-width * 0.37, width * 0.37]:
		var wheel := _round(root, Vector3(x, 0.065, depth * 0.28), 0.065, 0.06, INK)
		wheel.rotation.z = PI / 2
	# Lid is a separate hinge, so opening visibly changes the silhouette.
	var lid := Node3D.new()
	lid.name = "LidHinge"
	lid.position = Vector3(0, height + 0.1 if not opened else body_height + 0.1, -depth / 2)
	root.add_child(lid)
	_box(lid, Vector3(0, 0, depth / 2), Vector3(width + 0.018, 0.055, depth + 0.018), color.lightened(0.12))
	if opened:
		lid.rotation.x = deg_to_rad(-108)
		_box(root, Vector3(0, body_height + 0.106, 0), Vector3(width * 0.88, 0.022, depth * 0.85), INK)
	for x in [-0.12, 0.12]:
		_box(lid, Vector3(x, 0.075, depth / 2), Vector3(0.035, 0.13, 0.04), INK)
	_box(lid, Vector3(0, 0.14, depth / 2), Vector3(0.27, 0.04, 0.045), INK)
	var lock_kind := str(bag.get("lock", bag.get("lock_type", "none"))).to_lower()
	if lock_kind not in ["none", "", "unlocked", "false"] and not bool(bag.get("unlocked", false)):
		var approved := lock_kind in ["approved", "tsa", "tsa_approved", "standard"]
		_round(root, Vector3(width / 2 + 0.025, height * 0.78, 0.04), 0.045, 0.12, AIRPORT_STEEL)
		_box(root, Vector3(width / 2 + 0.025, height * 0.68, 0.04), Vector3(0.1, 0.12, 0.07), Color("b7ad7c") if approved else Color("9d6e65"))
	var flight_value: Variant = bag.get("flight", bag.get("flight_index", 0))
	var flight_text := str(flight_value)
	if flight_value is int or flight_value is float:
		flight_text = FLIGHTS[posmod(int(flight_value), FLIGHTS.size())]
	elif flight_text.to_lower() in ["a", "gate_a", "nw101"]:
		flight_text = FLIGHTS[0]
	elif flight_text.to_lower() in ["b", "gate_b", "se202"]:
		flight_text = FLIGHTS[1]
	elif flight_text.to_lower() in ["c", "gate_c", "int303"]:
		flight_text = FLIGHTS[2]
	_box(root, Vector3(width * 0.18, height * 0.48 + 0.1, depth / 2 + 0.052), Vector3(0.31, 0.15, 0.018), CREAM)
	_tag(root, flight_text, Vector3(width * 0.18, height * 0.48 + 0.1, depth / 2 + 0.068), 18, INK)
	if opened:
		var index := 0
		for entry in bag.get("items", bag.get("contents", [])):
			if not entry is Dictionary:
				continue
			var location := str(entry.get("location", "bag"))
			if location not in ["bag", "inside", ""]:
				continue
			var item := item_mesh(entry)
			item.scale = Vector3.ONE * 0.52
			item.position = Vector3((float(index % 2) - 0.5) * width * 0.44, body_height + 0.13 + floorf(index / 4.0) * 0.08, (float((index / 2) % 2) - 0.5) * depth * 0.4)
			root.add_child(item)
			index += 1
	return root

static func item_mesh(item: Dictionary, xray: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "ItemVisual"
	var kind := str(item.get("kind", item.get("type", item.get("id", "clothes")))).to_lower()
	var cyan := Color("9cc8c1")
	var color := cyan if xray else Color("9aabb6")
	var label := str(item.get("label", item.get("name", kind.replace("_", " ")))).to_upper()
	match kind:
		"clothes", "clothing", "shirt":
			_box(root, Vector3(0, 0.07, 0), Vector3(0.38, 0.14, 0.26), color)
			_box(root, Vector3(0, 0.15, 0), Vector3(0.31, 0.04, 0.23), cyan if xray else Color("b7aa9b"))
		"socks", "sock":
			for x in [-0.08, 0.08]:
				_capsule(root, Vector3(x, 0.11, 0), 0.055, 0.22, color)
				_box(root, Vector3(x, 0.04, 0.045), Vector3(0.11, 0.07, 0.14), color)
		"electronics", "laptop", "phone":
			_box(root, Vector3(0, 0.025, 0), Vector3(0.38, 0.05, 0.27), INK if not xray else cyan)
			_box(root, Vector3(0, 0.057, 0), Vector3(0.33, 0.015, 0.22), color)
			for x in [-0.09, 0, 0.09]:
				_box(root, Vector3(x, 0.07, 0.015), Vector3(0.05, 0.015, 0.1), AIRPORT_STEEL if not xray else cyan)
		"dildo":
			# Generic adult-product capsule and packaging: no anatomical detail.
			_capsule(root, Vector3(0, 0.18, 0), 0.065, 0.34, cyan if xray else Color("a98ba9"))
			_round(root, Vector3(0, 0.025, 0), 0.095, 0.05, color)
			label = "LEGAL / ADULT PRODUCT"
		"vibrator":
			_capsule(root, Vector3(-0.06, 0.14, 0), 0.055, 0.27, cyan if xray else Color("a98ba9"))
			var ring := TorusMesh.new()
			ring.inner_radius = 0.065
			ring.outer_radius = 0.095
			_mesh(root, ring, Vector3(0.10, 0.08, 0), color)
			label = "LEGAL / PERSONAL MASSAGER"
		"fruit", "apple", "orange":
			_capsule(root, Vector3(0, 0.11, 0), 0.11, 0.22, cyan if xray else Color("b88466"))
			_box(root, Vector3(0, 0.235, 0), Vector3(0.025, 0.05, 0.025), cyan if xray else Color("638269"))
		"vegetable", "vegetables", "carrot":
			var shape := CylinderMesh.new()
			shape.top_radius = 0.07
			shape.bottom_radius = 0.015
			shape.height = 0.28
			_mesh(root, shape, Vector3(0, 0.14, 0), cyan if xray else Color("bc9466"))
			_box(root, Vector3(0, 0.31, 0), Vector3(0.1, 0.09, 0.04), cyan if xray else Color("6f957c"))
		"seeds", "seed":
			_box(root, Vector3(0, 0.035, 0), Vector3(0.23, 0.07, 0.28), cyan if xray else Color("bba983"))
			for x in [-0.06, 0.0, 0.06]:
				_capsule(root, Vector3(x, 0.085, 0), 0.023, 0.05, cyan if xray else Color("6f8060"))
		"narcotics", "drugs", "sealed_brick":
			_box(root, Vector3(0, 0.09, 0), Vector3(0.35, 0.18, 0.22), cyan if xray else Color("b7b4a3"))
			for x in [-0.09, 0.09]:
				_box(root, Vector3(x, 0.095, 0), Vector3(0.035, 0.195, 0.235), cyan if xray else Color("8e8170"))
			label = "SEALED PACKAGE"
		"documents", "document", "passport":
			_box(root, Vector3(0, 0.025, 0), Vector3(0.26, 0.05, 0.32), cyan if xray else Color("768795"))
			_box(root, Vector3(0, 0.057, 0), Vector3(0.22, 0.01, 0.27), CREAM if not xray else cyan)
		"person_at_risk", "adult_at_risk", "adult_silhouette", "person", "safeguarding":
			# Abstract adult-scale proportions, clothed and non-graphic.
			_capsule(root, Vector3(0, 0.38, 0), 0.11, 0.40, cyan if xray else Color("82999f"))
			_capsule(root, Vector3(0, 0.66, 0), 0.085, 0.17, cyan if xray else Color("b6a394"))
			for x in [-0.065, 0.065]:
				_capsule(root, Vector3(x, 0.13, 0), 0.045, 0.27, color)
			for x in [-0.15, 0.15]:
				_capsule(root, Vector3(x, 0.37, 0), 0.035, 0.3, color)
			label = "ADULT / ASSISTANCE REQUIRED"
		_:
			_box(root, Vector3(0, 0.08, 0), Vector3(0.25, 0.16, 0.22), color)
	# X-ray needs clean silhouettes, not floating contents text.
	if not xray:
		_tag(root, label, Vector3(0, 0.49 if kind not in ["person_at_risk", "adult_at_risk", "adult_silhouette", "person", "safeguarding"] else 0.86, 0), 16)
	return root

static func dog_mesh() -> Node3D:
	var root := Node3D.new()
	root.name = "DogVisual"
	root.add_to_group("airport_dog_visual")
	var coat := Color("a99477")
	var dark := Color("645d55")
	# Forward is -Z; a short harness and four legs read from either side.
	var torso := _capsule(root, Vector3(0, 0.32, 0), 0.16, 0.57, coat)
	torso.rotation.x = PI / 2
	for x in [-0.11, 0.11]:
		for z in [-0.17, 0.2]:
			_capsule(root, Vector3(x, 0.14, z), 0.048, 0.28, coat)
			_box(root, Vector3(x, 0.025, z - 0.025), Vector3(0.1, 0.05, 0.14), dark)
	_capsule(root, Vector3(0, 0.48, -0.29), 0.13, 0.28, coat)
	_box(root, Vector3(0, 0.44, -0.43), Vector3(0.18, 0.11, 0.20), coat)
	_box(root, Vector3(0, 0.455, -0.535), Vector3(0.10, 0.065, 0.03), dark)
	for x in [-0.12, 0.12]:
		var ear := _capsule(root, Vector3(x, 0.54, -0.28), 0.045, 0.20, dark)
		ear.rotation.z = signf(x) * 0.3
		_box(root, Vector3(x * 0.76, 0.51, -0.389), Vector3(0.025, 0.025, 0.024), INK)
	_box(root, Vector3(0, 0.445, -0.06), Vector3(0.34, 0.04, 0.15), Color("6a8792"))
	var tail := Node3D.new()
	tail.name = "TailPivot"
	tail.position = Vector3(0, 0.37, 0.25)
	root.add_child(tail)
	var tail_mesh := _capsule(tail, Vector3(0, 0.08, 0.1), 0.04, 0.26, dark)
	tail_mesh.rotation.x = 0.8
	return root
