extends Node

enum GameStatus {
	PLAYING,
	PAUSED,
	DEAD,
	VICTORY,
}

const BASE_MAX_HEALTH := 100
const HEALTH_PER_UPGRADE := 20
const BASE_ATTACK_POWER := 10
const ATTACK_POWER_PER_UPGRADE := 3
const BASE_MAX_SPECIAL_ENERGY := 100.0
const SPECIAL_ENERGY_REGEN_PER_SECOND := 14.0
const SPECIAL_ENERGY_REGEN_DELAY := 0.75
const BOSS_FOREST_GUARDIAN := "penjaga_hutan_larangan"

var max_health: int = BASE_MAX_HEALTH
var current_health: int = BASE_MAX_HEALTH
var total_souls: int = 0
var status: GameStatus = GameStatus.PLAYING
var active_boss_id: String = ""
var active_boss_serial: int = 0
var defeated_bosses: PackedStringArray = PackedStringArray()

var _boss_serial_counter: int = 0

var max_special_energy: float = BASE_MAX_SPECIAL_ENERGY
var special_energy: float = BASE_MAX_SPECIAL_ENERGY

var upgrade_hp_level: int = 0
var upgrade_attack_level: int = 0
var upgrade_potion_level: int = 0
var upgrade_soul_save_level: int = 0

var inventory: Dictionary = {}

var registered_altars: Array[Dictionary] = []

var _special_energy_regen_delay: float = 0.0


func _ready() -> void:
	max_health = get_calculated_max_health()
	current_health = max_health
	max_special_energy = BASE_MAX_SPECIAL_ENERGY
	special_energy = max_special_energy


func _process(delta: float) -> void:
	if status != GameStatus.PLAYING:
		return
	if _special_energy_regen_delay > 0.0:
		_special_energy_regen_delay = maxf(_special_energy_regen_delay - delta, 0.0)
		return
	if special_energy >= max_special_energy:
		return
	_set_special_energy(
		minf(special_energy + SPECIAL_ENERGY_REGEN_PER_SECOND * delta, max_special_energy)
	)


func get_special_energy_ratio() -> float:
	if max_special_energy <= 0.0:
		return 0.0
	return clampf(special_energy / max_special_energy, 0.0, 1.0)


func has_special_energy(amount: int) -> bool:
	return amount <= 0 or special_energy + 0.001 >= float(amount)


func spend_special_energy(amount: int) -> bool:
	if amount <= 0:
		return true
	if not has_special_energy(amount):
		return false
	_special_energy_regen_delay = SPECIAL_ENERGY_REGEN_DELAY
	_set_special_energy(special_energy - float(amount))
	return true


func refill_special_energy() -> void:
	_special_energy_regen_delay = 0.0
	_set_special_energy(max_special_energy)


func _set_special_energy(value: float) -> void:
	max_special_energy = maxf(BASE_MAX_SPECIAL_ENERGY, max_special_energy)
	special_energy = clampf(value, 0.0, max_special_energy)
	EventBus.special_energy_changed.emit(special_energy, max_special_energy)


func get_calculated_max_health() -> int:
	return BASE_MAX_HEALTH + upgrade_hp_level * HEALTH_PER_UPGRADE


func get_max_potions() -> int:
	return 1 + upgrade_potion_level


func set_health(value: int, notify_listeners: bool = true) -> void:
	max_health = get_calculated_max_health()
	current_health = clampi(value, 0, max_health)
	if notify_listeners:
		EventBus.health_changed.emit(current_health, max_health)


func apply_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var previous := current_health
	set_health(current_health - amount, false)
	var applied := previous - current_health
	if applied > 0:
		EventBus.health_changed.emit(current_health, max_health)
	return applied


func heal(amount: int) -> void:
	if amount <= 0:
		return
	set_health(current_health + amount)


func reset_health() -> void:
	set_health(max_health)


func add_souls(amount: int, autosave: bool = true) -> void:
	if amount <= 0:
		return
	total_souls += amount
	add_item("jiwa_murni", amount, false)
	EventBus.souls_changed.emit(total_souls)
	if autosave:
		EventBus.save_requested.emit()


func add_item(item_id: String, amount: int = 1, autosave: bool = true) -> void:
	if item_id.is_empty() or amount <= 0:
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	if autosave:
		EventBus.save_requested.emit()


func get_item_count(item_id: String) -> int:
	if item_id.is_empty():
		return 0
	return int(inventory.get(item_id, 0))


func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount


func remove_item(item_id: String, amount: int = 1, autosave: bool = true) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false
	var current := get_item_count(item_id)
	if current < amount:
		return false
	var remaining := current - amount
	if remaining <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = remaining
	if autosave:
		EventBus.save_requested.emit()
	return true


func spend_souls(amount: int) -> bool:
	if amount <= 0 or total_souls < amount:
		return false
	total_souls -= amount
	EventBus.souls_changed.emit(total_souls)
	return true


func register_altar(
	altar_id: String,
	altar_position: Vector2,
	checkpoint_position: Vector2,
	altar_node: Node = null
) -> void:
	var normalized_id := altar_id.strip_edges()
	if normalized_id.is_empty():
		return
	var entry := {
		"id": normalized_id,
		"altar_position": altar_position,
		"checkpoint_position": checkpoint_position,
		"node": weakref(altar_node) if is_instance_valid(altar_node) else null,
	}
	for index in range(registered_altars.size()):
		if String(registered_altars[index].get("id", "")) == normalized_id:
			registered_altars[index] = entry
			return
	registered_altars.append(entry)


func unregister_altar(altar_id: String) -> void:
	var normalized_id := altar_id.strip_edges()
	if normalized_id.is_empty():
		return
	for index in range(registered_altars.size() - 1, -1, -1):
		if String(registered_altars[index].get("id", "")) == normalized_id:
			registered_altars.remove_at(index)


func get_registered_altars() -> Array[Dictionary]:
	return registered_altars


func get_other_registered_altars(altar_id: String) -> Array[Dictionary]:
	var normalized_id := altar_id.strip_edges()
	var result: Array[Dictionary] = []
	for entry in registered_altars:
		if normalized_id.is_empty() or String(entry.get("id", "")) != normalized_id:
			result.append(entry)
	return result


func find_registered_altar(altar_id: String) -> Dictionary:
	var normalized_id := altar_id.strip_edges()
	if normalized_id.is_empty():
		return {}
	for entry in registered_altars:
		if String(entry.get("id", "")) == normalized_id:
			return entry
	return {}


func get_registered_altar_node(entry: Dictionary) -> Node:
	var node_ref: Variant = entry.get("node", null)
	if node_ref is WeakRef:
		var node: Variant = (node_ref as WeakRef).get_ref()
		if node is Node and is_instance_valid(node):
			return node as Node
	return null


func clear_registered_altars() -> void:
	registered_altars.clear()


func get_hp_upgrade_cost() -> int:
	return 50 * (upgrade_hp_level + 1)

func get_attack_upgrade_cost() -> int:
	return 75 * (upgrade_attack_level + 1)

func get_calculated_attack_power() -> int:
	return BASE_ATTACK_POWER + upgrade_attack_level * ATTACK_POWER_PER_UPGRADE


func get_potion_upgrade_cost() -> int:
	return 100 * (upgrade_potion_level + 1)


func get_soul_save_upgrade_cost() -> int:
	return 150 * (upgrade_soul_save_level + 1)


func buy_hp_upgrade() -> bool:
	if not spend_souls(get_hp_upgrade_cost()):
		return false
	upgrade_hp_level += 1
	max_health = get_calculated_max_health()
	current_health = mini(current_health + HEALTH_PER_UPGRADE, max_health)
	EventBus.health_changed.emit(current_health, max_health)
	EventBus.save_requested.emit()
	return true


func buy_attack_upgrade() -> bool:
	if not spend_souls(get_attack_upgrade_cost()):
		return false
	upgrade_attack_level += 1
	EventBus.attack_upgraded.emit(upgrade_attack_level, get_calculated_attack_power())
	EventBus.save_requested.emit()
	return true


func buy_potion_upgrade() -> bool:
	if not spend_souls(get_potion_upgrade_cost()):
		return false
	upgrade_potion_level += 1
	EventBus.save_requested.emit()
	return true


func buy_soul_save_upgrade() -> bool:
	if not spend_souls(get_soul_save_upgrade_cost()):
		return false
	upgrade_soul_save_level += 1
	EventBus.save_requested.emit()
	return true


func begin_boss_fight(boss_id: String) -> bool:
	if boss_id.is_empty() or is_boss_defeated(boss_id):
		return false
	if not active_boss_id.is_empty() and active_boss_id != boss_id:
		push_warning(
			"GameState: encounter '%s' ditolak karena boss '%s' masih aktif."
			% [boss_id, active_boss_id]
		)
		return false

	_boss_serial_counter += 1
	active_boss_id = boss_id
	active_boss_serial = _boss_serial_counter
	return true


func get_active_boss_serial(boss_id: String) -> int:
	if boss_id.is_empty() or active_boss_id != boss_id:
		return -1
	return active_boss_serial


func is_boss_fight_active(boss_id: String = "") -> bool:
	if active_boss_id.is_empty():
		return false
	return boss_id.is_empty() or active_boss_id == boss_id


func finish_boss_fight(boss_id: String, victory: bool, serial: int = -1) -> void:
	if boss_id.is_empty():
		return
	var was_active := active_boss_id == boss_id
	if serial >= 0 and serial != active_boss_serial:
		# Kemenangan dari encounter lama tidak boleh menulis flag save.
		was_active = false
	if victory and was_active:
		mark_boss_defeated(boss_id)
	if was_active:
		active_boss_id = ""
		active_boss_serial = 0


func mark_boss_defeated(boss_id: String) -> bool:
	if boss_id.is_empty() or is_boss_defeated(boss_id):
		return false
	if active_boss_id != boss_id:
		push_warning(
			"GameState: kemenangan boss '%s' diabaikan karena tidak ada pertarungan aktif."
			% boss_id
		)
		return false
	defeated_bosses.append(boss_id)
	EventBus.save_requested.emit()
	return true


func reset_boss_status(boss_id: String) -> void:
	if boss_id.is_empty():
		return
	if active_boss_id == boss_id:
		active_boss_id = ""
		active_boss_serial = 0
	var index := defeated_bosses.find(boss_id)
	if index >= 0:
		defeated_bosses.remove_at(index)


func is_boss_defeated(boss_id: String) -> bool:
	return not boss_id.is_empty() and defeated_bosses.has(boss_id)


func set_status(new_status: GameStatus) -> void:
	if status == new_status:
		return
	status = new_status
	EventBus.game_status_changed.emit(int(status))


func load_from_save(
	new_total_souls: int,
	hp_level: int,
	potion_level: int,
	soul_save_level: int,
	attack_level: int = 0,
	saved_health: int = -1,
	saved_special_energy: float = -1.0,
	saved_defeated_bosses: Array = [],
	saved_inventory: Dictionary = {}
) -> void:
	total_souls = maxi(new_total_souls, 0)
	upgrade_hp_level = maxi(hp_level, 0)
	upgrade_potion_level = maxi(potion_level, 0)
	upgrade_soul_save_level = maxi(soul_save_level, 0)
	upgrade_attack_level = maxi(attack_level, 0)
	inventory.clear()
	if typeof(saved_inventory) == TYPE_DICTIONARY:
		for key in saved_inventory.keys():
			var val: Variant = saved_inventory[key]
			if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
				var count := int(val)
				if count > 0:
					inventory[String(key)] = count
	defeated_bosses.clear()
	for boss_value in saved_defeated_bosses:
		if typeof(boss_value) != TYPE_STRING and typeof(boss_value) != TYPE_STRING_NAME:
			continue
		var boss_id := String(boss_value).strip_edges()
		if not boss_id.is_empty() and not defeated_bosses.has(boss_id):
			defeated_bosses.append(boss_id)
	active_boss_id = ""
	active_boss_serial = 0
	registered_altars.clear()
	max_health = get_calculated_max_health()
	var health_to_use := saved_health if saved_health > 0 else max_health
	current_health = clampi(health_to_use, 0, max_health)
	max_special_energy = BASE_MAX_SPECIAL_ENERGY
	_special_energy_regen_delay = 0.0
	if saved_special_energy >= 0.0:
		_set_special_energy(saved_special_energy)
	else:
		_set_special_energy(max_special_energy)
	status = GameStatus.PLAYING
	EventBus.health_changed.emit(current_health, max_health)
	EventBus.souls_changed.emit(total_souls)


func reset_to_new_game() -> void:
	total_souls = 0
	upgrade_hp_level = 0
	upgrade_attack_level = 0
	upgrade_potion_level = 0
	upgrade_soul_save_level = 0
	inventory.clear()
	active_boss_id = ""
	active_boss_serial = 0
	defeated_bosses.clear()
	registered_altars.clear()
	max_health = get_calculated_max_health()
	current_health = max_health
	max_special_energy = BASE_MAX_SPECIAL_ENERGY
	_special_energy_regen_delay = 0.0
	_set_special_energy(max_special_energy)
	status = GameStatus.PLAYING
	EventBus.health_changed.emit(current_health, max_health)
	EventBus.souls_changed.emit(total_souls)
