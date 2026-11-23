class_name AttackStepData
extends Resource

@export var step_name: String = ""
@export_range(0.05, 2.0, 0.01) var duration: float = 0.18
@export_range(0.0, 5.0, 0.05) var damage_multiplier: float = 1.0
@export var hitbox_size: Vector2 = Vector2(48.0, 48.0)
@export_range(0.0, 250.0, 1.0) var hitbox_offset: float = 30.0
@export_range(0.0, 1.0, 0.005) var hitbox_start_time: float = 0.03
@export_range(0.01, 1.0, 0.005) var hitbox_lifetime: float = 0.06
@export_range(0.0, 2.0, 0.005) var combo_window_start: float = 0.07
@export_range(0.0, 2.0, 0.005) var combo_window_end: float = 0.16
@export_range(0.0, 5.0, 0.05) var knockback_multiplier: float = 1.0
