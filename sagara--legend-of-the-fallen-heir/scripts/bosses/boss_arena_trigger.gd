class_name BossArenaTrigger
extends Area2D

const PLAYER_BODY_LAYER := 1
const DEFAULT_BOSS_SCENE_PATH := "res://scenes/bosses/boss_forest_guardian.tscn"
const PLAYER_NAME_FALLBACKS := [&"Player", &"Sagara"]
const OVERLAP_POLL_INTERVAL := 0.15
const RETRY_COOLDOWN := 0.75
const INTRUDER_SWEEP_INTERVAL := 0.5

@export_group("Boss")
@export var boss_scene: PackedScene
@export var boss_path: NodePath
@export var boss_spawn_marker_path: NodePath
@export var boss_spawn_offset: Vector2 = Vector2.ZERO
@export var boss_parent_path: NodePath
@export var boss_group: String = "boss"
@export var boss_id: String = "penjaga_hutan_larangan"
@export var allow_rematch: bool = false
@export var debug_logging: bool = true

@export_group("Arena")
@export var gate_path: NodePath
@export var gate_group: String = "boss_gate"
@export var gate_paths: Array[NodePath] = []
@export var lock_arena: bool = true
@export var isolate_arena: bool = true
@export var intruder_group: String = "enemy"
@export var arena_left_marker_path: NodePath
@export var arena_right_marker_path: NodePath
@export var arena_top_marker_path: NodePath
@export var arena_bottom_marker_path: NodePath

@export_group("Isolation")
## Arena boss wajib menjadi ruangan tertutup. Bila gate tidak lengkap, trigger
## membuat barrier darurat agar pertarungan tetap 1v1 dan pemain tidak lolos.
@export var require_enclosed_arena: bool = true
@export var auto_build_barriers: bool = true
@export var barrier_thickness: float = 32.0
@export var intruder_margin: float = 6.0

@export_group("Exit")
@export var exit_portal_group: String = "boss_exit_portal"

@export_group("Player")
@export var player_group: String = "player"

var _boss: Node = null
var _pending_player: Node2D = null
var _triggered: bool = false
var _starting: bool = false
var _encounter_ready: bool = false
var _encounter_sealed: bool = false
var _arena_validated: bool = false
var _poll_timer: float = 0.0
var _retry_timer: float = 0.0
var _intruder_sweep_timer: float = 0.0
var _fallback_barriers: Array[StaticBody2D] = []


func _ready() -> void:
	if allow_rematch and GameState.is_boss_defeated(boss_id):
		GameState.reset_boss_status(boss_id)
		_log("status kekalahan boss '%s' direset saat ready." % boss_id)

	collision_layer = 0
	collision_mask = PLAYER_BODY_LAYER
	monitorable = false
	monitoring = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	if not EventBus.boss_fight_ended.is_connected(_on_boss_fight_ended):
		EventBus.boss_fight_ended.connect(_on_boss_fight_ended)
	if not EventBus.player_respawned.is_connected(_on_player_respawned):
		EventBus.player_respawned.connect(_on_player_respawned)

	_log(
		"ready: node=%s global_position=%s mask=%d group=%s boss_id=%s"
		% [name, global_position, collision_mask, player_group, boss_id]
	)
	_ensure_trigger_covers_arena()
	call_deferred("_prepare_encounter")


func _physics_process(delta: float) -> void:
	if _triggered:
		# Selama boss hidup, jangan pernah biarkan musuh biasa berada di arena.
		if _encounter_sealed and isolate_arena:
			_intruder_sweep_timer += delta
			if _intruder_sweep_timer >= INTRUDER_SWEEP_INTERVAL:
				_intruder_sweep_timer = 0.0
				_clear_arena_intruders()
				_maintain_arena_seal()
		return

	if not _encounter_ready:
		return

	_retry_timer = maxf(_retry_timer - delta, 0.0)
	_poll_timer += delta
	if _poll_timer < OVERLAP_POLL_INTERVAL:
		return
	_poll_timer = 0.0

	if _starting or _retry_timer > 0.0:
		return

	for body in get_overlapping_bodies():
		if _is_player(body):
			_log("polling: pemain '%s' masih berada di area trigger." % body.name)
			_try_trigger(body)
			return


func _ensure_trigger_covers_arena() -> void:
	var arena_rect := _get_arena_rect()
	if arena_rect.size.x <= 0.0 or arena_rect.size.y <= 0.0:
		return
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rectangle := shape_node.shape as RectangleShape2D
	if rectangle == null:
		return

	# Shape subresource dipakai bersama oleh semua instance trigger. Duplikasi
	# dulu supaya arena satu biome tidak mengubah ukuran trigger biome lain.
	rectangle = rectangle.duplicate() as RectangleShape2D
	rectangle.size = Vector2(rectangle.size.x, arena_rect.size.y)
	shape_node.shape = rectangle
	shape_node.position = Vector2(
		shape_node.position.x,
		arena_rect.get_center().y - global_position.y
	)

	var threshold := get_node_or_null("Threshold") as ColorRect
	if threshold != null:
		threshold.offset_top = shape_node.position.y - arena_rect.size.y * 0.5
		threshold.offset_bottom = shape_node.position.y + arena_rect.size.y * 0.5


func _prepare_encounter() -> void:
	await get_tree().physics_frame
	if not is_inside_tree() or _triggered:
		return

	_encounter_ready = true
	_prepare_preplaced_boss()
	_validate_arena_enclosure()
	_set_gates_closed(false, false)

	if lock_arena and _collect_gates().is_empty() and _fallback_barriers.is_empty():
		if not _is_unconfigured_template():
			push_warning(
				"BossArenaTrigger: tidak ada Boss Room Gate yang terhubung untuk arena '%s'."
				% boss_id
			)

	if allow_rematch and GameState.is_boss_defeated(boss_id):
		GameState.reset_boss_status(boss_id)
		_log(
			"status kekalahan boss '%s' direset agar pertarungan bisa diulang." % boss_id
		)

	if GameState.is_boss_defeated(boss_id):
		_triggered = true
		_encounter_sealed = false
		_set_gates_closed(false, false)
		_set_exit_portals_active(true)
		_log("encounter dilewati: boss '%s' sudah ditandai dikalahkan di save." % boss_id)
		return

	_log("encounter siap; memeriksa apakah pemain sudah berada di dalam area.")

	if is_instance_valid(_pending_player):
		var pending := _pending_player
		_pending_player = null
		_try_trigger(pending)
		return

	for body in get_overlapping_bodies():
		if _is_player(body):
			_try_trigger(body)
			return


func _is_player(candidate: Node) -> bool:
	if not is_instance_valid(candidate) or not candidate is Node2D:
		return false

	if not player_group.is_empty() and candidate.is_in_group(player_group):
		return true

	for expected_name in PLAYER_NAME_FALLBACKS:
		if candidate.name == expected_name:
			return true

	return false


func _on_body_entered(body: Node2D) -> void:
	if debug_logging:
		print(
			"[BossArenaTrigger:%s] body_entered -> %s | is_player=%s"
			% [boss_id, body.name, _is_player(body)]
		)
	if _is_player(body):
		_pending_player = body
	_try_trigger(body)


func _on_body_exited(body: Node2D) -> void:
	if not _is_player(body):
		return
	if _pending_player == body:
		_pending_player = null
	_log("body_exited: pemain '%s' meninggalkan area trigger." % body.name)


func _try_trigger(body: Node2D) -> void:
	if _triggered or _starting:
		return
	if not _is_player(body):
		return

	if not _encounter_ready:
		_pending_player = body
		_log("sinyal diterima sebelum encounter siap; menunggu polling berikutnya.")
		return

	if GameState.is_boss_defeated(boss_id):
		_triggered = true
		_set_gates_closed(false)
		_set_exit_portals_active(true)
		_log("trigger diabaikan: boss '%s' sudah dikalahkan." % boss_id)
		return

	# Segel arena segera, bahkan sebelum _start_encounter yang deferred berjalan.
	# Ini mencegah pemain melesat melewati gate saat frame pergantian state.
	_starting = true
	_set_exit_portals_active(false)
	_set_gates_closed(true)
	if isolate_arena:
		_clear_arena_intruders()
	_log(
		"pemain '%s' memasuki arena '%s' pada %s; memulai encounter."
		% [body.name, boss_id, body.global_position]
	)
	call_deferred("_start_encounter", body)


func _start_encounter(body: Node2D) -> void:
	_pending_player = null
	if _triggered or not _is_player(body):
		_starting = false
		return

	if allow_rematch and GameState.is_boss_defeated(boss_id):
		GameState.reset_boss_status(boss_id)

	if GameState.is_boss_defeated(boss_id):
		_triggered = true
		_starting = false
		_set_gates_closed(false)
		_set_exit_portals_active(true)
		_log("encounter dibatalkan: boss '%s' sudah dikalahkan." % boss_id)
		return

	_set_exit_portals_active(false)
	_set_gates_closed(true)
	if isolate_arena:
		_clear_arena_intruders()
	_log("gerbang arena ditutup; menyiapkan boss '%s'." % boss_id)

	var boss := _ensure_boss()
	if (
		boss == null
		or not is_instance_valid(boss)
		or boss.is_queued_for_deletion()
		or not boss.is_inside_tree()
		or not boss.has_method("activate_fight")
	):
		_starting = false
		_retry_timer = RETRY_COOLDOWN
		_set_gates_closed(false)
		_log("GAGAL memulai encounter: boss tidak valid atau tidak punya activate_fight().")
		return

	var boss_position := Vector2.ZERO
	if boss is Node2D:
		boss_position = (boss as Node2D).global_position

	_log(
		"memanggil activate_fight() pada '%s' (instance_id=%d, global_position=%s)."
		% [boss.name, boss.get_instance_id(), boss_position]
	)
	var activated := bool(boss.call("activate_fight", body))
	_starting = false

	if activated:
		_triggered = true
		_set_gates_closed(true)
		_log("boss fight DIMULAI; trigger dikunci.")
		return

	if boss.has_method("is_fight_active") and bool(boss.call("is_fight_active")):
		_triggered = true
		_set_gates_closed(true)
		_log("activate_fight() mengembalikan false, tetapi fight sudah aktif; trigger dikunci.")
		return

	_retry_timer = RETRY_COOLDOWN
	_set_gates_closed(false)
	_log("activate_fight() mengembalikan false; encounter akan dicoba lagi.")


func _find_existing_boss() -> Node:
	if is_instance_valid(_boss) and _is_valid_boss(_boss):
		if not _boss.is_queued_for_deletion():
			return _boss

	_boss = null
	if not boss_path.is_empty():
		var path_candidate := get_node_or_null(boss_path)
		if _is_valid_boss(path_candidate):
			return path_candidate

	for candidate in get_tree().get_nodes_in_group(boss_group):
		if _is_valid_boss(candidate):
			return candidate

	return null


func _is_valid_boss(candidate: Node) -> bool:
	return (
		is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and candidate.has_method("activate_fight")
		and candidate.is_in_group(boss_group)
	)


func _prepare_preplaced_boss() -> void:
	if _starting or _triggered:
		return

	var existing := _find_existing_boss()
	if existing == null:
		return

	if boss_scene == null:
		var scene_path := existing.scene_file_path
		if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
			boss_scene = load(scene_path) as PackedScene

	_boss = null
	_ensure_boss_in_arena(existing)

	if existing.has_method("set_dormant"):
		existing.call("set_dormant")
	elif existing is CanvasItem:
		(existing as CanvasItem).visible = false

	_log("boss awal '%s' disiapkan ulang tanpa menghapus instance." % existing.name)


func _ensure_boss() -> Node:
	var existing := _find_existing_boss()
	if existing != null:
		_boss = existing
		_apply_boss_id(_boss)
		_ensure_boss_in_arena(_boss)
		_configure_boss_arena(_boss)
		_log("memakai boss yang sudah ada: '%s'." % _boss.name)
		return _boss

	var spawned := _spawn_boss()
	if spawned == null:
		return null

	_ensure_boss_in_arena(spawned)
	_configure_boss_arena(spawned)
	return spawned


func _resolve_boss_scene() -> PackedScene:
	if boss_scene != null:
		return boss_scene

	if ResourceLoader.exists(DEFAULT_BOSS_SCENE_PATH):
		boss_scene = load(DEFAULT_BOSS_SCENE_PATH) as PackedScene
		if boss_scene != null:
			_log("boss_scene kosong; memakai scene default %s." % DEFAULT_BOSS_SCENE_PATH)
	return boss_scene


func _spawn_boss() -> Node:
	var scene := _resolve_boss_scene()
	if scene == null:
		push_warning(
			"BossArenaTrigger: boss_scene belum diatur untuk boss '%s'." % boss_id
		)
		_log("GAGAL spawn: boss_scene null dan scene default tidak ditemukan.")
		return null

	var parent := _resolve_boss_parent()
	if parent == null or not is_instance_valid(parent) or parent.is_queued_for_deletion():
		push_warning("BossArenaTrigger: parent untuk boss tidak ditemukan.")
		_log("GAGAL spawn: parent boss tidak ditemukan.")
		return null
	if not parent.is_inside_tree():
		push_warning("BossArenaTrigger: parent boss belum berada di dalam scene tree.")
		_log("GAGAL spawn: parent '%s' belum berada di scene tree." % parent.name)
		return null

	var spawn_position := _get_boss_spawn_position()
	if not _is_finite_position(spawn_position):
		spawn_position = global_position

	if debug_logging:
		print(
			"[BossArenaTrigger:%s] spawn boss scene=%s parent=%s global_position=%s"
			% [boss_id, scene.resource_path, parent.get_path(), spawn_position]
		)

	var instance := scene.instantiate()
	if instance == null:
		push_warning("BossArenaTrigger: gagal membuat instance boss.")
		_log("GAGAL spawn: instantiate() mengembalikan null.")
		return null

	_apply_boss_id(instance)

	if not instance.is_in_group(boss_group):
		instance.add_to_group(boss_group)

	if instance is Node2D and parent is Node2D:
		(instance as Node2D).position = (parent as Node2D).to_local(spawn_position)

	parent.add_child(instance)

	if instance is Node2D:
		var boss_node := instance as Node2D
		boss_node.global_position = spawn_position
		boss_node.set_physics_process(true)
		boss_node.visible = true
		boss_node.modulate.a = 1.0

	_boss = instance

	if not is_instance_valid(_boss) or _boss.is_queued_for_deletion():
		_log("GAGAL spawn: boss langsung tidak valid setelah add_child().")
		_boss = null
		return null

	if _boss is Node2D:
		var boss_node := _boss as Node2D
		if not boss_node.global_position.is_equal_approx(spawn_position):
			boss_node.global_position = spawn_position
		if debug_logging:
			print(
				"[BossArenaTrigger:%s] boss OK: name=%s instance_id=%d parent=%s global_position=%s"
				% [
					boss_id,
					boss_node.name,
					boss_node.get_instance_id(),
					boss_node.get_parent().get_path(),
					boss_node.global_position,
				]
			)
	else:
		_log("boss OK: '%s' (instance_id=%d)." % [_boss.name, _boss.get_instance_id()])

	return _boss


func _resolve_boss_parent() -> Node:
	if not boss_parent_path.is_empty():
		var path_candidate := get_node_or_null(boss_parent_path)
		if is_instance_valid(path_candidate) and path_candidate.is_inside_tree():
			return path_candidate
		_log(
			"boss_parent_path '%s' tidak valid; memakai current_scene."
			% str(boss_parent_path)
		)

	var current_scene := get_tree().current_scene
	if is_instance_valid(current_scene) and current_scene.is_inside_tree():
		return current_scene

	var parent := get_parent()
	if parent != null and parent.is_inside_tree():
		return parent

	return null


func _get_boss_spawn_position() -> Vector2:
	var spawn_position := global_position
	var marker_found := false

	if not boss_spawn_marker_path.is_empty():
		var marker := get_node_or_null(boss_spawn_marker_path)
		if marker is Node2D:
			var marker_position := (marker as Node2D).global_position
			if _is_finite_position(marker_position):
				spawn_position = marker_position
				marker_found = true
				_log("marker spawn ditemukan di %s." % spawn_position)
			else:
				push_warning(
					"BossArenaTrigger: marker spawn '%s' memiliki posisi tidak valid."
					% str(boss_spawn_marker_path)
				)
		else:
			push_warning(
				"BossArenaTrigger: marker spawn '%s' tidak ditemukan."
				% str(boss_spawn_marker_path)
			)

	var left_x := _get_marker_x(arena_left_marker_path)
	var right_x := _get_marker_x(arena_right_marker_path)

	if not marker_found:
		if not boss_spawn_offset.is_zero_approx():
			spawn_position = global_position + boss_spawn_offset
		elif not is_nan(left_x) and not is_nan(right_x) and left_x < right_x:
			spawn_position = Vector2((left_x + right_x) * 0.5, global_position.y)
		_log("tidak ada marker spawn; memakai posisi fallback %s." % spawn_position)

	var arena_rect := _get_arena_rect()
	if arena_rect.size.x > 0.0:
		var margin := maxf(intruder_margin, 1.0)
		var clamped := Vector2(
			clampf(spawn_position.x, arena_rect.position.x + margin, arena_rect.end.x - margin),
			clampf(spawn_position.y, arena_rect.position.y + margin, arena_rect.end.y - margin)
		)
		if not clamped.is_equal_approx(spawn_position):
			_log("posisi spawn %s berada di luar arena; diklem ke %s." % [spawn_position, clamped])
			spawn_position = clamped
	elif not is_nan(left_x) and not is_nan(right_x) and left_x < right_x:
		var clamped_x := clampf(spawn_position.x, left_x, right_x)
		if not is_equal_approx(clamped_x, spawn_position.x):
			_log(
				"posisi spawn x=%f berada di luar arena; diklem ke %f."
				% [spawn_position.x, clamped_x]
			)
			spawn_position.x = clamped_x

	return spawn_position


func _get_marker_x(marker_path: NodePath) -> float:
	if marker_path.is_empty():
		return NAN
	var marker := get_node_or_null(marker_path)
	if marker is Node2D:
		var marker_x := (marker as Node2D).global_position.x
		return marker_x if not is_nan(marker_x) and not is_inf(marker_x) else NAN
	return NAN


func _get_marker_y(marker_path: NodePath) -> float:
	if marker_path.is_empty():
		return NAN
	var marker := get_node_or_null(marker_path)
	if marker is Node2D:
		var marker_y := (marker as Node2D).global_position.y
		return marker_y if not is_nan(marker_y) and not is_inf(marker_y) else NAN
	return NAN


func _has_any_arena_marker() -> bool:
	return (
		not arena_left_marker_path.is_empty()
		or not arena_right_marker_path.is_empty()
		or not arena_top_marker_path.is_empty()
		or not arena_bottom_marker_path.is_empty()
	)


func _is_unconfigured_template() -> bool:
	return (
		boss_scene == null
		and boss_path.is_empty()
		and boss_spawn_marker_path.is_empty()
		and gate_path.is_empty()
		and gate_paths.is_empty()
		and not _has_any_arena_marker()
	)


func _get_arena_rect() -> Rect2:
	var left_x := _get_marker_x(arena_left_marker_path)
	var right_x := _get_marker_x(arena_right_marker_path)
	if is_nan(left_x) or is_nan(right_x) or left_x >= right_x:
		return Rect2()

	var top_y := _get_marker_y(arena_top_marker_path)
	var bottom_y := _get_marker_y(arena_bottom_marker_path)
	if is_nan(top_y) or is_nan(bottom_y):
		top_y = global_position.y - 260.0
		bottom_y = global_position.y + 260.0
	if top_y > bottom_y:
		var swap := top_y
		top_y = bottom_y
		bottom_y = swap

	return Rect2(
		Vector2(left_x, top_y),
		Vector2(right_x - left_x, bottom_y - top_y)
	)


func _point_inside_arena(point: Vector2) -> bool:
	var arena_rect := _get_arena_rect()
	if arena_rect.size.x > 0.0:
		return arena_rect.grow(maxf(intruder_margin, 0.0)).has_point(point)
	var left_x := _get_marker_x(arena_left_marker_path)
	var right_x := _get_marker_x(arena_right_marker_path)
	if is_nan(left_x) or is_nan(right_x) or left_x >= right_x:
		return true
	return point.x >= left_x - intruder_margin and point.x <= right_x + intruder_margin


func _ensure_boss_in_arena(boss: Node) -> void:
	if not is_instance_valid(boss) or not boss is Node2D:
		return
	var arena_rect := _get_arena_rect()
	if arena_rect.size.x <= 0.0:
		return

	var margin := maxf(intruder_margin, 1.0)
	var clamped := Vector2(
		clampf((boss as Node2D).global_position.x, arena_rect.position.x + margin, arena_rect.end.x - margin),
		clampf((boss as Node2D).global_position.y, arena_rect.position.y + margin, arena_rect.end.y - margin)
	)
	if clamped.is_equal_approx((boss as Node2D).global_position):
		return

	_log(
		"boss '%s' berada di luar arena; dipindahkan dari %s ke %s."
		% [boss.name, (boss as Node2D).global_position, clamped]
	)
	if boss.has_method("set_home_position"):
		boss.call("set_home_position", clamped)
	else:
		(boss as Node2D).global_position = clamped


func _validate_arena_enclosure() -> void:
	if _arena_validated:
		return
	_arena_validated = true
	if not require_enclosed_arena:
		return

	var arena_rect := _get_arena_rect()
	if arena_rect.size.x <= 0.0:
		if not _is_unconfigured_template():
			push_error(
				(
					"BossArenaTrigger '%s': marker ArenaLeft/ArenaRight tidak lengkap; "
					+ "arena boss tidak dapat divalidasi."
				) % boss_id
			)
		return

	if is_nan(_get_marker_y(arena_top_marker_path)) or is_nan(_get_marker_y(arena_bottom_marker_path)):
		push_warning(
			(
				"BossArenaTrigger '%s': marker ArenaTop/ArenaBottom belum diatur. "
				+ "Isolasi vertikal mengandalkan geometri ruangan."
			) % boss_id
		)

	if not auto_build_barriers:
		return

	var gates := _collect_gates()
	var center_x := arena_rect.get_center().x
	var has_left_gate := false
	var has_right_gate := false
	for gate in gates:
		if gate is Node2D:
			if (gate as Node2D).global_position.x <= center_x:
				has_left_gate = true
			else:
				has_right_gate = true

	if not has_left_gate:
		_create_fallback_barrier(
			Vector2(arena_rect.position.x, arena_rect.get_center().y),
			arena_rect.size.y,
			"FallbackBarrierLeft"
		)
	if not has_right_gate:
		_create_fallback_barrier(
			Vector2(arena_rect.end.x, arena_rect.get_center().y),
			arena_rect.size.y,
			"FallbackBarrierRight"
		)


func _create_fallback_barrier(barrier_position: Vector2, height: float, barrier_name: String) -> void:
	var barrier := StaticBody2D.new()
	barrier.name = barrier_name
	barrier.collision_layer = PLAYER_BODY_LAYER
	barrier.collision_mask = 0
	add_child(barrier)
	barrier.global_position = barrier_position

	var shape_node := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(maxf(barrier_thickness, 1.0), maxf(height, 1.0))
	shape_node.shape = rectangle
	shape_node.disabled = true
	barrier.add_child(shape_node)

	var visual := ColorRect.new()
	visual.name = "Visual"
	visual.color = Color(0.09, 0.06, 0.11, 0.92)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.visible = false
	visual.offset_left = -barrier_thickness * 0.5
	visual.offset_right = barrier_thickness * 0.5
	visual.offset_top = -height * 0.5
	visual.offset_bottom = height * 0.5
	barrier.add_child(visual)

	_fallback_barriers.append(barrier)
	_log("barrier darurat '%s' dibuat karena gate tidak lengkap." % barrier_name)


func _set_fallback_barriers_closed(closed: bool) -> void:
	for barrier in _fallback_barriers:
		if not is_instance_valid(barrier):
			continue
		var shape_node := barrier.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if is_instance_valid(shape_node):
			shape_node.set_deferred("disabled", not closed)
		var visual := barrier.get_node_or_null("Visual") as CanvasItem
		if is_instance_valid(visual):
			visual.visible = closed


func _is_finite_position(candidate_position: Vector2) -> bool:
	return (
		not is_nan(candidate_position.x)
		and not is_nan(candidate_position.y)
		and not is_inf(candidate_position.x)
		and not is_inf(candidate_position.y)
	)


func _apply_boss_id(boss: Node) -> void:
	if not is_instance_valid(boss):
		return
	if boss.has_method("set_boss_id"):
		boss.call("set_boss_id", boss_id)


func _configure_boss_arena(boss: Node) -> void:
	if not is_instance_valid(boss) or not boss.has_method("configure_arena"):
		return

	var left_x := _get_marker_x(arena_left_marker_path)
	var right_x := _get_marker_x(arena_right_marker_path)
	if is_nan(left_x) or is_nan(right_x) or left_x >= right_x:
		return

	boss.call("configure_arena", left_x, right_x)
	_log("arena boss dikonfigurasi: x=%f..%f." % [left_x, right_x])


func _clear_arena_intruders() -> void:
	if intruder_group.is_empty():
		return
	for node in get_tree().get_nodes_in_group(intruder_group):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node.is_in_group(boss_group) or node == _boss:
			continue
		if not node is Node2D:
			continue
		if not _point_inside_arena((node as Node2D).global_position):
			continue
		_log("musuh '%s' berada di dalam arena; dihapus untuk isolasi 1v1." % node.name)
		node.queue_free()


func _collect_gates() -> Array[Node]:
	var gates: Array[Node] = []
	var found: Dictionary = {}

	if not gate_path.is_empty():
		_add_gate(gates, found, get_node_or_null(gate_path))

	for path in gate_paths:
		if path.is_empty():
			continue
		_add_gate(gates, found, get_node_or_null(path))

	# Path eksplisit selalu menang agar arena tidak mengambil gate milik
	# encounter lain yang kebetulan berada di scene yang sama.
	if not gates.is_empty():
		return gates

	if not gate_group.is_empty():
		for candidate in get_tree().get_nodes_in_group(gate_group):
			_add_gate(gates, found, candidate)

	return gates


func _add_gate(gates: Array[Node], found: Dictionary, gate: Node) -> void:
	if not is_instance_valid(gate) or gate.is_queued_for_deletion():
		return
	var instance_id := gate.get_instance_id()
	if found.has(instance_id):
		return
	found[instance_id] = true
	gates.append(gate)


func _maintain_arena_seal() -> void:
	if not lock_arena:
		return
	for gate in _collect_gates():
		if gate.has_method("is_closed") and not bool(gate.call("is_closed")):
			_set_gates_closed(true, false)
			return


func _set_gates_closed(closed: bool, animated: bool = true) -> void:
	if not lock_arena:
		return

	_encounter_sealed = closed
	for gate in _collect_gates():
		if closed:
			if gate.has_method("close_gate"):
				gate.call("close_gate", animated)
		elif gate.has_method("open_gate"):
			gate.call("open_gate", animated)
	_set_fallback_barriers_closed(closed)


func _on_boss_fight_ended(_boss_name: String, victory: bool) -> void:
	if not _triggered:
		return

	if victory:
		# Hanya buka arena jika flag kemenangan benar-benar milik boss ini.
		if not GameState.is_boss_defeated(boss_id):
			_log("event kemenangan boss lain diabaikan; arena tetap terkunci.")
			return
	elif (
		is_instance_valid(_boss)
		and _boss.has_method("is_fight_active")
		and bool(_boss.call("is_fight_active"))
	):
		_log("event kekalahan boss lain diabaikan; pertarungan masih berjalan.")
		return

	_triggered = victory
	_starting = false
	_encounter_sealed = false
	_set_gates_closed(false)
	if victory:
		_set_exit_portals_active(true)
	else:
		_set_exit_portals_active(false)
	_log(
		"boss fight selesai; trigger %s."
		% ("tetap terkunci" if _triggered else "dibuka kembali")
	)


func _on_player_respawned(_at_position: Vector2) -> void:
	if not _triggered or GameState.is_boss_defeated(boss_id):
		return

	_triggered = false
	_starting = false
	_encounter_sealed = false
	_retry_timer = 0.0
	_set_gates_closed(false)
	_set_exit_portals_active(false)
	_log("pemain respawn; trigger direset agar boss bisa dimulai lagi.")


func _set_exit_portals_active(active: bool) -> void:
	if exit_portal_group.is_empty() or not is_inside_tree():
		return

	for node in get_tree().get_nodes_in_group(exit_portal_group):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if not _exit_portal_matches_boss(node):
			continue
		if active:
			if node.has_method("activate"):
				node.call("activate", true)
			elif node.has_method("open_gate"):
				node.call("open_gate", true)
			continue
		if node.has_method("deactivate"):
			node.call("deactivate", false)
		elif node.has_method("close_gate"):
			node.call("close_gate", false)
		elif node is CanvasItem:
			(node as CanvasItem).visible = false


func _exit_portal_matches_boss(portal: Node) -> bool:
	var required_value: Variant = portal.get("required_boss_id")
	if required_value == null:
		return true
	var required := String(required_value).strip_edges()
	return required.is_empty() or required == boss_id


func _log(message: String) -> void:
	if debug_logging:
		print("[BossArenaTrigger:%s] %s" % [boss_id, message])
