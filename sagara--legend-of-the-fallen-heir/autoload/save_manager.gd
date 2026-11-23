extends Node

const SAVE_PATH := "user://savegame.cfg"
## Versi 7: flag boss dari save lama tidak lagi dipercaya. Save versi 6 pernah
## dapat menyimpan status "defeated" sebelum encounter benar-benar dimenangkan,
## sehingga boss utama biome tidak pernah spawn lagi.
const SAVE_VERSION := 7
const BOSS_FLAGS_TRUSTED_FROM_VERSION := 7
const RESET_BOSS_DEFEATS_ON_LOAD := false


func _ready() -> void:
	EventBus.save_requested.connect(save_game)
	load_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "version", SAVE_VERSION)
	config.set_value("player", "current_health", GameState.current_health)
	config.set_value("player", "current_special_energy", GameState.special_energy)
	config.set_value("upgrades", "total_souls", GameState.total_souls)
	config.set_value("upgrades", "upgrade_hp_level", GameState.upgrade_hp_level)
	config.set_value("upgrades", "upgrade_attack_level", GameState.upgrade_attack_level)
	config.set_value("upgrades", "upgrade_potion_level", GameState.upgrade_potion_level)
	config.set_value("upgrades", "upgrade_soul_save_level", GameState.upgrade_soul_save_level)

	var defeated_bosses: Array[String] = []
	for boss_value in GameState.defeated_bosses:
		var boss_id := String(boss_value).strip_edges()
		if not boss_id.is_empty() and not defeated_bosses.has(boss_id):
			defeated_bosses.append(boss_id)
	config.set_value("bosses", "defeated", defeated_bosses)

	var error := config.save(SAVE_PATH)
	if error != OK:
		push_error("Gagal menyimpan game ke %s (error %d)." % [SAVE_PATH, error])
		return
	EventBus.game_saved.emit()


func load_game() -> bool:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		GameState.reset_to_new_game()
		return false

	var total_souls := int(config.get_value("upgrades", "total_souls", 0))
	var hp_level := int(config.get_value("upgrades", "upgrade_hp_level", 0))
	var potion_level := int(config.get_value("upgrades", "upgrade_potion_level", 0))
	var soul_save_level := int(config.get_value("upgrades", "upgrade_soul_save_level", 0))
	var attack_level := int(config.get_value("upgrades", "upgrade_attack_level", 0))
	var saved_health := int(config.get_value("player", "current_health", -1))
	var saved_special_energy := float(
		config.get_value("player", "current_special_energy", -1.0)
	)
	var save_version := int(config.get_value("meta", "version", 0))
	var trusted_boss_flags := save_version >= BOSS_FLAGS_TRUSTED_FROM_VERSION
	var saved_defeated_bosses: Array = []
	if not RESET_BOSS_DEFEATS_ON_LOAD and trusted_boss_flags:
		var stored_bosses: Variant = config.get_value("bosses", "defeated", [])
		if stored_bosses is Array:
			saved_defeated_bosses = stored_bosses
	elif not RESET_BOSS_DEFEATS_ON_LOAD:
		push_warning(
			(
				"SaveManager: flag boss dari save versi %d diabaikan karena tidak "
				+ "dapat diverifikasi. Encounter boss akan dimulai ulang dengan benar."
			) % save_version
		)

	GameState.load_from_save(
		total_souls,
		hp_level,
		potion_level,
		soul_save_level,
		attack_level,
		saved_health,
		saved_special_energy,
		saved_defeated_bosses
	)
	EventBus.game_loaded.emit()
	if not trusted_boss_flags:
		save_game()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
