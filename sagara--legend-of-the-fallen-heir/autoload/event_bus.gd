extends Node

signal health_changed(current_health: int, max_health: int)
signal souls_changed(total_souls: int)
signal enemy_killed(enemy: Node, at_position: Vector2)
signal item_collected(item_id: String, amount: int)
signal weapon_equipped(weapon: Resource)
signal dodge_ready_changed(is_ready: bool)
signal special_energy_changed(current_energy: float, max_energy: float)
signal special_skill_used(skill_name: String, style: int)
signal special_skill_failed(reason: String)
signal notification_requested(text: String)
signal boss_fight_started(boss_name: String, max_health: int)
signal boss_health_changed(current_health: int, max_health: int)
signal boss_fight_ended(boss_name: String, victory: bool)
signal game_status_changed(status: int)
signal save_requested
signal game_saved
signal game_loaded
signal player_respawned(at_position: Vector2)
signal attack_upgraded(level: int, new_power: int)
signal altar_upgraded(upgrade_type: String, new_level: int)
