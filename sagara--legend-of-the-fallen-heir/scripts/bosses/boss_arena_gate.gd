class_name BossArenaGate
extends StaticBody2D

@export var starts_open: bool = true
@export var animation_time: float = 0.25

@onready var visual: CanvasItem = get_node_or_null("Visual") as CanvasItem
@onready var collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

var _closed: bool = false
var _tween: Tween = null


func _ready() -> void:
	if starts_open:
		_apply_open(false)
	else:
		_apply_closed(false)


func close_gate(animated: bool = true) -> void:
	if _closed:
		return
	_closed = true
	if is_instance_valid(collision):
		collision.set_deferred("disabled", false)
	_apply_visual(true, animated)


func open_gate(animated: bool = true) -> void:
	_closed = false
	if is_instance_valid(collision):
		collision.set_deferred("disabled", true)
	_apply_visual(false, animated)


func is_closed() -> bool:
	return _closed


func _apply_open(animated: bool) -> void:
	_closed = false
	if is_instance_valid(collision):
		collision.set_deferred("disabled", true)
	_apply_visual(false, animated)


func _apply_closed(animated: bool) -> void:
	_closed = true
	if is_instance_valid(collision):
		collision.set_deferred("disabled", false)
	_apply_visual(true, animated)


func _apply_visual(closed: bool, animated: bool) -> void:
	if not is_instance_valid(visual):
		return

	_kill_tween()
	if not animated:
		visual.visible = closed
		visual.modulate.a = 1.0
		return

	visual.visible = true
	var target_alpha := 1.0 if closed else 0.0
	if closed:
		visual.modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(visual, "modulate:a", target_alpha, animation_time)
	else:
		_tween = create_tween()
		_tween.tween_property(visual, "modulate:a", target_alpha, animation_time)
		_tween.tween_callback(_hide_visual)


func _hide_visual() -> void:
	if is_instance_valid(visual):
		visual.visible = false


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
