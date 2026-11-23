extends Node

const DEFAULT_FADE_OUT_DURATION := 0.45
const DEFAULT_FADE_IN_DURATION := 0.35
const DEFAULT_FADE_COLOR := Color(0.02, 0.03, 0.05, 1.0)
const FADE_LAYER_INDEX := 128

var _spawn_tag: String = ""
var _transitioning: bool = false
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _fade_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fade_overlay()


func queue_spawn(tag: String) -> void:
	_spawn_tag = tag.strip_edges()


func consume_spawn_tag() -> String:
	var tag := _spawn_tag
	_spawn_tag = ""
	return tag


func peek_spawn_tag() -> String:
	return _spawn_tag


func clear_spawn_tag() -> void:
	_spawn_tag = ""


func is_transitioning() -> bool:
	return _transitioning


func transition_to_scene(
	target_scene: String,
	spawn_tag: String = "",
	fade_out_duration: float = DEFAULT_FADE_OUT_DURATION,
	fade_in_duration: float = DEFAULT_FADE_IN_DURATION,
	fade_color: Color = DEFAULT_FADE_COLOR
) -> bool:
	if _transitioning:
		return false
	if target_scene.strip_edges().is_empty():
		push_warning("LevelTransition: target scene kosong.")
		return false
	if not ResourceLoader.exists(target_scene):
		push_error("LevelTransition: scene target tidak ditemukan: %s" % target_scene)
		return false

	_transitioning = true
	await _fade_to_black(fade_color, fade_out_duration)
	queue_spawn(spawn_tag)

	var error := get_tree().change_scene_to_file(target_scene)
	if error != OK:
		clear_spawn_tag()
		await _fade_from_black(fade_color, fade_in_duration)
		_transitioning = false
		push_error(
			"LevelTransition: gagal berpindah ke %s (error %d)." % [target_scene, error]
		)
		return false

	await get_tree().process_frame
	await _fade_from_black(fade_color, fade_in_duration)
	_transitioning = false
	return true


func _build_fade_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "LevelFadeLayer"
	_fade_layer.layer = FADE_LAYER_INDEX
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeOverlay"
	_fade_rect.visible = false
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_layer.add_child(_fade_rect)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _fade_to_black(fade_color: Color, duration: float) -> void:
	if not is_instance_valid(_fade_rect):
		return

	_kill_fade_tween()
	_fade_rect.visible = true
	_fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
	_fade_tween = create_tween()
	_fade_tween.tween_property(
		_fade_rect,
		"color:a",
		1.0,
		maxf(duration, 0.01)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _fade_tween.finished


func _fade_from_black(fade_color: Color, duration: float) -> void:
	if not is_instance_valid(_fade_rect):
		return

	_kill_fade_tween()
	_fade_tween = create_tween()

	if duration <= 0.0:
		_fade_rect.visible = false
		_fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
		return

	_fade_rect.visible = true
	_fade_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, 1.0)
	_fade_tween.tween_property(
		_fade_rect,
		"color:a",
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _fade_tween.finished
	_fade_rect.visible = false


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
