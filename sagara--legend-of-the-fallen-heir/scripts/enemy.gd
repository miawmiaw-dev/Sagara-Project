extends CharacterBody2D

enum State {
	PATROL,
	CHASE,
	ATTACK,
}

const KNOCKBACK_FORCE = 300.0
const KNOCKBACK_LIFT = -150.0
const HIT_FLASH_TIME = 0.15
const HIT_COLOR = Color(1, 0, 0, 1)
const STUN_COLOR = Color(1, 1, 0, 1)
const FRICTION = 800.0
const SOUL_SCENE := preload("res://scenes/soul.tscn")
const SOUL_DROP_MIN := 2
const SOUL_DROP_MAX := 5

@export var patrol_speed: float = 60.0
@export var chase_speed: float = 120.0
@export var detection_range: float = 150.0
@export var attack_range: float = 40.0
@export var attack_damage: int = 10
@export var attack_cooldown_time: float = 0.9
@export var patrol_range: float = 120.0

var health = 3
var is_hit = false
var is_stunned = false
var stun_timer = 0.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var state: State = State.PATROL
var patrol_direction: float = 1.0
var patrol_origin_x: float = 0.0
var facing: float = 1.0
var attack_cooldown: float = 0.0
var player = null

var _stun_generation := 0
var _hit_generation := 0
var _dying := false

@onready var color_rect: ColorRect = $ColorRect
@onready var attack_area: Area2D = $AttackArea
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
var original_color: Color = Color.WHITE

func _ready() -> void:
	if color_rect:
		original_color = color_rect.color
	patrol_origin_x = global_position.x
	player = _find_player()
	_refresh_visual()

func _find_player() -> Node2D:
	var node := get_tree().get_first_node_in_group("player")
	if node is Node2D:
		return node
	return null

func _physics_process(delta: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown = maxf(attack_cooldown - delta, 0.0)

	if is_stunned:
		_process_stunned(delta)
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	if is_hit:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
		return

	if not is_instance_valid(player):
		player = _find_player()

	var distance := INF
	if is_instance_valid(player):
		distance = global_position.distance_to(player.global_position)

	_update_state(distance)

	match state:
		State.PATROL:
			_do_patrol()
		State.CHASE:
			_do_chase()
		State.ATTACK:
			_do_attack(delta)

	move_and_slide()

func _process_stunned(delta: float) -> void:
	stun_timer = maxf(stun_timer - delta, 0.0)
	velocity = Vector2.ZERO
	if stun_timer <= 0.0:
		_end_stun()
	move_and_slide()

func _update_state(distance: float) -> void:
	if distance <= attack_range:
		state = State.ATTACK
	elif distance <= detection_range:
		state = State.CHASE
	else:
		state = State.PATROL

func _do_patrol() -> void:
	var distance_from_origin := global_position.x - patrol_origin_x
	if distance_from_origin >= patrol_range:
		patrol_direction = -1.0
	elif distance_from_origin <= -patrol_range:
		patrol_direction = 1.0

	if is_on_wall():
		patrol_direction *= -1.0

	velocity.x = patrol_direction * patrol_speed
	facing = patrol_direction

func _do_chase() -> void:
	if not is_instance_valid(player):
		state = State.PATROL
		return

	var direction := signf(player.global_position.x - global_position.x)
	if is_zero_approx(direction):
		direction = facing
	facing = direction
	velocity.x = direction * chase_speed

func _do_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	if not is_instance_valid(player):
		state = State.PATROL
		return

	var direction := signf(player.global_position.x - global_position.x)
	if not is_zero_approx(direction):
		facing = direction

	if attack_cooldown <= 0.0 and _is_touching_player():
		_attack_player()

func _is_touching_player() -> bool:
	if not is_instance_valid(attack_area):
		return false
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			return true
	return false

func _attack_player() -> void:
	if not is_instance_valid(player) or is_stunned:
		return

	attack_cooldown = attack_cooldown_time

	var direction := signf(player.global_position.x - global_position.x)
	if is_zero_approx(direction):
		direction = facing

	var damaged = player.take_damage(attack_damage, self)
	if damaged and player.has_method("apply_knockback"):
		player.apply_knockback(direction, KNOCKBACK_FORCE)

func stun_enemy(duration: float) -> void:
	if duration <= 0.0:
		return

	_stun_generation += 1
	var generation := _stun_generation
	is_stunned = true
	stun_timer = maxf(stun_timer, duration)
	attack_cooldown = maxf(attack_cooldown, duration)
	state = State.PATROL
	velocity = Vector2.ZERO
	_refresh_visual()

	await get_tree().create_timer(duration).timeout
	if generation != _stun_generation:
		return
	_end_stun()

func _end_stun() -> void:
	if not is_stunned:
		return
	_stun_generation += 1
	is_stunned = false
	stun_timer = 0.0
	velocity = Vector2.ZERO
	_refresh_visual()

func stun(duration: float, _knockback_dir: float = 0.0, _force: float = KNOCKBACK_FORCE) -> void:
	stun_enemy(duration)

func take_damage(
	amount: int,
	knockback_dir: float = 0.0,
	knockback_force: float = KNOCKBACK_FORCE
) -> void:
	if amount <= 0 or _dying:
		return

	health -= amount
	if health <= 0:
		_die()
		return

	_hit_generation += 1
	var generation := _hit_generation
	is_hit = true
	if not is_stunned:
		velocity.x = knockback_dir * knockback_force
		velocity.y = KNOCKBACK_LIFT
	_refresh_visual()

	await get_tree().create_timer(HIT_FLASH_TIME).timeout
	if not is_inside_tree() or generation != _hit_generation:
		return
	is_hit = false
	_refresh_visual()

func _refresh_visual() -> void:
	if is_instance_valid(sprite):
		if is_stunned:
			sprite.modulate = STUN_COLOR
		elif is_hit:
			sprite.modulate = HIT_COLOR
		else:
			sprite.modulate = Color(1, 1, 1)
	if is_instance_valid(color_rect):
		if is_stunned:
			color_rect.color = Color(1, 1, 1)
			color_rect.modulate = STUN_COLOR
		elif is_hit:
			color_rect.color = HIT_COLOR
			color_rect.modulate = Color(1, 1, 1)
		else:
			color_rect.color = original_color
			color_rect.modulate = Color(1, 1, 1)

func _die() -> void:
	if _dying:
		return
	_dying = true
	EventBus.enemy_killed.emit(self, global_position)
	_spawn_souls.call_deferred()
	queue_free.call_deferred()

func _spawn_souls() -> void:
	var parent := get_parent()
	if parent == null or not parent is Node2D:
		return

	var count := randi_range(SOUL_DROP_MIN, SOUL_DROP_MAX)
	for i in range(count):
		var soul := SOUL_SCENE.instantiate()
		parent.add_child(soul)
		var offset := Vector2(randf_range(-30.0, 30.0), randf_range(-26.0, -8.0))
		soul.global_position = global_position + offset
