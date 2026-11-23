extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var err := change_scene_to_file("res://scenes/biome2.tscn")
	print("[DBG] load biome2 err=", err)
	await process_frame
	await physics_frame
	var scene := current_scene
	var door = scene.get_node_or_null("Portals/PintuHutanPurba")
	var trigger = scene.get_node_or_null("BossEncounter/BossArenaTrigger")
	var player := get_first_node_in_group("player") as Node2D
	player.global_position = trigger.global_position
	player.velocity = Vector2.ZERO
	await create_timer(1.2).timeout
	print("[DBG] after entering arena: door_locked=", door.call("is_locked"),
		" door_active=", door.call("is_active"))
	var game_state := get_root().get_node("GameState")
	var event_bus := get_root().get_node("EventBus")
	print("[DBG] boss_active=", game_state.get("active_boss_id"))
	event_bus.emit_signal("boss_fight_ended", "Penjaga Hutan Larangan", true)
	await create_timer(0.4).timeout
	print("[DBG] after victory signal: door_locked=", door.call("is_locked"),
		" door_active=", door.call("is_active"))
	quit(0)
