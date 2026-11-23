extends "res://scripts/interactable_area.gd"

const INACTIVE_COLOR := Color(0.36, 0.4, 0.45, 1.0)
const ACTIVE_COLOR := Color(0.35, 0.95, 1.0, 1.0)
const PULSE_DURATION := 0.9
const WARP_EFFECT_DURATION := 0.35

@export var teleporter_name: String = "Prasasti"
@export var spawn_offset: Vector2 = Vector2(0.0, -60.0)
@export var active: bool = false

var _glow: ColorRect = null
var _rune: Polygon2D = null
var _name_label: Label = null
var _pulse_tween: Tween = null


func _on_interactable_ready() -> void:
	add_to_group("teleporter")
	_glow = get_node_or_null("Glow") as ColorRect
	_rune = get_node_or_null("Rune") as Polygon2D
	_name_label = get_node_or_null("NameLabel") as Label
	if _name_label != null:
		_name_label.text = teleporter_name
	_update_visual_state()
	if active:
		_start_pulse()


func can_interact() -> bool:
	return true


func get_prompt_text() -> String:
	if not active:
		return "E / F : Aktifkan %s" % teleporter_name
	return "E / F : Teleport ke Prasasti Lain"


func interact(player: Node2D) -> void:
	if not active:
		_activate(player)
		return
	_teleport(player)


func is_active() -> bool:
	return active


func get_spawn_position() -> Vector2:
	return global_position + spawn_offset


func _activate(player: Node2D) -> void:
	active = true
	_update_visual_state()
	_start_pulse()
	refresh_prompt()
	_play_activation_flash()
	JuiceFX.checkpoint_activated(global_position + Vector2(0.0, -58.0), ACTIVE_COLOR)
	spawn_warp_effect(global_position, ACTIVE_COLOR)
	if player.has_method("show_message"):
		player.call("show_message", "%s telah aktif!" % teleporter_name)


func _play_activation_flash() -> void:
	modulate = Color(2.0, 2.0, 2.0, 1.0)
	var flash := create_tween()
	flash.tween_property(self, "modulate", Color.WHITE, 0.32) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if _rune == null:
		return
	_rune.color = Color.WHITE
	_rune.scale = Vector2(1.7, 1.7)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_rune, "color", ACTIVE_COLOR, 0.34) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_rune, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _teleport(player: Node2D) -> void:
	var target = _find_next_active_teleporter()
	if target == null:
		if player.has_method("show_message"):
			player.call("show_message", "Aktifkan prasasti lain terlebih dahulu.")
		return

	spawn_warp_effect(global_position, ACTIVE_COLOR)
	JuiceFX.magic_burst(global_position + Vector2(0.0, -58.0), ACTIVE_COLOR, 0.85)
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	player.global_position = target.get_spawn_position()
	target.spawn_warp_effect(target.global_position, ACTIVE_COLOR)
	JuiceFX.magic_burst(target.global_position + Vector2(0.0, -58.0), ACTIVE_COLOR, 0.85)
	JuiceFX.shake_camera(1.5, 0.12, 42.0)
	if player.has_method("show_message"):
		player.call("show_message", "Berpindah ke %s." % target.teleporter_name)


func _find_next_active_teleporter():
	var active_teleporters: Array = []
	for node in get_tree().get_nodes_in_group("teleporter"):
		if not is_instance_valid(node):
			continue
		if node.has_method("is_active") and node.is_active():
			active_teleporters.append(node)

	if active_teleporters.size() <= 1:
		return null

	active_teleporters.sort_custom(_sort_by_x)
	var current_index: int = active_teleporters.find(self)
	if current_index == -1:
		return active_teleporters[0]

	for step in range(1, active_teleporters.size()):
		var candidate = active_teleporters[(current_index + step) % active_teleporters.size()]
		if candidate != self:
			return candidate
	return null


func _sort_by_x(a: Node2D, b: Node2D) -> bool:
	return a.global_position.x < b.global_position.x


func _update_visual_state() -> void:
	if _rune != null:
		_rune.color = ACTIVE_COLOR if active else INACTIVE_COLOR
	if _glow != null:
		_glow.visible = active
		_glow.modulate = Color.WHITE


func _start_pulse() -> void:
	if _glow == null:
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_glow, "modulate:a", 0.35, PULSE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_glow, "modulate:a", 1.0, PULSE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
	tween.tween_property(effect, "scale", Vector2(3.2, 3.2), WARP_EFFECT_DURATION)
	tween.tween_property(effect, "modulate:a", 0.0, WARP_EFFECT_DURATION)
	tween.finished.connect(effect.queue_free)
