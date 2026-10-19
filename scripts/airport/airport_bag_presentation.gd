class_name AirportBagPresentation
extends RefCounted
## Presentation only: camera-local carry rig, world crew, and cached bag hulls.

const NAVY = Color("243b56")
const HI_VIS = Color("d6e956")
const GLOVE = Color("c2d9e3")
const REFLECTIVE = Color("e5e9df")
const OUTLINE_META = &"airport_outline_hulls"
static var _outline_material: ShaderMaterial

static func apply_outline(root: Node3D, enabled: bool) -> void:
	if not root.has_meta(OUTLINE_META):
		var hulls: Array[MeshInstance3D] = []
		_collect_hulls(root, hulls)
		root.set_meta(OUTLINE_META, hulls)
	for hull in root.get_meta(OUTLINE_META):
		if is_instance_valid(hull):
			hull.visible = enabled

static func _collect_hulls(node: Node, hulls: Array[MeshInstance3D]) -> void:
	# Contents and label glyphs are not case geometry. Snapshot before adding.
	if node is Label3D or node.name == &"ItemVisual":
		return
	for child in node.get_children():
		_collect_hulls(child, hulls)
	if node is MeshInstance3D and node.mesh != null:
		if _outline_material == null:
			var shader := Shader.new()
			shader.code = """shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;
void vertex() { VERTEX += NORMAL * 0.012; }
void fragment() { ALBEDO = vec3(1.0, 0.86, 0.015); }
"""
			_outline_material = ShaderMaterial.new()
			_outline_material.shader = shader
		var hull := MeshInstance3D.new()
		hull.name = "YellowSilhouette"
		hull.mesh = node.mesh
		hull.material_override = _outline_material
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Identity under the source inherits its exact transform and visibility.
		node.add_child(hull)
		hulls.append(hull)

static func _bag_dimensions(bag: Dictionary) -> Vector2:
	var size: Variant = bag.get("size", 1)
	var factor := 1.0
	if size is int:
		factor = [0.82, 1.0, 1.3][clampi(int(size), 0, 2)]
	elif size is float:
		factor = clampf(float(size), 0.7, 1.45)
	elif str(size).to_lower() in ["small", "s", "compact"]:
		factor = 0.78
	elif str(size).to_lower() in ["large", "l", "oversize"]:
		factor = 1.3
	var kind: Variant = bag.get("type", bag.get("kind", 0))
	var kind_name := str(kind).to_lower()
	if kind is int:
		kind_name = ["suitcase", "duffel", "backpack", "trunk"][posmod(int(kind), 4)]
	var dimensions := Vector2(0.68, 0.55) * factor
	if kind_name in ["duffel", "duffle", "sports"]:
		dimensions *= Vector2(1.25, 0.72)
	elif kind_name in ["backpack", "rucksack"]:
		dimensions *= Vector2(0.75, 1.16)
	elif kind_name in ["crate", "trunk", "oversize"]:
		dimensions.x *= 1.2
	return dimensions

static func carry_offset(_bag: Dictionary) -> Vector3:
	return Vector3(0, -0.56, -1.12)

static func carry_scale(_bag: Dictionary) -> float:
	return 0.90

static func make_hands() -> Node3D:
	var rig := Node3D.new()
	rig.name = "TwoHandCarryRig"
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.name = "Left" if side < 0 else "Right"
		rig.add_child(arm)
		_box(arm, "Sleeve", Vector3.ZERO, Vector3(0.16, 1, 0.16), NAVY)
		_box(arm, "Cuff", Vector3.ZERO, Vector3(0.17, 1, 0.17), HI_VIS)
		_make_glove(arm)
	update_hands(rig, {}, 0)
	return rig

static func update_hands(rig: Node3D, bag: Dictionary, clock: float) -> void:
	rig.visible = not bag.is_empty()
	if bag.is_empty():
		return
	var dimensions := _bag_dimensions(bag) * carry_scale(bag)
	var half_width := dimensions.x * 0.5
	var weight := clampf(float(bag.get("mass_kg", bag.get("weight_kg", 10.0))) / 35.0, 0, 1)
	var bob := sin(clock * 2.2) * 0.002 * weight
	# Bag origin is its support surface, not its geometric center.
	var grip_y := carry_offset(bag).y + 0.09 + dimensions.y * 0.34 + bob
	for side in [-1, 1]:
		var arm: Node3D = rig.get_node("Left" if side < 0 else "Right")
		var elbow := Vector3(side * 0.52, -0.5, -0.15)
		var grip := Vector3(side * (half_width + 0.035), grip_y, -1.01)
		var wrist := grip.lerp(elbow, 0.19)
		var cuff_end := grip.lerp(elbow, 0.28)
		_segment(arm.get_node("Sleeve"), elbow, cuff_end)
		_segment(arm.get_node("Cuff"), cuff_end, wrist)
		var glove: Node3D = arm.get_node("Glove")
		glove.position = grip
		glove.scale.x = side

static func make_crew(peer_name: String, tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "AirportWorker"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	for side in [-1, 1]:
		_box(body, "Boot", Vector3(side * 0.14, 0.09, -0.045), Vector3(0.21, 0.18, 0.34), NAVY.darkened(0.35))
		_box(body, "Trouser", Vector3(side * 0.14, 0.45, 0), Vector3(0.19, 0.62, 0.22), NAVY)
		_box(body, "AnkleTape", Vector3(side * 0.14, 0.22, -0.005), Vector3(0.195, 0.06, 0.23), REFLECTIVE)
	_box(body, "Torso", Vector3(0, 1.09, 0), Vector3(0.51, 0.65, 0.30), tint)
	_box(body, "Belt", Vector3(0, 0.81, 0), Vector3(0.53, 0.08, 0.32), NAVY)
	for side in [-1, 1]:
		_box(body, "Vest", Vector3(side * 0.14, 1.14, -0.163), Vector3(0.18, 0.53, 0.025), HI_VIS)
		_box(body, "VestTape", Vector3(side * 0.14, 1.14, -0.182), Vector3(0.055, 0.51, 0.018), REFLECTIVE)
	_box(body, "WaistTape", Vector3(0, 0.99, -0.188), Vector3(0.49, 0.055, 0.02), REFLECTIVE)
	_box(body, "Badge", Vector3(0.13, 1.27, -0.20), Vector3(0.09, 0.06, 0.02), NAVY)
	_box(body, "Neck", Vector3(0, 1.45, 0), Vector3(0.14, 0.14, 0.14), Color("b78f74"))
	_box(body, "Head", Vector3(0, 1.63, -0.015), Vector3(0.30, 0.33, 0.28), Color("c49e81"))
	_box(body, "Cap", Vector3(0, 1.81, -0.01), Vector3(0.34, 0.10, 0.32), tint)
	_box(body, "CapBrim", Vector3(0, 1.77, -0.20), Vector3(0.36, 0.04, 0.20), tint)
	_box(body, "EarBand", Vector3(0, 1.83, 0.015), Vector3(0.39, 0.035, 0.05), NAVY)
	for side in [-1, 1]:
		_box(body, "EarProtector", Vector3(side * 0.18, 1.65, 0), Vector3(0.075, 0.18, 0.14), NAVY)
		_box(body, "Eye", Vector3(side * 0.065, 1.66, -0.16), Vector3(0.035, 0.035, 0.012), NAVY)
	_box(body, "Nose", Vector3(0, 1.60, -0.175), Vector3(0.05, 0.065, 0.05), Color("b78f74"))
	_box(body, "Smile", Vector3(0, 1.54, -0.16), Vector3(0.09, 0.018, 0.012), NAVY)
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.name = "LeftArm" if side < 0 else "RightArm"
		body.add_child(arm)
		_box(arm, "Upper", Vector3.ZERO, Vector3(0.16, 1, 0.17), tint)
		_box(arm, "Forearm", Vector3.ZERO, Vector3(0.15, 1, 0.16), NAVY)
		_box(arm, "Cuff", Vector3.ZERO, Vector3(0.165, 1, 0.175), HI_VIS)
		_make_glove(arm)
	var label := Label3D.new()
	label.name = "PeerName"
	label.text = peer_name
	label.position.y = 2.04
	label.font_size = 28
	label.pixel_size = 0.003
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	root.add_child(label)
	update_crew(root, false)
	return root

static func update_crew(root: Node3D, holding: bool, mass_kg: float = 0.0) -> void:
	var body: Node3D = root.get_node("Body")
	body.position.y = -0.045 * clampf((mass_kg - 15) / 25.0, 0, 1) if holding else 0.0
	for side in [-1, 1]:
		var arm: Node3D = body.get_node("LeftArm" if side < 0 else "RightArm")
		var shoulder := Vector3(side * 0.31, 1.34, 0)
		var elbow := Vector3(side * 0.40, 1.08, -0.27) if holding else Vector3(side * 0.35, 1.03, 0)
		var grip := Vector3(side * 0.33, 1.19, -0.53) if holding else Vector3(side * 0.35, 0.79, -0.04)
		var wrist := grip.lerp(elbow, 0.23)
		_segment(arm.get_node("Upper"), shoulder, elbow)
		_segment(arm.get_node("Forearm"), elbow, grip.lerp(elbow, 0.39))
		_segment(arm.get_node("Cuff"), grip.lerp(elbow, 0.39), wrist)
		var glove: Node3D = arm.get_node("Glove")
		glove.position = grip
		glove.scale.x = side
		glove.rotation.x = 0 if holding else -0.7

static func _make_glove(parent: Node3D) -> void:
	var glove := Node3D.new()
	glove.name = "Glove"
	parent.add_child(glove)
	_box(glove, "Palm", Vector3.ZERO, Vector3(0.12, 0.16, 0.19), GLOVE)
	_box(glove, "Thumb", Vector3(-0.065, 0.065, -0.005), Vector3(0.075, 0.07, 0.11), GLOVE.lightened(0.07))
	for i in range(3):
		_box(glove, "Finger", Vector3(-0.025, 0.045 - i * 0.045, -0.095), Vector3(0.11, 0.035, 0.05), GLOVE.darkened(0.07))

static func _segment(mesh: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	mesh.position = (start + end) * 0.5
	var axis := (end - start).normalized()
	var across := Vector3.FORWARD.cross(axis).normalized()
	mesh.basis = Basis(across, axis, across.cross(axis).normalized())
	mesh.scale.y = start.distance_to(end)

static func _box(parent: Node3D, node_name: String, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh
