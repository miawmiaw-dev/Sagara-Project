class_name LevelDoor
extends Area2D

const LOCKED_CORE_COLOR := Color(0.09, 0.06, 0.08, 0.92)
const OPEN_CORE_COLOR := Color(0.16, 0.58, 0.52, 0.55)
const LOCKED_RUNE_COLOR := Color(0.62, 0.22, 0.24, 0.7)
const OPEN_RUNE_COLOR := Color(0.52, 1.0, 0.82, 0.95)
const LOCKED_GLOW_COLOR := Color(0.4, 0.08, 0.1, 0.1)
const OPEN_GLOW_COLOR := Color(0.3, 0.95, 0.75, 0.16)
const PULSE_DURATION := 1.2
const PULSE_MIN_ALPHA := 0.45
const REVEAL_DURATION := 0.4
const LOCKED_MESSAGE_COOLDOWN := 1.5

@export_group("Transition")
@export_file("*.tscn") var target_scene: String = ""
@export var target_spawn_tag: String = ""
@export var fade_out_duration: float = 0.45
@export var fade_in_duration: float = 0.35
@export var fade_color: Color = Color(0.02, 0.03, 0.05, 1.0)

@export_group("Lock")
@export var required_boss_id: String = ""
@export var start_locked: bool = true
@export var locked_feedback: String = "Gerbang tersegel."

@export_group("Visual")
@export var gate_title: String = "GERBANG CANDI"
@export var open_hint: String = "MASUK"
@export var locked_hint: String = "TERSEGEL"
@export var player_group: String = "player"

var _locked: bool = true
var _active: bool = false
var _transitioning: bool = false
var _feedback_cooldown: float = 0.0
var _pulse_tween: Tween = null
var _state_tween: Tween = null

@onready var _glow: ColorRect = get_node_or_null("Glow") as ColorRect
@onready var _core: ColorRect = get_node_or_null("Core") as ColorRect
@onready var _rune: Polygon2D = get_node_or_null("Rune") as Polygon2D
@onready var _title: Label = get_node_or_null("Title") as Label
@onready var _hint: Label = get_node_or_null("Hint") as Label
@onready var _collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not required_boss_id.strip_edges().is_empty() and GameState.is_boss_defeated(
		required_boss_id
	):
		start_locked = false
	_set_locked(start_locked, false)
	call_deferred("_check_player_overlap")


func _process(delta: float) -> void:
	_feedback_cooldown = maxf(_feedback_cooldown - delta, 0.0)


func activate(animated: bool = true) -> void:
	if _active and not _locked:
		return
	_locked = false
	_active = true
	_transitioning = false
	if is_instance_valid(_collision):
		_collision.set_deferred("disabled", false)
	_apply_state_visuals(animated)
	if animated:
		_play_reveal()
	else:
		_start_glow_pulse()
	call_deferred("_check_player_overlap")


func deactivate(animated: bool = true) -> void:
	_locked = true
	_active = false
	_transitioning = false
	_stop_glow_pulse()
	_apply_state_visuals(animated)


func is_active() -> bool:
	return _active


func is_locked() -> bool:
	return _locked


func _set_locked(locked: bool, animated: bool) -> void:
	_locked = locked
	_active = not locked
	_apply_state_visuals(animated)
	if _active:
		_start_glow_pulse()
	else:
		_stop_glow_pulse()


func _apply_state_visuals(animated: bool) -> void:
	if is_instance_valid(_title):
		_title.text = gate_title
	if is_instance_valid(_hint):
		_hint.text = locked_hint if _locked else open_hint

	var core_color := LOCKED_CORE_COLOR if _locked else OPEN_CORE_COLOR
	var rune_color := LOCKED_RUNE_COLOR if _locked else OPEN_RUNE_COLOR
	var glow_color := LOCKED_GLOW_COLOR if _locked else OPEN_GLOW_COLOR

	_kill_state_tween()
	if not animated:
		if is_instance_valid(_core):
			_core.color = core_color
		if is_instance_valid(_rune):
			_rune.color = rune_color
		if is_instance_valid(_glow):
			_glow.color = glow_color
			_glow.modulate.a = 1.0
		modulate = Color.WHITE
		return

	_state_tween = create_tween()
	_state_tween.set_parallel(true)
	if is_instance_valid(_core):
		_state_tween.tween_property(_core, "color", core_color, REVEAL_DURATION)
	if is_instance_valid(_rune):
		_state_tween.tween_property(_rune, "color", rune_color, REVEAL_DURATION)
		_state_tween.tween_property(_rune, "scale", Vector2.ONE, REVEAL_DURATION) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_glow):
		_state_tween.tween_property(_glow, "color", glow_color, REVEAL_DURATION)
		_state_tween.tween_property(_glow, "modulate:a", 1.0, REVEAL_DURATION)


func _play_reveal() -> void:
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	if is_instance_valid(_rune):
		_rune.scale = Vector2(0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, REVEAL_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_glow):
		_glow.modulate.a = 0.0
		tween.parallel().tween_property(_glow, "modulate:a", 1.0, REVEAL_DURATION + 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_inside_tree():
		JuiceFX.magic_burst(global_position, OPEN_RUNE_COLOR, 1.1)
	tween.chain().tween_callback(_reset_modulate_after_reveal)


func _reset_modulate_after_reveal() -> void:
	if _active:
		modulate = Color.WHITE
		_start_glow_pulse()


func _start_glow_pulse() -> void:
	if not _active or not is_instance_valid(_glow):
		return
	_stop_glow_pulse()
	var tween := create_tween().set_loops()
	var fade_in := tween.tween_property(_glow, "modulate:a", PULSE_MIN_ALPHA, PULSE_DURATION)
	fade_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var fade_out := tween.tween_property(_glow, "modulate:a", 1.0, PULSE_DURATION)
	fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween = tween


func _stop_glow_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null


func _kill_state_tween() -> void:
	if _state_tween != null and _state_tween.is_valid():
		_state_tween.kill()
	_state_tween = null


func _validate_target() -> void:
	if target_scene.strip_edges().is_empty():
		push_warning("LevelDoor '%s': target_scene belum diatur." % name)
		return
	if not ResourceLoader.exists(target_scene):
		push_error("LevelDoor '%s': scene target tidak ditemukan: %s" % [name, target_scene])


func _check_player_overlap() -> void:
	await get_tree().physics_frame
	if not is_inside_tree() or not _active or _transitioning:
		return
	for body in get_overlapping_bodies():
		if _is_player(body):
			_transitioning = true
			_begin_transition(body)
			return


func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	if not _active:
		_show_locked_feedback(body)
		return
	if _transitioning or LevelTransition.is_transitioning():
		return
	_transitioning = true
	_begin_transition(body)


func _is_player(body: Node) -> bool:
	return is_instance_valid(body) and body.is_in_group(player_group)


func _show_locked_feedback(body: Node) -> void:
	if _feedback_cooldown > 0.0:
		return
	_feedback_cooldown = LOCKED_MESSAGE_COOLDOWN
	if body.has_method("show_message"):
		body.call("show_message", locked_feedback)


func _begin_transition(body: Node2D) -> void:
	if not is_instance_valid(body) or not _active or not is_inside_tree():
		_transitioning = false
		return
	if not body.is_in_group(player_group):
		_transitioning = false
		return
	if target_scene.strip_edges().is_empty() or not ResourceLoader.exists(target_scene):
		_transitioning = false
		_validate_target()
		return
	if LevelTransition.is_transitioning():
		_transitioning = false
		return

	set_deferred("monitoring", false)
	if body is CharacterBody2D:
		(body as CharacterBody2D).velocity = Vector2.ZERO

	var success: bool = await LevelTransition.transition_to_scene(
		target_scene,
		target_spawn_tag,
		fade_out_duration,
		fade_in_duration,
		fade_color
	)
	if success:
		return

	_transitioning = false
	set_deferred("monitoring", true)
	if is_instance_valid(body) and body.has_method("show_message"):
		body.call("show_message", "Gerbang tidak dapat dibuka.")
