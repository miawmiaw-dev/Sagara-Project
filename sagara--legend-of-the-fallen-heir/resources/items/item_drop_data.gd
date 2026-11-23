class_name ItemDropData
extends Resource

enum Kind {
	SOULS,
	HEAL,
}

@export var item_id: String = "jiwa_murni"
@export var display_name: String = "Jiwa Murni"
@export_multiline var description: String = "Menambah Jiwa."
@export var kind: Kind = Kind.SOULS
@export_range(0, 9999, 1) var amount_min: int = 1
@export_range(0, 9999, 1) var amount_max: int = 1
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 1.0
@export var pickup_scene: PackedScene = null
@export var color: Color = Color(0.55, 0.95, 1.0, 1.0)
@export_range(0.0, 64.0, 1.0) var scatter_radius: float = 18.0


func rolls_drop() -> bool:
	if drop_chance >= 1.0:
		return true
	if drop_chance <= 0.0:
		return false
	return randf() < drop_chance


func get_amount() -> int:
	var low := maxi(mini(amount_min, amount_max), 0)
	var high := maxi(maxi(amount_min, amount_max), 0)
	return randi_range(low, high)
