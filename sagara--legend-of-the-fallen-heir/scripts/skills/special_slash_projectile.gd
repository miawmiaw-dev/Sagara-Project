class_name SpecialSlashProjectile
extends Area2D

signal hit_registered(target: Node)

const ENEMY_HURTBOX_LAYER := 2
const MIN_LIFETIME := 0.05

var _skill: SpecialSkillData
var _damage: int = 0
var _direction: float = 1.0
var _knockback_force: float = 0.0
var _speed: float = 0.0
var _max_distance: float = 1.0
var _stun_duration: float = 0.0
var _pierces: bool = true
var _distance_travelled: float = 0.0
var _active: bool = false
var _built: bool = false
var _hit_targets: Dictionary = {}
var _collision: CollisionShape2D
var _visual: Node2D


func setup(skill: SpecialSkillData, damage: int, direction: float) -> bool:
	if skill == null:
		return false

	_skill = skill
	_damage = maxi(damage, 0)
	_direction = 1.0 if direction >= 0.0 else -1.0
	_knockback_force = maxf(skill.knockback_multiplier, 0.0) * 320.0
	_speed = maxf(skill.projectile_speed, 1.0)
	_max_distance = maxf(skill.projectile_range, 1.0)
	_stun_duration = maxf(skill.stun_duration, 0.0)
	_pierces = skill.projectile_pierces
	_build()
	if is_inside_tree():
		_active = _damage > 0 and _speed > 0.0
	return true


func _ready() -> void:
	collision_layer = 0
	collision_mask = ENEMY_HURTBOX_LAYER
	monitoring = true
	monitorable = false
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if _skill != null:
		_build()
	_active = _damage > 0 and _speed > 0.0


func _physics_process(delta: float) -> void:
	if not _active or _skill == null:
		return

	var motion := Vector2(_direction * _speed * delta, 0.0)
	global_position += motion
	_distance_travelled += absf(motion.x)

	for area in get_overlapping_areas():
		_try_hit(area)

	if _distance_travelled >= _max_distance:
		_finish()


func is_active() -> bool:
	return _active


func _build() -> void:
	if _built or _skill == null:
		return
	_built = true

	var size := Vector2(
		maxf(_skill.projectile_size.x, 4.0),
		maxf(_skill.projectile_size.y, 4.0)
	)

	_collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	_collision.shape = shape
	add_child(_collision)

	_visual = Node2D.new()
	_visual.scale = Vector2(_direction, 1.0)
	add_child(_visual)

	var half_size := size * 0.5
	var slash_points := PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x * 0.75, 0.0),
		Vector2(-half_size.x, half_size.y),
	])

	var glow := Line2D.new()
	glow.width = maxf(size.y * 0.6, 8.0)
	glow.default_color = Color(
		_skill.effect_color.r,
		_skill.effect_color.g,
		_skill.effect_color.b,
		0.22
	)
	glow.points = slash_points
	_visual.add_child(glow)

	var core := Line2D.new()
	core.width = maxf(size.y * 0.22, 3.0)
	core.default_color = _skill.effect_color
	core.points = slash_points
	_visual.add_child(core)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _try_hit(area: Area2D) -> void:
	if not _active or not is_instance_valid(area) or _damage <= 0:
		return

	var target := area.get_parent()
	if (
		not is_instance_valid(target)
		or target.is_in_group("player")
		or not target.has_method("take_damage")
		or _hit_targets.has(target)
	):
		return

	_hit_targets[target] = true
	target.call("take_damage", _damage, _direction, _knockback_force)
	if _stun_duration > 0.0 and target.has_method("stun_enemy"):
		target.call("stun_enemy", _stun_duration)
	if is_instance_valid(target):
		hit_registered.emit(target)

	if not _pierces:
		_finish()


func _finish() -> void:
	if not _active:
		return
	_active = false
	set_deferred("monitoring", false)
	if _collision != null:
		_collision.set_deferred("disabled", true)

	if not is_inside_tree():
		queue_free()
		return

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, MIN_LIFETIME)
	tween.finished.connect(queue_free)
