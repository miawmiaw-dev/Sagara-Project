extends Area2D

const FLOAT_HEIGHT := 6.0
const FLOAT_DURATION := 0.75
const GLOW_MIN_ALPHA := 0.35
const GLOW_MAX_ALPHA := 1.0
const GLOW_DURATION := 0.65
const COLLECT_RISE := 28.0
const COLLECT_DURATION := 0.25

@export var value: int = 1

var _collected := false

@onready var _visual: Node2D = $Visual
@onready var _glow: ColorRect = $Visual/Glow


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_start_idle_animations()


func _start_idle_animations() -> void:
	var float_tween := create_tween().set_loops()
	float_tween.tween_property(_visual, "position:y", -FLOAT_HEIGHT, FLOAT_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(_visual, "position:y", 0.0, FLOAT_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var glow_tween := create_tween().set_loops()
	glow_tween.tween_property(_glow, "modulate:a", GLOW_MIN_ALPHA, GLOW_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow_tween.tween_property(_glow, "modulate:a", GLOW_MAX_ALPHA, GLOW_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	_collected = true
	set_deferred("monitoring", false)
	if body.has_method("add_souls"):
		body.call("add_souls", value)
	_play_collect_animation()


func _play_collect_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - COLLECT_RISE, COLLECT_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, COLLECT_DURATION)
	tween.finished.connect(queue_free)
