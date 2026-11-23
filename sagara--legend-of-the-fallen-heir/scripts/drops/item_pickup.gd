class_name ItemPickup
extends Area2D

const FLOAT_HEIGHT := 5.0
const FLOAT_DURATION := 0.8
const COLLECT_RISE := 24.0
const COLLECT_DURATION := 0.22
const MAGNET_SPEED := 320.0
const MAGNET_ACCEL := 600.0

@export var item_data: ItemDropData = null
@export var magnet_enabled: bool = true
@export var magnet_range: float = 90.0

var _collected := false
var _magnet_target: Node2D = null
var _magnet_velocity: Vector2 = Vector2.ZERO

@onready var _visual: Node2D = get_node_or_null("Visual") as Node2D
@onready var _core: Polygon2D = get_node_or_null("Visual/Core") as Polygon2D
@onready var _glow: CanvasItem = get_node_or_null("Visual/Glow") as CanvasItem
@onready var _name_label: Label = get_node_or_null("NameLabel") as Label
@onready var _magnet_area: Area2D = get_node_or_null("MagnetArea") as Area2D


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if _magnet_area != null and not _magnet_area.body_entered.is_connected(_on_magnet_entered):
		_magnet_area.body_entered.connect(_on_magnet_entered)
	_apply_data()
	_start_idle_animations()
	_setup_magnet()


func setup(data: ItemDropData) -> void:
	item_data = data
	if is_node_ready():
		_apply_data()
		_setup_magnet()


func _apply_data() -> void:
	if item_data == null:
		return

	if is_instance_valid(_core):
		_core.color = item_data.color
	if is_instance_valid(_glow):
		_glow.color = Color(
			item_data.color.r,
			item_data.color.g,
			item_data.color.b,
			0.18
		)
	if is_instance_valid(_name_label):
		_name_label.text = item_data.display_name
		_name_label.visible = not item_data.display_name.is_empty()
		_name_label.add_theme_color_override("font_color", item_data.color)


func _setup_magnet() -> void:
	if _magnet_area == null:
		return
	var shape := _magnet_area.get_node_or_null("CollisionShape2D")
	if shape != null and shape.shape is CircleShape2D:
		var circle := shape.shape as CircleShape2D
		circle.radius = magnet_range


func _physics_process(delta: float) -> void:
	if _collected or _magnet_target == null or not is_instance_valid(_magnet_target):
		_magnet_target = null
		return
	var dir := (_magnet_target.global_position - global_position).normalized()
	_magnet_velocity = _magnet_velocity.move_toward(dir * MAGNET_SPEED, MAGNET_ACCEL * delta)
	global_position += _magnet_velocity * delta


func _on_magnet_entered(body: Node2D) -> void:
	if _collected or not magnet_enabled or _magnet_target != null:
		return
	if body != null and body.is_in_group("player"):
		_magnet_target = body


func _start_idle_animations() -> void:
	if is_instance_valid(_visual):
		var float_tween := create_tween().set_loops()
		float_tween.tween_property(_visual, "position:y", -FLOAT_HEIGHT, FLOAT_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		float_tween.tween_property(_visual, "position:y", 0.0, FLOAT_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if is_instance_valid(_glow):
		var glow_tween := create_tween().set_loops()
		glow_tween.tween_property(_glow, "modulate:a", 0.45, FLOAT_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glow_tween.tween_property(_glow, "modulate:a", 1.0, FLOAT_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node2D) -> void:
	if _collected or item_data == null or body == null:
		return
	if not body.is_in_group("player"):
		return

	_collected = true
	set_deferred("monitoring", false)
	if _magnet_area != null:
		_magnet_area.set_deferred("monitoring", false)

	var amount := item_data.get_amount()
	_apply_reward(amount)
	EventBus.item_collected.emit(item_data.item_id, amount)
	if not item_data.display_name.is_empty():
		EventBus.notification_requested.emit("%s diperoleh!" % item_data.display_name)
	if has_node("/root/JuiceFX"):
		var juice = get_node("/root/JuiceFX")
		if juice.has_method("flash_screen"):
			juice.call("flash_screen", Color(0.6, 0.9, 1.0, 0.12), 0.12)
	_play_collect_animation()


func _apply_reward(amount: int) -> void:
	if amount <= 0:
		return

	if item_data.item_id != "":
		GameState.add_item(item_data.item_id, amount, true)

	match item_data.kind:
		ItemDropData.Kind.SOULS:
			GameState.add_souls(amount)
		ItemDropData.Kind.HEAL:
			GameState.heal(amount)


func _play_collect_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - COLLECT_RISE, COLLECT_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, COLLECT_DURATION)
	if is_instance_valid(_visual):
		tween.tween_property(_visual, "scale", Vector2(1.4, 1.4), COLLECT_DURATION)
	tween.finished.connect(queue_free)
