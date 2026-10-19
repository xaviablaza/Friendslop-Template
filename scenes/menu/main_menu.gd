extends Control

## UI Controller for the Main Menu.
## Serves as the entry point for hosting or joining multiplayer sessions.

@onready var join_ip_input: LineEdit = %JoinIP

func _ready() -> void:
	PeerManager.shutdown()
	
	if LobbyManager.disconnection_reason != "":
		_show_disconnection_dialog(LobbyManager.disconnection_reason)
	
	LobbyManager.reset_lobby()
	%StartGame.grab_focus()

	SceneManager.mark_scene_as_loaded(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var solo_button = Button.new()
	solo_button.text = "Play solo / Revolving sushi"
	solo_button.custom_minimum_size = Vector2(0, 48)
	var buttons = $CenterContainer/VBoxContainer
	buttons.add_child(solo_button)
	buttons.move_child(solo_button, 2)
	solo_button.pressed.connect(_play_solo)
	var args = OS.get_cmdline_user_args()
	if args.has("--sushi-tour"):
		_play_solo.call_deferred()
	elif args.has("--sushi-net-host"):
		PeerManager.set_provider(ENetNetworkProvider.new("127.0.0.1", 17107))
		PeerManager.host_game.call_deferred()
	elif args.has("--sushi-net-client"):
		PeerManager.set_provider(ENetNetworkProvider.new("127.0.0.1", 17107))
		PeerManager.join_game.call_deferred()

func _play_solo() -> void:
	# PeerManager.shutdown intentionally clears the peer. Godot needs an explicit
	# offline authority for the standalone simulation and its local peer ID.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	SceneManager.start_transition_to("res://scenes/level/sushi/RevolvingSushi.tscn")

func _on_start_game_pressed() -> void:
	PeerManager.set_provider(ENetNetworkProvider.new())
	PeerManager.host_game() # Note: Scene Syncing is handled by SceneManager

func _on_join_game_pressed() -> void:
	var ip = join_ip_input.text
	if ip.is_empty():
		ip = "127.0.0.1"
	
	PeerManager.set_provider(ENetNetworkProvider.new(ip))
	PeerManager.join_game() # Note: Scene Syncing is handled by SceneManager

func _on_quit_pressed() -> void:
	get_tree().quit()

func _show_disconnection_dialog(reason: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = reason
	dialog.title = "Disconnected"
	add_child(dialog)
	dialog.popup_centered()
	LobbyManager.disconnection_reason = ""