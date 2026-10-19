extends GutTest

const Simulation = preload("res://scripts/sushi/sushi_simulation.gd")
var sim

func before_each():
	sim = Simulation.new()
	sim.add_player(7)

func _plate(id: int, recipe: int, phase: float, age: float = 0.0, stale: bool = false) -> Dictionary:
	return {"id": id, "recipe": recipe, "t": phase, "age": age, "stale": stale}

func _stock() -> int:
	var total: int = sim.clean_plates + sim.dirty_plates + sim.belt.size()
	for player in sim.players.values():
		total += player.tray.size() + int(player.preparing >= 0)
	return total

func test_initial_contract():
	assert_eq(sim.RECIPES, ["SALMON", "TUNA", "CUCUMBER"])
	assert_eq(sim.clean_plates, 8)
	assert_eq(sim.day, 1)
	assert_eq(sim.time_left, 120.0)
	assert_eq(sim.belt_speed, 0.035)
	assert_eq(sim.upgrades, {"tray": 0, "prep": 0, "washer": 0})
	assert_eq(sim.customers.map(func(c): return c.recipe), [0, 1, 2, 0])
	assert_eq(sim.customers.map(func(c): return c.t), [0.125, 0.375, 0.625, 0.875])

func test_preparation_reserves_plate_and_completes_after_one_point_five_seconds():
	assert_ne(sim.act(7, "prepare", 0), "")
	assert_eq(sim.clean_plates, 7)
	assert_eq(sim.players[7].preparing, 0)
	sim.update(1.0)
	assert_eq(sim.players[7].tray.size(), 0)
	assert_almost_eq(sim.players[7].prep_left, 0.5, 0.00001)
	sim.update(0.5)
	assert_eq(sim.players[7].tray, [0])
	assert_eq(sim.players[7].preparing, -1)
	assert_eq(sim.players[7].prep_left, 0.0)
	assert_eq(_stock(), 8)

func test_busy_full_invalid_and_empty_stock_preparations_do_not_consume_plates():
	sim.act(7, "prepare", -1)
	sim.act(7, "prepare", 3)
	assert_eq(sim.clean_plates, 8)
	sim.act(7, "prepare", 1)
	sim.act(7, "prepare", 2)
	assert_eq(sim.clean_plates, 7)
	sim.update(1.5)
	sim.act(7, "prepare", 2)
	assert_eq(sim.clean_plates, 7)
	sim.act(7, "load")
	sim.clean_plates = 0
	sim.act(7, "prepare", 0)
	assert_eq(sim.players[7].preparing, -1)
	assert_eq(sim.clean_plates, 0)

func test_load_is_fifo_and_plate_ids_are_unique():
	sim.money = 24
	sim.act(7, "upgrade_tray")
	for recipe in [1, 2]:
		sim.act(7, "prepare", recipe)
		sim.update(1.5)
	sim.act(7, "load")
	assert_eq(sim.players[7].tray, [2])
	assert_eq(sim.belt[0].recipe, 1)
	assert_eq(sim.belt[0].t, 0.75)
	assert_eq(sim.belt[0].age, 0.0)
	assert_false(sim.belt[0].stale)
	sim.act(7, "load")
	assert_ne(sim.belt[0].id, sim.belt[1].id)
	sim.act(7, "load")
	assert_eq(sim.belt.size(), 2)
	assert_eq(_stock(), 8)

func test_matching_crossing_earns_cash_and_dirty_plate():
	sim.belt.append(_plate(1, 0, 0.12))
	sim.update(0.2)
	assert_eq(sim.belt.size(), 0)
	assert_eq(sim.money, 8)
	assert_eq(sim.total_earned, 8)
	assert_eq(sim.shift_earned, 8)
	assert_eq(sim.served, 1)
	assert_eq(sim.dirty_plates, 1)
	assert_eq(sim.customers[0].recipe, 1)
	assert_eq(sim.customers[0].served, 1)
	assert_gt(sim.customers[0].patience, 17.9)

func test_each_recipe_has_its_expected_value():
	for recipe in range(3):
		sim = Simulation.new()
		sim.customers[0].recipe = recipe
		sim.belt.append(_plate(1, recipe, 0.12))
		sim.update(0.2)
		assert_eq(sim.money, [8, 10, 6][recipe])

func test_wrong_recipe_passes_customer():
	sim.belt.append(_plate(1, 1, 0.12))
	sim.update(0.2)
	assert_eq(sim.belt.size(), 1)
	assert_eq(sim.money, 0)
	assert_gt(sim.belt[0].t, 0.125)

func test_wraparound_crossing_is_detected():
	sim.customers[0].patience = 100.0
	sim.belt.append(_plate(1, 0, 0.99))
	sim.update(4.0)
	assert_eq(sim.served, 1)
	assert_eq(sim.belt.size(), 0)

func test_crossings_are_chronological_not_customer_or_belt_array_order():
	# On a long step the customer at .875 must take this salmon before .125.
	sim.belt.append(_plate(1, 0, 0.8))
	sim.update(10.0)
	assert_eq(sim.customers[3].served, 1)
	assert_eq(sim.customers[0].served, 0)

func test_one_plate_per_customer_per_update():
	sim.belt.append(_plate(1, 0, 0.12))
	sim.belt.append(_plate(2, 1, 0.119))
	sim.update(0.3)
	assert_eq(sim.served, 1)
	assert_eq(sim.belt.size(), 1)

func test_stale_plates_cannot_be_served_and_expire_to_dirty_stock():
	sim.belt.append(_plate(1, 0, 0.12, 32.0, true))
	sim.update(0.2)
	assert_eq(sim.served, 0)
	assert_true(sim.belt[0].stale)
	sim.belt[0].age = 63.9
	sim.update(0.2)
	assert_eq(sim.belt.size(), 0)
	assert_eq(sim.wasted, 1)
	assert_eq(sim.dirty_plates, 1)

func test_freshness_is_evaluated_at_crossing_not_end_of_large_update():
	sim.belt.append(_plate(1, 0, 0.12, 31.0))
	sim.update(2.0)
	assert_eq(sim.served, 1)
	sim.belt.append(_plate(2, 1, 0.12, 31.99))
	sim.update(0.2)
	assert_eq(sim.served, 1)
	assert_true(sim.belt[0].stale)

func test_clear_removes_only_oldest_stale_plate():
	sim.belt.append(_plate(1, 0, 0.75, 10.0))
	sim.belt.append(_plate(2, 0, 0.8, 33.0, true))
	sim.belt.append(_plate(3, 0, 0.1, 45.0, true))
	sim.act(7, "clear")
	assert_eq(sim.belt.map(func(p): return p.id), [1, 2])
	assert_eq(sim.dirty_plates, 1)
	assert_eq(sim.wasted, 1)

func test_wash_conserves_stock_and_handles_empty_sink():
	sim.clean_plates = 3
	sim.dirty_plates = 5
	sim.act(7, "wash")
	assert_eq(sim.clean_plates, 6)
	assert_eq(sim.dirty_plates, 2)
	sim.act(7, "wash")
	sim.act(7, "wash")
	assert_eq(sim.clean_plates, 8)
	assert_eq(sim.dirty_plates, 0)
	assert_eq(_stock(), 8)

func test_upgrades_require_money_are_single_use_and_affect_all_players():
	for action in ["upgrade_tray", "upgrade_prep", "upgrade_washer"]:
		sim.act(7, action)
	assert_eq(sim.upgrades, {"tray": 0, "prep": 0, "washer": 0})
	sim.money = 58
	sim.add_player(8)
	sim.act(7, "upgrade_tray")
	assert_eq(sim.money, 34)
	assert_eq(sim.players[7].capacity, 3)
	assert_eq(sim.players[8].capacity, 3)
	sim.add_player(9)
	assert_eq(sim.players[9].capacity, 3)
	sim.act(7, "upgrade_tray")
	assert_eq(sim.money, 34)
	sim.act(7, "upgrade_prep")
	sim.act(7, "prepare", 2)
	assert_eq(sim.players[7].prep_left, 0.65)
	sim.update(0.65)
	assert_eq(sim.players[7].tray, [2])
	sim.act(7, "upgrade_washer")
	assert_eq(sim.money, 0)
	sim.dirty_plates = 5
	sim.act(7, "wash")
	assert_eq(sim.dirty_plates, 0)
	assert_eq(sim.upgrades, {"tray": 1, "prep": 1, "washer": 1})

func test_tray_capacity_counts_in_progress_preparation():
	sim.money = 24
	sim.act(7, "upgrade_tray")
	for recipe in [0, 1, 2]:
		sim.act(7, "prepare", recipe)
		sim.update(1.5)
	sim.act(7, "prepare", 0)
	assert_eq(sim.players[7].tray.size(), 3)
	assert_eq(sim.players[7].preparing, -1)
	assert_eq(sim.clean_plates, 5)

func test_patience_timeout_cycles_and_retains_remainder():
	sim.update(37.0)
	assert_eq(sim.customers[0].recipe, 2)
	assert_almost_eq(sim.customers[0].patience, 17.0, 0.00001)

func test_shift_clamps_progress_and_pauses_until_next_shift():
	assert_false(sim.next_shift())
	sim.time_left = 0.5
	sim.act(7, "prepare", 0)
	sim.belt.append(_plate(1, 2, 0.0))
	sim.update(4.0)
	assert_true(sim.shift_finished)
	assert_eq(sim.time_left, 0.0)
	assert_almost_eq(sim.players[7].prep_left, 1.0, 0.00001)
	assert_almost_eq(sim.belt[0].age, 0.5, 0.00001)
	var frozen: Dictionary = sim.snapshot()
	sim.update(10.0)
	assert_eq(sim.snapshot(), frozen)
	sim.act(7, "prepare", 1)
	sim.act(7, "load")
	assert_eq(sim.clean_plates, 7)
	assert_eq(sim.belt.size(), 1)
	sim.money = 30
	sim.shift_earned = 8
	assert_true(sim.next_shift())
	assert_eq(sim.day, 2)
	assert_eq(sim.time_left, 120.0)
	assert_false(sim.shift_finished)
	assert_eq(sim.money, 30)
	assert_eq(sim.shift_earned, 0)
	assert_eq(sim.belt.size(), 1)
	sim.update(1.0)
	assert_eq(sim.players[7].tray, [0])

func test_finished_shift_allows_housekeeping_and_upgrades():
	sim.shift_finished = true
	sim.dirty_plates = 4
	sim.act(7, "wash")
	assert_eq(sim.dirty_plates, 1)
	sim.belt.append(_plate(1, 0, 0.75, 40.0, true))
	sim.act(7, "clear")
	assert_eq(sim.belt.size(), 0)
	sim.money = 24
	sim.act(7, "upgrade_tray")
	assert_eq(sim.players[7].capacity, 3)

func test_snapshot_is_deep_copied_and_restores_integer_player_keys():
	sim.act(7, "prepare", 1)
	sim.belt.append(_plate(10, 2, 0.2))
	var data: Dictionary = sim.snapshot()
	var restored = Simulation.new()
	restored.apply_snapshot(data)
	assert_eq(restored.snapshot(), data)
	assert_true(restored.players.has(7))
	assert_false(restored.players.has("7"))
	data.players[7].capacity = 99
	data.belt[0].recipe = 0
	data.customers[0].recipe = 2
	assert_eq(sim.players[7].capacity, 1)
	assert_eq(restored.players[7].capacity, 1)
	assert_eq(restored.belt[0].recipe, 2)
	assert_eq(restored.customers[0].recipe, 0)
	restored.update(1.5)
	assert_eq(restored.players[7].tray, [1])
	assert_eq(sim.players[7].tray.size(), 0)

func test_snapshot_continuation_is_deterministic_and_keeps_plate_id_sequence():
	sim.act(7, "prepare", 0)
	sim.update(1.5)
	sim.act(7, "load")
	var first_plate_id: int = sim.belt[0].id
	sim.act(7, "prepare", 2)
	var restored = Simulation.new()
	restored.apply_snapshot(sim.snapshot())
	for delta in [0.5, 1.0, 4.0, 8.0]:
		sim.update(delta)
		restored.update(delta)
	sim.act(7, "load")
	restored.act(7, "load")
	assert_eq(restored.snapshot(), sim.snapshot())
	assert_eq(sim.belt.size(), 1)
	assert_ne(sim.belt[0].id, first_plate_id)

func test_disconnect_returns_ready_and_in_progress_plates_once():
	sim.money = 24
	sim.act(7, "upgrade_tray")
	sim.act(7, "prepare", 0)
	sim.update(1.5)
	sim.act(7, "prepare", 1)
	sim.add_player(7)
	assert_eq(sim.clean_plates, 6)
	sim.remove_player(7)
	assert_eq(sim.clean_plates, 8)
	assert_false(sim.players.has(7))
	sim.remove_player(7)
	assert_eq(sim.clean_plates, 8)

func test_invalid_actions_and_unknown_players_leave_economy_unchanged():
	var before: Dictionary = sim.snapshot()
	assert_ne(sim.act(999, "prepare", 0), "")
	assert_ne(sim.act(7, "nonsense"), "")
	assert_eq(sim.clean_plates, before.clean_plates)
	assert_eq(sim.money, before.money)
	assert_eq(sim.players, before.players)
	assert_ne(sim.last_event, "")

func test_full_prepare_load_serve_wash_loop_conserves_eight_plates():
	sim.act(7, "prepare", 0)
	sim.update(1.5)
	sim.act(7, "load")
	assert_eq(_stock(), 8)
	sim.update(4.0)
	assert_eq(sim.served, 1)
	assert_eq(sim.clean_plates, 7)
	assert_eq(sim.dirty_plates, 1)
	assert_eq(_stock(), 8)
	sim.act(7, "wash")
	assert_eq(sim.clean_plates, 8)
	assert_eq(_stock(), 8)

func test_large_delta_detects_crossing_after_full_wrap_and_normalizes_position():
	for customer in sim.customers:
		customer.patience = 100.0
		customer.recipe = 2
	sim.customers[0].recipe = 0
	sim.belt.append(_plate(1, 0, 0.2))
	sim.belt.append(_plate(2, 1, 0.9))
	sim.update(30.0)
	assert_eq(sim.customers[0].served, 1)
	assert_eq(sim.belt.size(), 1)
	assert_almost_eq(sim.belt[0].t, 0.95, 0.00001)

func test_plate_at_exact_stale_threshold_is_not_served():
	sim.belt_speed = 0.125
	sim.belt.append(_plate(1, 0, 0.0, 31.0))
	sim.update(1.0)
	assert_eq(sim.served, 0)
	assert_true(sim.belt[0].stale)
	assert_eq(sim.belt[0].age, 32.0)

func test_same_time_crossings_use_stable_fifo_tie_breaking():
	sim.belt.append(_plate(2, 0, 0.12))
	sim.belt.append(_plate(1, 0, 0.12))
	sim.update(0.2)
	assert_eq(sim.served, 1)
	assert_eq(sim.belt[0].id, 1)

func test_enet_variant_snapshot_round_trip_preserves_integer_peer_ids():
	var peer_id: int = 2147483647
	sim.add_player(peer_id)
	sim.act(peer_id, "prepare", 2)
	var encoded: PackedByteArray = var_to_bytes(sim.snapshot())
	var restored = Simulation.new()
	restored.apply_snapshot(bytes_to_var(encoded))
	assert_true(restored.players.has(peer_id))
	assert_eq(restored.snapshot(), sim.snapshot())
	restored.update(1.5)
	assert_eq(restored.players[peer_id].tray, [2])

func test_zero_speed_still_ages_plates_and_advances_customer_patience():
	sim.belt_speed = 0.0
	sim.belt.append(_plate(1, 0, 0.12, 31.0))
	sim.update(2.0)
	assert_eq(sim.served, 0)
	assert_eq(sim.belt[0].t, 0.12)
	assert_true(sim.belt[0].stale)
	assert_eq(sim.customers[0].patience, 16.0)

func test_nonpositive_or_nonfinite_delta_is_ignored():
	var before: Dictionary = sim.snapshot()
	for delta in [0.0, -1.0, INF, NAN]:
		sim.update(delta)
	assert_eq(sim.snapshot(), before)
