class_name DodgeData
extends Resource

@export_range(0.05, 1.0, 0.01) var duration: float = 0.36
@export_range(0.0, 1.0, 0.01) var iframe_start: float = 0.04
@export_range(0.0, 1.0, 0.01) var iframe_end: float = 0.26
@export_range(1.0, 1000.0, 1.0) var speed: float = 340.0
@export_range(0.0, 2.0, 0.01) var cooldown: float = 0.38
@export_range(0.0, 1.0, 0.01) var recovery_speed_multiplier: float = 0.35
@export var can_cancel_into_attack: bool = true
@export_range(0.0, 1.0, 0.01) var attack_cancel_start_time: float = 0.2
@export var can_cancel_into_jump: bool = false
@export_range(0.0, 1.0, 0.01) var jump_cancel_start_time: float = 0.24
@export_range(0.01, 0.25, 0.01) var ghost_interval: float = 0.03
@export_range(0.05, 1.0, 0.01) var ghost_fade_duration: float = 0.2
@export_range(0.0, 1.0, 0.01) var ghost_alpha: float = 0.35


func is_invulnerable(elapsed: float) -> bool:
	var start := minf(iframe_start, iframe_end)
	var end := maxf(iframe_start, iframe_end)
	return elapsed >= start and elapsed <= end


func get_speed_multiplier(elapsed: float) -> float:
	if elapsed < iframe_end:
		return 1.0
	var recovery_length := maxf(duration - iframe_end, 0.001)
	var recovery_ratio := clampf((elapsed - iframe_end) / recovery_length, 0.0, 1.0)
	return lerpf(1.0, recovery_speed_multiplier, recovery_ratio)
