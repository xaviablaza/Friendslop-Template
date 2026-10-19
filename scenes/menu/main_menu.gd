extends Control
## Local entry flow; networking and scene readiness remain template-owned.
const Settings = preload("res://scenes/menu/airport_settings.gd")
const AIRPORT_SCENE = "res://scenes/level/airport/AirportBaggage.tscn"
const SUSHI_SCENE = "res://scenes/level/sushi/RevolvingSushi.tscn"
var settings = Settings.new()
var join_ip_input: LineEdit
var pages: Dictionary = {}
var page_name = ""
var splash: Control
var first_button: Button
var status_label: Label
var settings_status: Label

func _ready() -> void:
	PeerManager.shutdown()
	var reason = LobbyManager.disconnection_reason
	LobbyManager.reset_lobby()
	settings.load_settings()
	_build_menu()
	SceneManager.mark_scene_as_loaded(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var args = OS.get_cmdline_user_args()
	var automated = false
	for arg in args:
		if arg.begins_with("--airport-") or arg.begins_with("--sushi-"):
			automated = true
	if automated or reason != "" or get_tree().root.has_meta("airport_splash_seen"):
		_finish_splash()
	else:
		_show_page("splash")
		var timer = get_tree().create_timer(2.2)
		timer.timeout.connect(func():
			if is_instance_valid(self) and page_name == "splash": _finish_splash())
	if reason != "":
		_show_disconnection_dialog(reason)
	_run_automation(args)

func _build_menu() -> void:
	var column: VBoxContainer = $Margin/Center/Column
	var title = Label.new()
	title.text = "CHECKED CHAOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	column.add_child(title)
	var subtitle = Label.new()
	subtitle.text = "AIRPORT BAGGAGE  /  CO-OP GREYBOX"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("89cddb"))
	column.add_child(subtitle)
	for key in ["splash", "main", "settings", "controls"]:
		var page = VBoxContainer.new()
		page.name = key.capitalize()
		page.add_theme_constant_override("separation", 10)
		column.add_child(page)
		pages[key] = page
	splash = pages.splash
	_label(splash, "WELCOME TO ARRIVALS\nInspect. Repack. Route. Cause a little chaos.")
	_button(splash, "Continue", _finish_splash, "Continue")
	var main: VBoxContainer = pages.main
	first_button = _button(main, "Play solo", _play_solo, "Solo")
	_button(main, "Host co-op", _on_start_game_pressed, "StartGame")
	var row = HBoxContainer.new()
	row.name = "JoinHBox"
	main.add_child(row)
	var join = _button(row, "Join", _on_join_game_pressed, "JoinGame")
	join.custom_minimum_size.x = 100
	join_ip_input = LineEdit.new()
	join_ip_input.name = "JoinIP"
	join_ip_input.text = "127.0.0.1"
	join_ip_input.placeholder_text = "Server IP address"
	join_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_ip_input.text_submitted.connect(func(_text): _on_join_game_pressed())
	row.add_child(join_ip_input)
	_button(main, "Settings", _show_page.bind("settings"), "Settings")
	_button(main, "Controls", _show_page.bind("controls"), "Controls")
	_button(main, "Previous concept / Revolving sushi", _play_sushi, "Sushi")
	_button(main, "Quit", _on_quit_pressed, "Quit")
	status_label = _label(main, "Co-op uses the existing LAN lobby. Default port: 7000.")
	_build_settings()
	var controls: VBoxContainer = pages.controls
	_label(controls, "CONTROLS")
	_label(controls, "WASD / left stick  —  Move\nMouse / arrow keys / right stick  —  Look\nShift  —  Sprint (uses stamina)\nCtrl  —  Crouch; release to stand when clear\nSpace  —  Jump (needs stamina); lock challenge input\nE  —  Interact / catch / start lock\nO / C / R  —  Open / close / relock bag\nI  —  Contents browser / repack\n1 / 2 / 3  —  Hands / key / pliers; lock sequence\nG / Q  —  Throw / gentle drop\nH / P / K  —  Carry helper / dog mode / call dog\nF / Tab  —  Enlarge X-ray / development shop\nEsc  —  Release mouse / close panels; Esc again to resume")
	_label(controls, "Injury and heavy loads slow movement. Rest to recover stamina.\nStation prompts expose supplies, animal care and first aid.")
	_button(controls, "Back", _show_page.bind("main"), "Back")

func _build_settings() -> void:
	var page: VBoxContainer = pages.settings
	_label(page, "SETTINGS  /  saved on this device")
	var volume_label = _label(page, "Master volume: %d%%" % roundi(settings.master_volume * 100))
	var volume = HSlider.new()
	volume.name = "MasterVolume"
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = settings.master_volume
	page.add_child(volume)
	volume.value_changed.connect(func(value):
		settings.master_volume = value
		volume_label.text = "Master volume: %d%%" % roundi(value * 100)
		_save_settings())
	var mouse_label = _label(page, "Airport mouse sensitivity: %.2fx" % settings.mouse_sensitivity)
	var sensitivity = HSlider.new()
	sensitivity.name = "MouseSensitivity"
	sensitivity.min_value = 0.25
	sensitivity.max_value = 3.0
	sensitivity.step = 0.05
	sensitivity.value = settings.mouse_sensitivity
	page.add_child(sensitivity)
	sensitivity.value_changed.connect(func(value):
		settings.mouse_sensitivity = value
		mouse_label.text = "Airport mouse sensitivity: %.2fx" % value
		_save_settings())
	var fullscreen = CheckButton.new()
	fullscreen.name = "Fullscreen"
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = settings.fullscreen
	page.add_child(fullscreen)
	fullscreen.toggled.connect(func(value):
		settings.fullscreen = value
		_save_settings())
	settings_status = _label(page, "Changes apply immediately.")
	_button(page, "Back", _show_page.bind("main"), "Back")

func _save_settings() -> void:
	settings_status.text = "Saved." if settings.save() == OK else "Could not save settings on this device."

func _button(parent: Node, text: String, callback: Callable, node_name: String) -> Button:
	var button = Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = 42
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func _label(parent: Node, text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _show_page(key: String) -> void:
	page_name = key
	for name_key in pages:
		pages[name_key].visible = name_key == key
	var focus = pages[key].find_children("*", "BaseButton", true, false)
	if not focus.is_empty(): focus[0].grab_focus()

func _finish_splash() -> void:
	get_tree().root.set_meta("airport_splash_seen", true)
	_show_page("main")

func _input(event: InputEvent) -> void:
	# Consume the dismissal before GUI dispatch so Enter cannot also activate Solo.
	if page_name == "splash" and ((event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed)):
		_finish_splash()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and page_name in ["settings", "controls"]:
		_show_page("main")
		get_viewport().set_input_as_handled()

func _run_automation(args: PackedStringArray) -> void:
	if args.has("--airport-throw-host"):
		_auto_network(true, 17127)
	elif args.has("--airport-throw-client"):
		_auto_network(false, 17127)
	elif args.has("--airport-tour"):
		_play_solo.call_deferred()
	elif args.has("--airport-net-host"):
		_auto_network(true, 17117)
	elif args.has("--airport-net-client"):
		_auto_network(false, 17117)
	elif args.has("--sushi-tour"):
		_play_sushi.call_deferred()
	elif args.has("--sushi-net-host"):
		_auto_network(true, 17107)
	elif args.has("--sushi-net-client"):
		_auto_network(false, 17107)

func _auto_network(host: bool, port: int) -> void:
	PeerManager.set_provider(ENetNetworkProvider.new("127.0.0.1", port))
	if host: PeerManager.host_game.call_deferred()
	else: PeerManager.join_game.call_deferred()

func _play_solo() -> void:
	# A null peer cannot provide local authority after shutdown.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	SceneManager.start_transition_to(AIRPORT_SCENE)

func _play_sushi() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	SceneManager.start_transition_to(SUSHI_SCENE)

func _on_start_game_pressed() -> void:
	PeerManager.set_provider(ENetNetworkProvider.new())
	PeerManager.host_game()

func _on_join_game_pressed() -> void:
	var ip = join_ip_input.text.strip_edges()
	if ip.is_empty(): ip = "127.0.0.1"
	status_label.text = "Connecting to %s…" % ip
	PeerManager.set_provider(ENetNetworkProvider.new(ip))
	PeerManager.join_game()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _show_disconnection_dialog(reason: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = reason
	dialog.title = "Disconnected"
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered()
	LobbyManager.disconnection_reason = ""
