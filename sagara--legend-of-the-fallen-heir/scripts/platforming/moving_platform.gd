class_name MovingPlatform
extends AnimatableBody2D

@export var travel_offset: Vector2 = Vector2(0.0, -160.0)
@export_range(0.2, 20.0, 0.05) var travel_time: float = 3.0
@export_range(0.0, 5.0, 0.05) var wait_at_ends: float = 0.35
@export_range(0.0, 1.0, 0.01) var start_phase: float = 0.0

var _start_position: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0


func _ready() -> void:
	_start_position = position
	sync_to_physics = true
	_elapsed = start_phase * maxf(travel_time, 0.01)


func _physics_process(delta: float) -> void:
	if travel_offset.is_zero_approx():
		return

	_elapsed += delta
	var one_way := maxf(travel_time, 0.01)
	var cycle := one_way * 2.0 + wait_at_ends * 2.0
	var time_in_cycle := fmod(_elapsed, cycle)
	var weight := 0.0

	if time_in_cycle < one_way:
		weight = _smoothstep(time_in_cycle / one_way)
	elif time_in_cycle < one_way + wait_at_ends:
		weight = 1.0
	elif time_in_cycle < one_way * 2.0 + wait_at_ends:
		var return_progress := (time_in_cycle - one_way - wait_at_ends) / one_way
		weight = 1.0 - _smoothstep(return_progress)

	position = _start_position + travel_offset * weight


func _smoothstep(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
