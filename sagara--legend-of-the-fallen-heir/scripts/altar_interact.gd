extends "res://scripts/interactable_area.gd"
class_name AltarInteract

const SHOP_MODE := "shop"
const TELEPORT_MODE := "teleport"
const ALTAR_COLOR := Color(0.65, 1.0, 0.36, 1.0)
const SHOP_KEY := KEY_E
const TELEPORT_KEY := KEY_F
const INTERACTION_PROMPT := "E : Buka Toko/Upgrade | F : Teleport"
const TELEPORT_FADE_OUT_DURATION := 0.25
const TELEPORT_FADE_IN_DURATION := 0.3
const TELEPORT_PAUSE_WAIT_FRAMES := 120

@export var spawn_offset: Vector2 = Vector2(0.0, -40.0)
@export var altar_id: String = ""

@onready var glow: ColorRect = get_node_or_null("RelikAltar/Glow") as ColorRect
@onready var inti: Polygon2D = get_node_or_null("RelikAltar/Inti") as Polygon2D

var shop_ui_scene: PackedScene = preload("res://scenes/altar_shop_ui.tscn")
var is_checkpoint_active: bool = false
var checkpoint_position: Vector2 = Vector2.ZERO

var _resolved_altar_id: String = ""
var _is_teleporting: bool = false
var _shop_ui_open: bool = false
var _glow_tween: Tween = null
var _glow_base_color: Color = Color.WHITE


# ============================================================
# INPUT HANDLING
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _can_handle_altar_input():
		return
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var keycode := _get_keycode(key_event)
	if keycode == SHOP_KEY:
		get_viewport().set_input_as_handled()
		_handle_shop_key()
	elif keycode == TELEPORT_KEY:
		get_viewport().set_input_as_handled()
		_handle_checkpoint_teleport_key()


func _handle_shop_key() -> void:
	if _shop_ui_open or _is_teleporting:
		return
	open_shop_ui()


func _handle_checkpoint_teleport_key() -> void:
	if _shop_ui_open or _is_teleporting:
		return
	if not is_checkpoint_active:
		_save_checkpoint()
		return
	open_teleport_menu()


func _can_handle_altar_input() -> bool:
	if get_tree().paused:
		return false
	if _shop_ui_open or _is_teleporting:
		return false
	if not is_instance_valid(_player_in_range):
		return false
	return can_interact()


func _get_keycode(event: InputEventKey) -> int:
	if event.physical_keycode != KEY_NONE:
		return event.physical_keycode
	return event.keycode


func _on_interactable_ready() -> void:
	_resolved_altar_id = _resolve_altar_id()
	_restore_checkpoint_from_game_state()
	refresh_prompt()
	_start_glow_pulse()


func get_altar_id() -> String:
	if _resolved_altar_id.is_empty():
		_resolved_altar_id = _resolve_altar_id()
	return _resolved_altar_id


func _resolve_altar_id() -> String:
	var explicit_id := altar_id.strip_edges()
	if not explicit_id.is_empty():
		return explicit_id
	var scene_root: Node = owner
	if scene_root == null:
		scene_root = get_tree().current_scene
	var scene_path := ""
	if scene_root != null:
		scene_path = scene_root.scene_file_path
		if scene_path.is_empty():
			scene_path = String(scene_root.name)
	if scene_path.is_empty():
		scene_path = "unknown_scene"
	return "%s::%s" % [scene_path, str(get_path())]


func _restore_checkpoint_from_game_state() -> void:
	var entry := GameState.find_registered_altar(get_altar_id())
	if entry.is_empty():
		return
	var saved_position: Variant = entry.get("checkpoint_position", global_position)
	checkpoint_position = saved_position if saved_position is Vector2 else global_position
	is_checkpoint_active = true
	GameState.register_altar(
		get_altar_id(), global_position, checkpoint_position, self
	)


func can_interact() -> bool:
	return not _is_teleporting


func get_prompt_text() -> String:
	return INTERACTION_PROMPT


# ============================================================
# SHOP / UPGRADE (HANYA UNTUK TOMBOL E)
# ============================================================

func open_shop_ui() -> void:
	_open_altar_ui(SHOP_MODE)


func _open_altar_ui(mode: String) -> void:
	if not is_inside_tree():
		return
	if get_tree().paused or _is_teleporting or _shop_ui_open:
		return

	var ui := shop_ui_scene.instantiate() as AltarShopUI
	if ui == null:
		return

	ui.source_altar = self
	ui.open_mode = mode
	ui.closed.connect(_on_shop_ui_closed)
	ui.tree_exited.connect(_on_shop_ui_closed)
	_shop_ui_open = true
	get_tree().root.add_child(ui)
	get_tree().paused = true


func _on_shop_ui_closed() -> void:
	_shop_ui_open = false


# ============================================================
# CHECKPOINT (HANYA UNTUK TOMBOL F)
# ============================================================

func _save_checkpoint() -> void:
	var player := _player_in_range
	if not is_instance_valid(player):
		return
	_activate_checkpoint(player)


func activate_checkpoint(player: Node2D) -> void:
	_activate_checkpoint(player)


func _activate_checkpoint(player: Node2D) -> void:
	if not is_instance_valid(player):
		return

	is_checkpoint_active = true
	checkpoint_position = player.global_position
	GameState.register_altar(
		get_altar_id(), global_position, checkpoint_position, self
	)
	refresh_prompt()
	_play_activation_flash()
	JuiceFX.checkpoint_activated(global_position + Vector2(0.0, -40.0), ALTAR_COLOR)
	spawn_warp_effect(global_position, ALTAR_COLOR)

	if player.has_method("show_message"):
		player.call("show_message", "Checkpoint tersimpan di altar ini!")


# ============================================================
# MENU TELEPORTASI ALTAR (HANYA UNTUK TOMBOL F)
# ============================================================

func open_teleport_menu() -> void:
	if not is_checkpoint_active:
		_save_checkpoint()
		return
	if _get_other_active_altars().is_empty():
		_show_message_to_player("Belum ada altar aktif lain untuk teleportasi.")
		return
	_open_altar_ui(TELEPORT_MODE)


func _get_other_active_altars() -> Array[AltarInteract]:
	var result: Array[AltarInteract] = []
	var current_id := get_altar_id()
	for entry in GameState.get_other_registered_altars(current_id):
		var altar := GameState.get_registered_altar_node(entry) as AltarInteract
		if not is_instance_valid(altar) or altar == self:
			continue
		if altar.get_altar_id() == current_id:
			continue
		result.append(altar)
	return result


# ============================================================
# TELEPORTASI (DIPANGGIL DARI MENU TELEPORT, BUKAN DARI TOMBOL E)
# ============================================================

func try_teleport_from_altar(target_altar: AltarInteract) -> void:
	if target_altar == null or not is_instance_valid(target_altar):
		_show_message_to_player("Altar tujuan tidak tersedia.")
		return
	if target_altar == self:
		return
	if not target_altar.is_checkpoint_active:
		_show_message_to_player("Aktifkan altar tujuan terlebih dahulu.")
		return

	start_teleport_sequence(target_altar)


func start_teleport_sequence(target: AltarInteract, explicit_player: Node2D = null) -> void:
	if _is_teleporting:
		return
	if not is_inside_tree():
		return
	if target == null or not is_instance_valid(target) or target == self:
		return
	if not target.is_checkpoint_active:
		_show_message_to_player("Aktifkan altar tujuan terlebih dahulu.")
		return

	var player := explicit_player
	if not is_instance_valid(player):
		player = _player_in_range
	if not is_instance_valid(player):
		return

	_is_teleporting = true
	refresh_prompt()

	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO

	var pause_wait_frames := 0
	while get_tree().paused:
		await get_tree().process_frame
		pause_wait_frames += 1
		if pause_wait_frames >= TELEPORT_PAUSE_WAIT_FRAMES:
			get_tree().paused = false
			break

	if not is_instance_valid(player) or not is_instance_valid(target):
		_finish_teleport()
		return

	spawn_warp_effect(global_position, ALTAR_COLOR)
	JuiceFX.magic_burst(global_position + Vector2(0.0, -40.0), ALTAR_COLOR, 0.85)

	var fade_out := create_tween()
	fade_out.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(self, "modulate:a", 0.0, TELEPORT_FADE_OUT_DURATION)
	await fade_out.finished

	if not is_instance_valid(player) or not is_instance_valid(target):
		_finish_teleport()
		return

	player.global_position = target.global_position + target.spawn_offset
	modulate = Color(1.0, 1.0, 1.0, 0.0)

	target.spawn_warp_effect(target.global_position, ALTAR_COLOR)
	JuiceFX.magic_burst(target.global_position + Vector2(0.0, -40.0), ALTAR_COLOR, 0.85)
	JuiceFX.shake_camera(1.2, 0.1, 36.0)

	var fade_in := create_tween()
	fade_in.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fade_in.tween_property(self, "modulate:a", 1.0, TELEPORT_FADE_IN_DURATION)
	await fade_in.finished

	if is_instance_valid(player) and player.has_method("show_message"):
		player.call("show_message", "Teleport ke altar berhasil!")

	_finish_teleport()


func _finish_teleport() -> void:
	modulate = Color.WHITE
	_player_in_range = null
	_is_teleporting = false
	_shop_ui_open = false
	refresh_prompt()


func _show_message_to_player(message: String) -> void:
	var player := _player_in_range
	if is_instance_valid(player) and player.has_method("show_message"):
		player.call("show_message", message)


# ============================================================
# VISUAL EFFECTS
# ============================================================

func _play_activation_flash() -> void:
	modulate = Color(2.0, 2.0, 2.0, 1.0)
	var flash := create_tween()
	flash.tween_property(self, "modulate", Color.WHITE, 0.32) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)

	if inti == null:
		return

	inti.color = Color.WHITE
	inti.scale = Vector2(1.6, 1.6)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(inti, "color", ALTAR_COLOR, 0.34) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(inti, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


func spawn_warp_effect(at_position: Vector2, effect_color: Color) -> void:
	var parent := get_parent()
	if parent == null:
		return

	var effect := Line2D.new()
	effect.width = 3.0
	effect.default_color = effect_color
	effect.z_index = 3

	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(Vector2(cos(angle), sin(angle)) * 16.0)
	effect.points = points

	parent.add_child(effect)
	effect.global_position = at_position

	var tween := effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(3.2, 3.2), 0.35)
	tween.tween_property(effect, "modulate:a", 0.0, 0.35)
	tween.finished.connect(effect.queue_free)


func _start_glow_pulse() -> void:
	if glow == null:
		return
	_glow_base_color = glow.color
	_pulse_glow()


func _pulse_glow() -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()

	_glow_tween = create_tween().set_loops()
	var pulse_color := _glow_base_color
	pulse_color.a = 0.35
	_glow_tween.tween_property(glow, "color", pulse_color, 1.2) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)
	_glow_tween.tween_property(glow, "color", _glow_base_color, 1.2) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN)
