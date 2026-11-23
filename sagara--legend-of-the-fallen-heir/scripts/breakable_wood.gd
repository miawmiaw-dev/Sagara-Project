extends StaticBody2D

const HIT_FLASH_COLOR := Color(1.0, 0.72, 0.35, 1.0)
const BREAK_FADE_TIME := 0.16

@export var max_health: int = 1

var health: int = 1
var is_broken := false

var _flash_tween: Tween

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D


func _ready() -> void:
	add_to_group("breakable_wood")
	health = maxi(max_health, 1)


func take_damage(
	amount: int,
	direction: float = 0.0,
	_knockback_force: float = 0.0
) -> bool:
	if is_broken or amount <= 0:
		return false
	health -= amount
	if health > 0:
		_play_hit_feedback(direction)
		return true
	_break_apart(direction)
	return true


func _play_hit_feedback(direction: float) -> void:
	JuiceFX.wood_hit(global_position, direction)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", HIT_FLASH_COLOR, 0.04)
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.12)


func _break_apart(direction: float) -> void:
	is_broken = true
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = Color.WHITE
	JuiceFX.wood_break(global_position, direction, 1.0)
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", true)
	if is_instance_valid(hurtbox):
		hurtbox.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, BREAK_FADE_TIME)
	tween.finished.connect(queue_free)
