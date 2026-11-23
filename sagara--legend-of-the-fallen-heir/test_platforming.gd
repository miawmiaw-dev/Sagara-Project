extends SceneTree

const BIOME2_SCENE := "res://scenes/biome2.tscn"
const BIOME3_SCENE := "res://scenes/biome3.tscn"
const DOOR_PATH := "Portals/PintuHutanPurba"
const SPAWN_PATH := "SpawnPoints/from_biome2"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var all_ok := true
	var load_error := change_scene_to_file(BIOME2_SCENE)
	print("[TEST] load biome2 error=", load_error)
	if load_error != OK:
		quit(1)
		return
	await process_frame
	await physics_frame

	var biome2 := current_scene
	var door := biome2.get_node_or_null(DOOR_PATH) if biome2 != null else null
	var player := get_first_node_in_group("player") as Node2D
	if door == null or player == null:
		print("[TEST] missing door or player in biome2")
		quit(1)
		return

	var door_locked := bool(door.call("is_locked"))
	print("[TEST] door_locked=", door_locked)
	all_ok = all_ok and door_locked

	player.global_position = door.global_position
	player.velocity = Vector2.ZERO
	await create_timer(0.35).timeout
	var blocked_while_locked := current_scene == biome2
	print("[TEST] blocked_while_locked=", blocked_while_locked)
	all_ok = all_ok and blocked_while_locked

	door.call("activate", false)
	var changed := await _wait_for_scene(biome2, 6000)
	var biome3 := current_scene
	var spawned_player := get_first_node_in_group("player") as Node2D
	var spawn_marker := biome3.get_node_or_null(SPAWN_PATH) as Node2D if biome3 != null else null
	var spawn_ok := (
		changed
		and spawned_player != null
		and spawn_marker != null
		and spawned_player.global_position.distance_to(spawn_marker.global_position) < 48.0
	)
	print("[TEST] transition_ok=", changed, " spawn_ok=", spawn_ok)
	all_ok = all_ok and spawn_ok
	if not spawn_ok or spawned_player == null or biome3 == null:
		print("[TEST] RESULT=false")
		quit(1)
		return

	var wind_zone := biome3.get_node_or_null("Platforming/AnginJurang") as Node2D
	var climb_wall := biome3.get_node_or_null("Platforming/AkarPanjat") as Node2D
	var platform := biome3.get_node_or_null("Platforming/PlatformA") as Node2D
	if wind_zone == null or climb_wall == null or platform == null:
		print("[TEST] missing platforming node in biome3")
		quit(1)
		return

	spawned_player.global_position = wind_zone.global_position
	spawned_player.velocity = Vector2.ZERO
	await create_timer(0.7).timeout
	var wind_force: Vector2 = spawned_player.get("environmental_force")
	var wind_ok := (
		wind_force.y < -100.0
		and spawned_player.global_position.y < wind_zone.global_position.y - 20.0
	)
	print("[TEST] wind_force=", wind_force, " wind_ok=", wind_ok)
	all_ok = all_ok and wind_ok

	spawned_player.global_position = Vector2(-1360.0, 500.0)
	await create_timer(0.3).timeout
	var cleared_force: Vector2 = spawned_player.get("environmental_force")
	var clear_ok := cleared_force.length() < 1.0
	print("[TEST] cleared_force=", cleared_force, " clear_ok=", clear_ok)
	all_ok = all_ok and clear_ok

	spawned_player.global_position = Vector2(-376.0, 250.0)
	spawned_player.velocity = Vector2.ZERO
	var climb_ok := false
	for _index in range(20):
		await physics_frame
		if bool(spawned_player.call("is_climbing_available")):
			climb_ok = true
			break
	print("[TEST] climb_ok=", climb_ok, " (wall=", climb_wall.name, ")")
	all_ok = all_ok and climb_ok

	var platform_start := platform.position
	await create_timer(0.6).timeout
	var platform_moved := platform.position.distance_to(platform_start) > 1.0
	print("[TEST] platform_moved=", platform_moved)
	all_ok = all_ok and platform_moved

	print("[TEST] RESULT=", all_ok)
	quit(0 if all_ok else 1)


func _wait_for_scene(previous_scene: Node, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
		if not is_instance_valid(previous_scene) or current_scene != previous_scene:
			for _frame in range(5):
				await process_frame
			return is_instance_valid(current_scene)
	return false
