extends "res://scripts/interactable_area.gd"

const LOOT_SCENE := preload("res://scenes/loot_item.tscn")
const DEFAULT_LOOT_TABLE := ["keris_nogososro", "jamu_hp"]
const OPEN_DURATION := 0.32
const DROP_DISTANCE := 64.0

@export var loot_table: Array[String] = []
@export var item_drop_table: ItemDropTable = null
@export var drop_spawn_offset: Vector2 = Vector2(0.0, -36.0)

var _opened := false
var _opening := false
var _lid: ColorRect = null
var _glow: ColorRect = null
var _idle_tween: Tween = null


func _on_interactable_ready() -> void:
	_lid = get_node_or_null("Lid") as ColorRect
	_glow = get_node_or_null("Glow") as ColorRect
	if loot_table.is_empty() and item_drop_table == null:
		loot_table.assign(DEFAULT_LOOT_TABLE)
	_start_idle_glow()


func can_interact() -> bool:
	return not _opened and not _opening


func get_prompt_text() -> String:
	return "E / F : Buka Peti Pusaka"


func interact(player: Node2D) -> void:
	if _opened or _opening:
		return
	_opening = true
	refresh_prompt()
	_play_open_feedback()
	await _play_open_animation()
	_drop_loot(player)
	_opened = true
	_opening = false
	refresh_prompt()


func _play_open_feedback() -> void:
	JuiceFX.chest_open(global_position + Vector2(0.0, -22.0))
	var flash := create_tween()
	flash.tween_property(self, "modulate", Color(1.65, 1.5, 1.05, 1.0), 0.04)
	flash.tween_property(self, "modulate", Color.WHITE, 0.07)
	flash.tween_property(self, "modulate", Color(1.35, 1.25, 0.9, 1.0), 0.04)
	flash.tween_property(self, "modulate", Color.WHITE, 0.1)


func _start_idle_glow() -> void:
	if _glow == null:
		return
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(_glow, "modulate:a", 0.35, 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(_glow, "modulate:a", 1.0, 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_open_animation() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()

	if _glow != null:
		var flash := create_tween()
		flash.tween_property(_glow, "color:a", 0.6, 0.16)
		flash.tween_property(_glow, "color:a", 0.18, OPEN_DURATION)

	if _lid == null:
		await get_tree().create_timer(OPEN_DURATION).timeout
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_lid, "rotation", -1.15, OPEN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_lid, "position:y", _lid.position.y - 7.0, OPEN_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished


func _drop_loot(player: Node2D) -> void:
	var parent := get_parent()
	if parent == null:
		return

	if item_drop_table != null:
		ItemDropSpawner.spawn_table(item_drop_table, parent, global_position + drop_spawn_offset)
		return

	if loot_table.is_empty():
		loot_table.assign(DEFAULT_LOOT_TABLE)
	if loot_table.is_empty():
		return

	var loot := LOOT_SCENE.instantiate()
	loot.setup(loot_table[randi_range(0, loot_table.size() - 1)])
	parent.add_child(loot)
	loot.global_position = global_position + Vector2(0.0, -36.0)

	var drop_direction := 1.0
	if is_instance_valid(player):
		drop_direction = signf(global_position.x - player.global_position.x)
		if is_zero_approx(drop_direction):
			drop_direction = 1.0 if randf() < 0.5 else -1.0

	var landing_position := global_position + Vector2(drop_direction * DROP_DISTANCE, -20.0)
	var tween := loot.create_tween()
	tween.tween_property(loot, "global_position", landing_position, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
