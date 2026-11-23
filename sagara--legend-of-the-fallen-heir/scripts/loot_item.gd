extends Area2D

const ITEM_DATA := {
	"keris_nogososro": {
		"name": "Keris Nogososro",
		"kind": "weapon",
		"value": 1,
		"color": Color(0.98, 0.84, 0.35, 1.0),
		"description": "Kekuatan serangan +1",
	},
	"jamu_hp": {
		"name": "Jamu HP",
		"kind": "heal",
		"value": 40,
		"color": Color(0.38, 0.95, 0.55, 1.0),
		"description": "Memulihkan 40 HP",
	},
}

const FLOAT_HEIGHT := 5.0
const FLOAT_DURATION := 0.8
const COLLECT_DURATION := 0.22

@export var item_id: String = "jamu_hp"

var _collected := false

@onready var _core: Polygon2D = $Visual/Core
@onready var _glow: ColorRect = $Visual/Glow
@onready var _name_label: Label = $NameLabel
@onready var _visual: Node2D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_item_data()
	_start_float_animation()


func setup(new_item_id: String) -> void:
	item_id = new_item_id
	if is_node_ready():
		_apply_item_data()


func _apply_item_data() -> void:
	var data: Dictionary = ITEM_DATA.get(item_id, {})
	if data.is_empty():
		push_warning("ID item tidak dikenal: %s" % item_id)
		return
	var item_color: Color = data["color"]
	_core.color = item_color
	_glow.color = Color(item_color.r, item_color.g, item_color.b, 0.16)
	_name_label.text = "%s\n%s" % [data["name"], data["description"]]
	_name_label.add_theme_color_override("font_color", item_color)


func _start_float_animation() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_visual, "position:y", -FLOAT_HEIGHT, FLOAT_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_visual, "position:y", 0.0, FLOAT_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	_collected = true
	set_deferred("monitoring", false)

	var data: Dictionary = ITEM_DATA.get(item_id, {})
	match data.get("kind", ""):
		"weapon":
			if body.has_method("equip_weapon"):
				body.call("equip_weapon", data["name"], int(data["value"]))
		"heal":
			if body.has_method("heal"):
				body.call("heal", int(data["value"]))

	EventBus.item_collected.emit(item_id, int(data.get("value", 0)))
	if body.has_method("show_message"):
		body.call("show_message", "%s diperoleh! %s" % [data.get("name", "Item"), data.get("description", "")])
	_play_collect_animation()


func _play_collect_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 22.0, COLLECT_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, COLLECT_DURATION)
	tween.finished.connect(queue_free)
