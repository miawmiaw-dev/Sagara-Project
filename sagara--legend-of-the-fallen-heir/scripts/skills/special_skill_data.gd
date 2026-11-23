class_name SpecialSkillData
extends Resource

enum Style {
	GROUND_AOE,
	PROJECTILE,
}

@export var skill_name: String = "Tebasan Jiwa"
@export var style: Style = Style.PROJECTILE
@export_range(0, 100, 1) var energy_cost: int = 30
@export_range(0.0, 10.0, 0.05) var cooldown: float = 1.2
@export_range(0.0, 5.0, 0.01) var windup_time: float = 0.12
@export_range(0.01, 5.0, 0.01) var active_time: float = 0.18
@export_range(0.0, 5.0, 0.01) var recovery_time: float = 0.22
@export_range(0.1, 20.0, 0.05) var damage_multiplier: float = 2.0
@export_range(0.0, 10.0, 0.05) var knockback_multiplier: float = 1.5
@export var hitbox_size: Vector2 = Vector2(140.0, 90.0)
@export_range(0.0, 500.0, 1.0) var spawn_offset: float = 56.0
@export_range(1.0, 1000.0, 1.0) var aoe_radius: float = 90.0
@export_range(0.0, 2000.0, 10.0) var projectile_speed: float = 620.0
@export_range(1.0, 3000.0, 1.0) var projectile_range: float = 420.0
@export var projectile_size: Vector2 = Vector2(58.0, 26.0)
@export var projectile_pierces: bool = true
@export_range(0.0, 3.0, 0.05) var stun_duration: float = 0.0
@export var effect_color: Color = Color(0.45, 0.9, 1.0, 1.0)
@export var animation_name: StringName = &"special"


func get_total_duration() -> float:
	return maxf(windup_time + active_time + recovery_time, 0.05)


func is_projectile() -> bool:
	return style == Style.PROJECTILE
