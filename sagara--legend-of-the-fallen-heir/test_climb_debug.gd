extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var err := change_scene_to_file("res://scenes/biome3.tscn")
	print("[DBG] load err=", err)
	await process_frame
	await physics_frame
	var scene := current_scene
	var player := get_first_node_in_group("player") as Node2D
	var wall := scene.get_node_or_null("Platforming/AkarPanjat") as Area2D
	wall.body_entered.connect(func(b): print("[DBG] body_entered ", b))
	wall.body_exited.connect(func(b): print("[DBG] body_exited ", b))
	await create_timer(0.7).timeout
	player.global_position = Vector2(-1360.0, 500.0)
	await create_timer(0.3).timeout
	print("[DBG] before teleport player=", player.global_position,
		" state=", player.get_node("StateMachine").current_state_name,
		" contacts=", player.get("_climb_contacts"))
	player.global_position = Vector2(-376.0, 250.0)
	player.velocity = Vector2.ZERO
	await physics_frame
	print("[DBG] after 1 frame contacts=", player.get("_climb_contacts"),
		" avail=", player.call("is_climbing_available"))
	await physics_frame
	print("[DBG] after 2 frames contacts=", player.get("_climb_contacts"),
		" avail=", player.call("is_climbing_available"))
	await physics_frame
	print("[DBG] after 3 frames contacts=", player.get("_climb_contacts"),
		" avail=", player.call("is_climbing_available"))
	quit(0)
