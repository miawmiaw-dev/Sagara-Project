class_name PlayerCombat
extends Node2D

const ENEMY_HURTBOX_LAYER := 2
const WORLD_COLLISION_LAYER := 1
const DIVE_STUN_DURATION := 1.1
const KNOCKBACK_PIXELS_PER_UNIT := 16.0
const SPECIAL_KNOCKBACK_PIXELS_PER_UNIT := 320.0
const SPECIAL_MIN_SIZE := 4.0
const SPECIAL_EFFECT_Z_INDEX := 2

@onready var weapon_hitbox: WeaponHitbox = $WeaponHitbox

var _player: SagaraPlayer


func _ready() -> void:
	_player = get_parent() as SagaraPlayer
	if weapon_hitbox != null:
		weapon_hitbox.hit_registered.connect(_on_weapon_hit_registered)


func attack(
	step: AttackStepData,
	damage: int,
	facing: float,
	weapon: WeaponData,
	hitbox_lifetime: float
) -> void:
	if _player == null or weapon == null or weapon_hitbox == null:
		return

	var attack_range := _player.get_attack_range()
	var hitbox_size := Vector2(attack_range, 48.0)
	var hitbox_offset := hitbox_size.x * 0.5 + 6.0
	var knockback_multiplier := 1.0
	if step != null:
		hitbox_size = Vector2(
			maxf(step.hitbox_size.x, attack_range),
			maxf(step.hitbox_size.y, 1.0)
		)
		hitbox_offset = maxf(step.hitbox_offset, hitbox_size.x * 0.5)
		knockback_multiplier = maxf(step.knockback_multiplier, 0.0)

	var direction := 1.0 if facing >= 0.0 else -1.0
	var knockback_force := weapon.knockback * knockback_multiplier * KNOCKBACK_PIXELS_PER_UNIT
	weapon_hitbox.activate(
		hitbox_size,
		hitbox_offset,
		direction,
		damage,
		direction,
		knockback_force,
		maxf(hitbox_lifetime, 0.01),
		_player
	)


func cancel_attack_hitbox() -> void:
	if weapon_hitbox != null:
		weapon_hitbox.deactivate()


func _on_weapon_hit_registered(target: Node) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if target == null or not is_instance_valid(target):
		return
	var hit_position := _player.global_position
	if target is Node2D:
		hit_position = (target as Node2D).global_position
	var step := _player.get_current_attack_step()
	var heavy := _player.combo_step >= maxi(_player.get_weapon_combo_count() - 1, 0)
	JuiceFX.enemy_hit(
		target,
		hit_position,
		_player.get_attack_damage(step),
		Color(1.0, 0.88, 0.5, 1.0),
		_player.facing,
		heavy
	)


# target dari sinyal hit_registered diletakkan di parameter pertama.
func _on_special_projectile_hit(
	target: Node,
	projectile: SpecialSlashProjectile,
	skill: SpecialSkillData
) -> void:
	if target == null or not is_instance_valid(target):
		return
	if _player == null or skill == null or not is_instance_valid(_player):
		return
	if projectile != null and not is_instance_valid(projectile):
		projectile = null
	var hit_position := _player.global_position
	if target is Node2D:
		hit_position = (target as Node2D).global_position
	elif projectile != null and is_instance_valid(projectile):
		hit_position = projectile.global_position
	JuiceFX.enemy_hit(
		target,
		hit_position,
		_player.get_special_damage(skill),
		skill.effect_color,
		_player.facing,
		true
	)


func use_special_skill(skill: SpecialSkillData, damage: int, facing: float) -> bool:
	if skill == null or damage <= 0 or not is_instance_valid(_player):
		return false

	match skill.style:
		SpecialSkillData.Style.GROUND_AOE:
			return _strike_special_aoe(skill, damage, facing)
		SpecialSkillData.Style.PROJECTILE:
			return _spawn_special_projectile(skill, damage, facing)
	return false


func _spawn_special_projectile(
	skill: SpecialSkillData,
	damage: int,
	facing: float
) -> bool:
	if skill == null or not is_instance_valid(_player):
		return false

	var direction := 1.0 if facing >= 0.0 else -1.0
	var projectile := SpecialSlashProjectile.new()
	if not projectile.setup(skill, damage, direction):
		projectile.queue_free()
		return false

	projectile.z_index = SPECIAL_EFFECT_Z_INDEX
	add_child(projectile)
	projectile.global_position = (
		_player.global_position
		+ Vector2(direction * maxf(skill.spawn_offset, 0.0), 0.0)
	)
	projectile.hit_registered.connect(func(target: Node):
		_on_special_projectile_hit(target, projectile, skill)
	)
	return true


func _strike_special_aoe(skill: SpecialSkillData, damage: int, facing: float) -> bool:
	if skill == null or not is_instance_valid(_player):
		return false

	var direction := 1.0 if facing >= 0.0 else -1.0
	var hitbox := Area2D.new()
	hitbox.name = "SpecialAoeHitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = ENEMY_HURTBOX_LAYER
	hitbox.monitoring = true
	hitbox.monitorable = false

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(
		maxf(skill.hitbox_size.x, SPECIAL_MIN_SIZE),
		maxf(skill.hitbox_size.y, SPECIAL_MIN_SIZE)
	)
	collision.shape = shape
	collision.position = Vector2(direction * maxf(skill.spawn_offset, 0.0), 0.0)
	hitbox.add_child(collision)

	var hit_targets: Dictionary = {}
	hitbox.area_entered.connect(func(area: Area2D):
		_on_special_aoe_area_entered(area, hit_targets, skill, damage, direction)
	)
	add_child(hitbox)
	_resolve_special_aoe_overlaps(hitbox, hit_targets, skill, damage, direction)
	_spawn_special_aoe_effect(skill, direction)
	_expire_node(hitbox, maxf(skill.active_time, 0.1))
	return true


func _resolve_special_aoe_overlaps(
	hitbox: Area2D,
	hit_targets: Dictionary,
	skill: SpecialSkillData,
	damage: int,
	direction: float
) -> void:
	await get_tree().physics_frame
	if not is_instance_valid(hitbox) or not hitbox.is_inside_tree():
		return
	for area in hitbox.get_overlapping_areas():
		_apply_special_aoe_hit(area, hit_targets, skill, damage, direction)


# area dari sinyal area_entered diletakkan di parameter pertama.
func _on_special_aoe_area_entered(
	area: Area2D,
	hit_targets: Dictionary,
	skill: SpecialSkillData,
	damage: int,
	direction: float
) -> void:
	_apply_special_aoe_hit(area, hit_targets, skill, damage, direction)


func _apply_special_aoe_hit(
	area: Area2D,
	hit_targets: Dictionary,
	skill: SpecialSkillData,
	damage: int,
	fallback_direction: float
) -> void:
	if skill == null or damage <= 0 or not is_instance_valid(area):
		return

	var target := area.get_parent()
	if (
		not is_instance_valid(target)
		or target == _player
		or target.is_in_group("player")
		or not target.has_method("take_damage")
		or hit_targets.has(target)
	):
		return

	var hit_direction := fallback_direction
	if target is Node2D and is_instance_valid(_player):
		var offset_x := (target as Node2D).global_position.x - _player.global_position.x
		if not is_zero_approx(offset_x):
			hit_direction = signf(offset_x)

	hit_targets[target] = true
	var knockback_force := (
		maxf(skill.knockback_multiplier, 0.0) * SPECIAL_KNOCKBACK_PIXELS_PER_UNIT
	)
	var hit_applied = target.call("take_damage", damage, hit_direction, knockback_force)
	if skill.stun_duration > 0.0 and target.has_method("stun_enemy"):
		target.call("stun_enemy", skill.stun_duration)
	if hit_applied != false and target is Node2D:
		JuiceFX.enemy_hit(
			target,
			(target as Node2D).global_position,
			damage,
			skill.effect_color,
			hit_direction,
			true
		)


func _spawn_special_aoe_effect(skill: SpecialSkillData, direction: float) -> void:
	if skill == null or not is_inside_tree():
		return

	var effect := Node2D.new()
	effect.name = "SpecialAoeEffect"
	effect.position = Vector2(direction * maxf(skill.spawn_offset, 0.0), 0.0)
	effect.scale = Vector2(direction, 1.0)
	effect.z_index = SPECIAL_EFFECT_Z_INDEX
	add_child(effect)

	var size := Vector2(
		maxf(skill.hitbox_size.x, SPECIAL_MIN_SIZE),
		maxf(skill.hitbox_size.y, SPECIAL_MIN_SIZE)
	)
	var half_size := size * 0.5
	var slash_points := PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x * 0.65, 0.0),
		Vector2(-half_size.x, half_size.y),
	])

	var glow := Line2D.new()
	glow.width = maxf(size.y * 0.55, 8.0)
	glow.default_color = Color(
		skill.effect_color.r,
		skill.effect_color.g,
		skill.effect_color.b,
		0.25
	)
	glow.points = slash_points
	effect.add_child(glow)

	var core := Line2D.new()
	core.width = maxf(size.y * 0.2, 3.0)
	core.default_color = skill.effect_color
	core.points = slash_points
	effect.add_child(core)

	var duration := maxf(skill.active_time, 0.1)
	var tween := effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(direction * 1.2, 1.25), duration)
	tween.tween_property(effect, "modulate:a", 0.0, duration)
	tween.finished.connect(effect.queue_free)

	spawn_ring(
		maxf(skill.aoe_radius * 0.35, 8.0),
		maxf(skill.aoe_radius, 16.0),
		skill.effect_color,
		duration,
		0.0,
		0.55
	)


func dive_impact(
	radius: float,
	y_offset: float,
	damage: int,
	direction: float
) -> void:
	if _player == null:
		return

	var hitbox := Area2D.new()
	hitbox.name = "DiveShockwave"
	hitbox.collision_layer = 0
	hitbox.collision_mask = ENEMY_HURTBOX_LAYER
	hitbox.monitoring = true
	hitbox.monitorable = false

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	collision.position = Vector2(0.0, y_offset)
	hitbox.add_child(collision)
	hitbox.area_entered.connect(func(area: Area2D):
		_on_dive_area_entered(area, damage, direction, DIVE_STUN_DURATION)
	)
	add_child(hitbox)
	_expire_node(hitbox, 0.08)

	_break_floors_in_radius(radius, y_offset)


# area dari sinyal area_entered diletakkan di parameter pertama.
func _on_dive_area_entered(
	area: Area2D,
	damage: int,
	fallback_direction: float,
	stun_duration: float
) -> void:
	var target := area.get_parent()
	if (
		not is_instance_valid(target)
		or target == _player
		or not target.has_method("take_damage")
	):
		return

	var direction := fallback_direction
	if target is Node2D:
		direction = signf((target as Node2D).global_position.x - _player.global_position.x)
		if is_zero_approx(direction):
			direction = fallback_direction

	target.call("take_damage", damage, direction)
	if target.has_method("stun_enemy"):
		target.call("stun_enemy", stun_duration)
	if target is Node2D:
		JuiceFX.enemy_hit(
			target,
			(target as Node2D).global_position,
			damage,
			Color(1.0, 0.55, 0.15, 1.0),
			direction,
			true
		)


func _break_floors_in_radius(radius: float, y_offset: float) -> void:
	if _player == null:
		return

	var shape := CircleShape2D.new()
	shape.radius = radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	var query_transform := _player.global_transform
	query_transform.origin += Vector2(0.0, y_offset)
	query.transform = query_transform
	query.collision_mask = WORLD_COLLISION_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var results := _player.get_world_2d().direct_space_state.intersect_shape(query, 32)
	var hit_floors: Dictionary = {}
	for result in results:
		var collider = result.get("collider")
		if collider == null or collider == _player or hit_floors.has(collider):
			continue
		if collider.has_method("break_from_slam"):
			hit_floors[collider] = true
			collider.call("break_from_slam")


func _expire_node(node: Node, lifetime: float) -> void:
	var timer := get_tree().create_timer(maxf(lifetime, 0.01))
	timer.timeout.connect(_free_if_valid.bind(node))


func _free_if_valid(node = null) -> void:
	if is_instance_valid(node) and node is Node:
		node.queue_free()


func spawn_ring(
	start_radius: float,
	end_radius: float,
	color: Color,
	duration: float,
	y_offset: float = 0.0,
	horizontal_scale: float = 1.0
) -> void:
	var effect := Line2D.new()
	effect.width = 3.0
	effect.default_color = color
	effect.z_index = 2
	var points := PackedVector2Array()
	var segments := 28
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * start_radius)
	effect.points = points
	effect.position = Vector2(0.0, y_offset)
	add_child(effect)

	var scale_factor := end_radius / maxf(start_radius, 0.001)
	var tween := effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		effect,
		"scale",
		Vector2(scale_factor, scale_factor * horizontal_scale),
		duration
	)
	tween.tween_property(effect, "modulate:a", 0.0, duration)
	tween.finished.connect(effect.queue_free)
