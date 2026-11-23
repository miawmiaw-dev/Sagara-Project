extends StaticBody2D

const FLASH_COLOR := Color(1.0, 0.55, 0.15, 1.0)
const BREAK_FADE_TIME := 0.18

@export var max_health: int = 1
@export var slam_damage: int = 1

var health: int = 1
var is_broken := false

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

func _ready() -> void:
	add_to_group("breakable_floor")
	health = max_health

func break_from_slam() -> void:
	if is_broken:
		return
	health -= slam_damage
	if health > 0:
		_flash()
		JuiceFX.wood_hit(global_position, 0.0)
		return
	_break_apart()

func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", FLASH_COLOR, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)

func _break_apart() -> void:
	is_broken = true
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", true)
	JuiceFX.wood_break(global_position, 0.0, 1.5)
	JuiceFX.shake_camera(3.2, 0.2, 30.0)
	_spawn_debris()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, BREAK_FADE_TIME)
	tween.finished.connect(queue_free)

func _spawn_debris() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in range(4):
		var piece := ColorRect.new()
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.color = Color(0.52, 0.38, 0.18, 1.0)
		piece.size = Vector2(14, 8)
		parent.add_child(piece)
		piece.global_position = global_position + Vector2(-60.0 + float(i) * 36.0, -4.0)
		var tween := piece.create_tween()
		tween.set_parallel(true)
		tween.tween_property(piece, "global_position", piece.global_position + Vector2(randf_range(-40.0, 40.0), 140.0), 0.45)
		tween.tween_property(piece, "rotation", randf_range(-2.5, 2.5), 0.45)
		tween.tween_property(piece, "modulate:a", 0.0, 0.45)
		tween.finished.connect(piece.queue_free)
