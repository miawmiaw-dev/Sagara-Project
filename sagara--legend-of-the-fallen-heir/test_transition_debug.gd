extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var err := change_scene_to_file("res://scenes/biome2.tscn")
	print("[DBG] load biome2 err=", err)
	await process_frame
	await physics_frame
	var scene := current_scene
	var door := scene.get_node_or_null("Portals/PintuHutanPurba")
	var player := get_first_node_in_group("player") as Node2D
	print("[DBG] door=", door, " locked=", door.call("is_locked") if door else "n/a",
		" player=", player)
	player.global_position = door.global_position
	player.velocity = Vector2.ZERO
	await create_timer(0.3).timeout
	print("[DBG] still scene=", current_scene.name if is_instance_valid(current_scene) else "null",
		" (locked feedback expected)")
	door.call("activate", false)
	await create_timer(0.2).timeout
	for i in range(120):
		await process_frame
		if is_instance_valid(current_scene) and current_scene != scene:
			break
	var new_scene := current_scene
	var new_player := get_first_node_in_group("player") as Node2D
	print("[DBG] after transition: scene=", new_scene.name if is_instance_valid(new_scene) else "null",
		" pos=", new_player.global_position if is_instance_valid(new_player) else "n/a",
		" tag=", get_root().get_node("LevelTransition").peek_spawn_tag())
	await create_timer(0.8).timeout
	new_player = get_first_node_in_group("player") as Node2D
	print("[DBG] settled: scene=", current_scene.name if is_instance_valid(current_scene) else "null",
		" pos=", new_player.global_position if is_instance_valid(new_player) else "n/a",
		" transitioning=", get_root().get_node("LevelTransition").is_transitioning())
	quit(0)
