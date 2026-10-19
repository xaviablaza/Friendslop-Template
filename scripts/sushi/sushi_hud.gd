class_name SushiHUD
extends CanvasLayer

signal upgrade_requested(kind: String)
signal menu_requested
var stats: Label
var orders: Array[Label] = []
var inventory: Label
var progress: ProgressBar
var prompt: Label
var event_label: Label
var shop: PanelContainer
var shop_buttons: Array[Button] = []
var shift_label: Label
var chapter: Label
var pointer_panel: PanelContainer

func label(text: String, size: int = 20, color: Color = Color("eeeade")) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func panel(at: Vector2, dimensions: Vector2) -> PanelContainer:
	var node = PanelContainer.new()
	node.position = at
	node.size = dimensions
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.13, 0.15, 0.91)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	node.add_theme_stylebox_override("panel", style)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func _ready() -> void:
	var header = panel(Vector2(22, 18), Vector2(380, 86))
	var title = VBoxContainer.new()
	header.add_child(title)
	title.add_child(label("BELT BEHAVIOUR", 25))
	title.add_child(label("REVOLVING SUSHI  /  PLAYABLE GRAYBOX", 12, Color("d5bc7b")))
	var stats_panel = panel(Vector2(430, 18), Vector2(410, 86))
	stats = label("", 21)
	stats_panel.add_child(stats)
	var order_panel = panel(Vector2(1000, 18), Vector2(258, 278))
	var order_box = VBoxContainer.new()
	order_box.add_theme_constant_override("separation", 12)
	order_panel.add_child(order_box)
	order_box.add_child(label("CUSTOMER ORDERS", 17, Color("d5bc7b")))
	for i in range(4):
		var line = label("", 16)
		orders.append(line)
		order_box.add_child(line)
	var tray_panel = panel(Vector2(22, 513), Vector2(380, 143))
	var tray_box = VBoxContainer.new()
	tray_panel.add_child(tray_box)
	inventory = label("", 18)
	tray_box.add_child(inventory)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(320, 9)
	progress.show_percentage = false
	tray_box.add_child(progress)
	var center = label("+", 25)
	center.position = Vector2(630, 344)
	add_child(center)
	prompt = label("", 21)
	prompt.position = Vector2(410, 555)
	prompt.size = Vector2(500, 80)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_color_override("font_shadow_color", Color("13262b"))
	prompt.add_theme_constant_override("shadow_offset_x", 2)
	prompt.add_theme_constant_override("shadow_offset_y", 2)
	add_child(prompt)
	event_label = label("", 17, Color("e4d497"))
	event_label.position = Vector2(22, 115)
	add_child(event_label)
	var controls = panel(Vector2(22, 674), Vector2(1236, 32))
	controls.add_child(label("WASD  MOVE     MOUSE / ARROWS  LOOK     E  INTERACT     F  CLEAR STALE AT BELT     TAB  UPGRADES     ESC  CURSOR / MENU", 13))
	chapter = label("", 17, Color("e4d497"))
	chapter.position = Vector2(430, 115)
	chapter.size.x = 540
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(chapter)
	_build_shop()
	var shift_panel = panel(Vector2(430, 350), Vector2(420, 130))
	shift_label = label("", 22)
	shift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shift_panel.add_child(shift_label)
	shift_panel.visible = false
	pointer_panel = panel(Vector2(470, 220), Vector2(340, 150))
	var pointer_box = VBoxContainer.new()
	pointer_panel.add_child(pointer_box)
	pointer_box.add_child(label("CURSOR RELEASED", 22))
	pointer_box.add_child(label("ESC resumes looking.\nThe restaurant keeps running.", 16))
	var back = Button.new()
	back.text = "Return to main menu"
	back.pressed.connect(func(): menu_requested.emit())
	pointer_box.add_child(back)
	pointer_panel.visible = false

func _build_shop() -> void:
	shop = panel(Vector2(420, 200), Vector2(470, 290))
	shop.mouse_filter = Control.MOUSE_FILTER_STOP
	var rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	shop.add_child(rows)
	rows.add_child(label("INTERNAL PURCHASING", 24, Color("e4d497")))
	rows.add_child(label("Stand beside the upgrade terminal.\nTAB closes. Shared restaurant budget.", 16))
	var kinds = ["tray", "prep", "washer"]
	for i in range(3):
		var button = Button.new()
		button.custom_minimum_size = Vector2(420, 44)
		button.pressed.connect(func(): upgrade_requested.emit(kinds[i]))
		rows.add_child(button)
		shop_buttons.append(button)
	shop.visible = false

func refresh(sim, peer_id: int, target: String, feedback: String) -> void:
	var seconds = int(ceil(sim.time_left))
	stats.text = "$%d   |   SHIFT %02d   |   %d:%02d\nEarned $%d / $80 target   •   %d served" % [sim.money, sim.day, seconds / 60, seconds % 60, sim.shift_earned, sim.served]
	for i in range(orders.size()):
		var customer: Dictionary = sim.customers[i]
		var recipe = int(customer.recipe)
		orders[i].text = "SEAT %02d   %s\n%d sec  /  %d served" % [i + 1, sim.RECIPES[recipe], int(ceil(customer.patience)), customer.served]
		orders[i].modulate = SushiRoom.FOOD_COLORS[recipe].lightened(0.25)
	var state: Dictionary = sim.players.get(peer_id, {"tray": [], "capacity": 1, "preparing": -1, "prep_left": 0})
	var contents: Array[String] = []
	for recipe in state.tray:
		contents.append(sim.RECIPES[recipe])
	inventory.text = "TRAY  %d / %d   %s\nCLEAN %d    RETURN %d    STALE %d" % [state.tray.size(), state.capacity, "·".join(contents), sim.clean_plates, sim.dirty_plates, _stale_count(sim)]
	if state.preparing >= 0:
		inventory.text += "\nPreparing %s…" % sim.RECIPES[state.preparing]
	progress.visible = state.preparing >= 0
	progress.value = (1.0 - float(state.prep_left) / (0.65 if sim.upgrades.prep else 1.5)) * 100
	prompt.text = target
	event_label.text = feedback if not feedback.is_empty() else sim.last_event
	var titles = ["[1]  Serving tray: carry 3 plates  /  $24", "[2]  Prep jig: 0.65 sec per dish  /  $18", "[3]  Dish rack: wash entire return  /  $16"]
	var kinds = ["tray", "prep", "washer"]
	var costs = [24, 18, 16]
	for i in range(shop_buttons.size()):
		shop_buttons[i].text = "INSTALLED  /  " + kinds[i].to_upper() if sim.upgrades[kinds[i]] else titles[i]
		shop_buttons[i].disabled = bool(sim.upgrades[kinds[i]]) or sim.money < costs[i]
	shift_label.get_parent().visible = sim.shift_finished
	shift_label.text = "SHIFT COMPLETE  /  $%d\n%s\nHOST: PRESS N FOR NEXT SHIFT" % [sim.shift_earned, "TARGET HIT" if sim.shift_earned >= 80 else "TRY ANOTHER SHIFT"]

func _stale_count(sim) -> int:
	var count = 0
	for item in sim.belt:
		if item.stale:
			count += 1
	return count
