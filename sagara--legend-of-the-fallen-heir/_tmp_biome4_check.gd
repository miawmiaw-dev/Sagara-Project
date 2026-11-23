extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var err := change_scene_to_file("res://scenes/biome4.tscn")
	print("[DBG4] load biome4 err=", err)
	await process_frame
	await physics_frame
	var scene := current_scene
	var player := get_first_node_in_group("player") as Node2D
	var trigger := scene.get_node("BossEncounter/BossArenaTrigger") as Node2D
	var boss := scene.get_node("BossEncounter/MurkaLeluhur")
	var gate_left := scene.get_node("BossEncounter/BossArenaGate")
	var gate_right := scene.get_node("BossEncounter/BossArenaGateExit")
	var zone_a := scene.get_node("Platforming/ZonaAntiGravitasiA") as Node2D
	var altar_guard := scene.get_node("Enemies/PenjagaAltar") as Node2D
	var game_state := get_root().get_node("GameState")
	print("[DBG4] altar_guard_x=", altar_guard.global_position.x)

	player.global_position = zone_a.global_position
	player.velocity = Vector2.ZERO
	await create_timer(0.8).timeout
	print(
		"[DBG4] gravity vy=", player.velocity.y,
		" dy=", player.global_position.y - zone_a.global_position.y
	)

	player.global_position = trigger.global_position
	player.velocity = Vector2.ZERO
	await create_timer(2.0).timeout
	print(
		"[DBG4] arena active=", game_state.get("active_boss_id"),
		" left_closed=", gate_left.call("is_closed"),
		" right_closed=", gate_right.call("is_closed"),
		" boss_visible=", boss.get("visible"),
		" boss_fighting=", boss.call("is_fight_active")
	)

	var event_bus := get_root().get_node("EventBus")
	var save_manager := get_root().get_node("SaveManager")
	if event_bus.save_requested.is_connected(save_manager.save_game):
		event_bus.save_requested.disconnect(save_manager.save_game)
	boss.call("take_damage", 99999, 0.0, 0.0)
	await create_timer(0.6).timeout
	print(
		"[DBG4] after death defeated=", game_state.call("is_boss_defeated", "murka_leluhur"),
		" left_closed=", gate_left.call("is_closed"),
		" right_closed=", gate_right.call("is_closed"),
		" active='", game_state.get("active_boss_id"), "'"
	)
	quit(0)
