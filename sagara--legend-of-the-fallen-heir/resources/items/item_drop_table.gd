class_name ItemDropTable
extends Resource

@export var entries: Array[ItemDropData] = []


func roll_drops() -> Array[ItemDropData]:
	var drops: Array[ItemDropData] = []
	for entry in entries:
		if entry == null or not entry.rolls_drop():
			continue
		drops.append(entry)
	return drops
