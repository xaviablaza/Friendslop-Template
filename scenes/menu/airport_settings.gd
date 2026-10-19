extends RefCounted
## Shared with AirportChef via engine metadata, without changing the sushi variant.
var config_path = "user://airport_settings.cfg"
var master_volume = 0.8
var mouse_sensitivity = 1.0
var fullscreen = false

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(config_path) == OK:
		master_volume = clampf(float(config.get_value("audio", "master_volume", 0.8)), 0.0, 1.0)
		mouse_sensitivity = clampf(float(config.get_value("input", "mouse_sensitivity", 1.0)), 0.25, 3.0)
		fullscreen = bool(config.get_value("display", "fullscreen", false))
	apply()

func apply() -> void:
	var master = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(0.001, master_volume)))
	Engine.set_meta("airport_mouse_sensitivity", mouse_sensitivity)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func save() -> Error:
	apply()
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("display", "fullscreen", fullscreen)
	return config.save(config_path)
