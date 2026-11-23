class_name WeaponData
extends Resource

@export var weapon_name: String = "Keris Pusaka"
@export_range(0.0, 1000.0, 0.1) var damage: float = 15.0
@export_range(0.1, 5.0, 0.05) var attack_speed: float = 1.0
@export_range(1.0, 250.0, 1.0) var range_px: float = 48.0
@export_range(0.0, 2000.0, 1.0) var knockback: float = 20.0
@export_range(0.05, 3.0, 0.01) var cooldown: float = 0.2
@export_range(1, 10, 1) var combo_max: int = 3
@export var combo_data: Array[AttackStepData] = []
@export var special_skill: SpecialSkillData
@export var elang_special_skill: SpecialSkillData


func get_special_skill(is_elang: bool = false) -> SpecialSkillData:
	var preferred := elang_special_skill if is_elang else special_skill
	if preferred != null:
		return preferred
	return special_skill if special_skill != null else elang_special_skill


func get_combo_step(index: int) -> AttackStepData:
	if combo_data.is_empty() or index < 0 or index >= get_combo_count():
		return null
	return combo_data[index]


func get_combo_count() -> int:
	if combo_data.is_empty():
		return maxi(combo_max, 1)
	return mini(maxi(combo_max, 1), combo_data.size())
