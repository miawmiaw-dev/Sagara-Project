extends PlayerState

const PARRY_WINDOW := 0.2
const PARRY_COOLDOWN := 0.55
const PARRY_STUN_DURATION := 1.1
const PARRY_AREA_RADIUS := 48.0
const PARRY_COLOR := Color(0.35, 0.95, 1.0, 1.0)
const PARRY_EFFECT_DURATION := 0.3
const ENEMY_HURTBOX_LAYER := 2
const WORLD_COLLISION_LAYER := 1

var _timer: float = 0.0
var _parry_area: Area2D
var _resolved: bool = false


func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	_timer = PARRY_WINDOW
	_resolved = false
	player.parry_cooldown_timer = PARRY_COOLDOWN
	player.set_visual_color(PARRY_COLOR)
	player.play_animation(&"parry")
	_create_parry_area()


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)

	if player.can_start_dodge() and player.consume_dodge_buffer():
		state_machine.transition_to(&"Dodge")
		return

	player.velocity.x = move_toward(
		player.velocity.x,
		0.0,
		player.get_move_speed() * 4.0 * delta
	)
	player.move_and_slide()

	if not player.is_on_floor():
		state_machine.transition_to(&"Fall")
		return

	_check_overlapping_targets()

	_timer = maxf(_timer - delta, 0.0)
	if _timer <= 0.0:
		state_machine.transition_to(&"Idle")


func try_parry(source: Node, amount: int) -> bool:
	if _resolved or source == null or not source.has_method("stun_enemy"):
		return false
	_resolve_parry(source, amount)
	return true


func _check_overlapping_targets() -> void:
	if _resolved or not is_instance_valid(_parry_area):
		return

	for body in _parry_area.get_overlapping_bodies():
		if body != player and body.has_method("stun_enemy"):
			_resolve_parry(body, 0)
			return

	for area in _parry_area.get_overlapping_areas():
		var target := area.get_parent()
		if target != null and target != player and target.has_method("stun_enemy"):
			_resolve_parry(target, 0)
			return


func _resolve_parry(attacker: Node, incoming_damage: int) -> void:
	if _resolved:
		return
	_resolved = true

	var horizontal_direction := -player.facing
	if attacker is Node2D:
		horizontal_direction = signf(
			(attacker as Node2D).global_position.x - player.global_position.x
		)
		if is_zero_approx(horizontal_direction):
			horizontal_direction = -player.facing
	player.facing = 1.0 if horizontal_direction > 0.0 else -1.0

	var reflected_damage := maxi(incoming_damage, player.get_attack_damage()) * 2
	if attacker.has_method("stun_enemy"):
		attacker.call("stun_enemy", PARRY_STUN_DURATION)
	if attacker.has_method("take_damage"):
		attacker.call("take_damage", reflected_damage, horizontal_direction)

	JuiceFX.parry_success(player.global_position, PARRY_COLOR)
	player.combat.spawn_ring(
		30.0,
		51.0,
		PARRY_COLOR,
		PARRY_EFFECT_DURATION
	)
	state_machine.transition_to(&"Idle")


func _create_parry_area() -> void:
	_parry_area = Area2D.new()
	_parry_area.name = "ParryArea"
	_parry_area.collision_layer = 0
	_parry_area.collision_mask = ENEMY_HURTBOX_LAYER | WORLD_COLLISION_LAYER
	_parry_area.monitoring = true
	_parry_area.monitorable = false

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = PARRY_AREA_RADIUS
	collision.shape = shape
	_parry_area.add_child(collision)
	player.add_child(_parry_area)


func exit() -> void:
	if is_instance_valid(_parry_area):
		_parry_area.queue_free()
	_parry_area = null
	player.restore_visual_color()
