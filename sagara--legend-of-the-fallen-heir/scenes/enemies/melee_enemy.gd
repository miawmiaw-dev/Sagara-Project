class_name MeleeEnemy
extends CharacterBody2D

enum State {
	IDLE,
	CHASE,
	ATTACK,
	HURT,
	DEAD,
}

enum AttackPhase {
	NONE,
	WINDUP,
	ACTIVE,
	RECOVERY,
}

const HURTBOX_LAYER := 2
const PLAYER_BODY_LAYER := 1
const WORLD_LAYER := 1
const ENEMY_BODY_LAYER := 4
const BODY_COLLISION_MASK := WORLD_LAYER | PLAYER_BODY_LAYER | ENEMY_BODY_LAYER
const HURT_COLOR := Color(1.0, 0.25, 0.25, 1.0)
const WARNING_COLOR := Color(1.0, 0.55, 0.15, 1.0)
const STRIKE_COLOR := Color(1.0, 0.9, 0.55, 1.0)
const DEFAULT_DROP_TABLE := preload("res://resources/items/melee_enemy_drops.tres")

const HIT_FLASH_COLOR := Color(3.0, 2.4, 2.2, 1.0)
const HIT_FLASH_DURATION := 0.12
const HIT_SQUASH_SCALE := Vector2(1.35, 0.72)
const ATTACK_LUNGE_SCALE := Vector2(1.22, 0.82)
const IMPACT_SQUASH_SCALE := Vector2(1.3, 0.78)
const HIT_SPARK_COLOR := Color(1.0, 0.8, 0.45, 1.0)
const PLAYER_HIT_SPARK_COLOR := Color(1.0, 0.34, 0.22, 1.0)
const SWING_COLOR := Color(1.0, 0.72, 0.3, 1.0)
const HIT_SHAKE_INTENSITY := 1.8
const HIT_SHAKE_DURATION := 0.09
const ATTACK_SHAKE_INTENSITY := 2.4
const ATTACK_SHAKE_DURATION := 0.12
const ATTACK_FLASH_COLOR := Color(1.0, 0.25, 0.16, 0.06)

signal health_changed(current: int, maximum: int)

@export_group("Stats")
@export_range(1, 500, 1) var max_hp: int = 50
var current_hp: int = 50
@export var attack_damage: int = 10

@export_group("Movement")
@export var patrol_speed: float = 55.0
@export var chase_speed: float = 130.0
@export var acceleration: float = 900.0
@export var deceleration: float = 1200.0
@export var patrol_range: float = 96.0
@export var patrol_pause_time: float = 0.8
@export var gravity_scale: float = 1.0

@export_group("Detection")
@export var detection_range: float = 180.0
@export var attack_range: float = 52.0

@export_group("Attack")
@export_range(0.1, 2.0, 0.05) var telegraph_time: float = 0.45
@export_range(0.05, 1.0, 0.01) var attack_active_time: float = 0.12
@export_range(0.0, 2.0, 0.05) var attack_recovery_time: float = 0.3
@export_range(0.0, 3.0, 0.05) var attack_cooldown_time: float = 0.9
@export var attack_height: float = 48.0
@export var attack_knockback_force: float = 320.0

@export_group("Damage Reaction")
@export var hurt_duration: float = 0.3
@export var hit_knockback_force: float = 280.0
@export var hit_knockback_lift: float = -140.0

@export_group("Drops")
@export var drop_table: ItemDropTable = DEFAULT_DROP_TABLE
@export var drop_spawn_offset: Vector2 = Vector2(0.0, -18.0)

@export_group("Spawn")
@export var snap_to_floor_on_spawn: bool = true
@export var floor_snap_max_distance: float = 192.0
@export var floor_snap_clearance: float = 1.0

@onready var visual: CanvasItem = get_node_or_null("ColorRect") as CanvasItem
@onready var telegraph: Label = get_node_or_null("Telegraph") as Label
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
@onready var body_collision: CollisionShape2D = (
	get_node_or_null("CollisionShape2D") as CollisionShape2D
)
@onready var detection_area: Area2D = get_node_or_null("DetectionArea") as Area2D
@onready var detection_collision: CollisionShape2D = (
	get_node_or_null("DetectionArea/CollisionShape2D") as CollisionShape2D
)
@onready var attack_area: Area2D = get_node_or_null("AttackArea") as Area2D
@onready var attack_collision: CollisionShape2D = (
	get_node_or_null("AttackArea/CollisionShape2D") as CollisionShape2D
)

var state: State = State.IDLE
var facing: float = 1.0
var player: Node2D = null

var _state_time: float = 0.0
var _attack_phase: AttackPhase = AttackPhase.NONE
var _attack_hit: bool = false
var _attack_cooldown_timer: float = 0.0
var _hurt_timer: float = 0.0
var _patrol_direction: float = 1.0
var _patrol_origin_x: float = 0.0
var _patrol_wait: float = 0.0
var _dead: bool = false
var _telegraph_visible: bool = false
var _telegraph_tween: Tween = null
var _hit_flash_timer: float = 0.0
var _visual_tween: Tween = null

var _initialized: bool = false
var _node_resolve_attempts: int = 0
var _pending_floor_snap: bool = false

const MAX_NODE_RESOLVE_ATTEMPTS := 60


func _ready() -> void:
	max_hp = maxi(max_hp, 1)
	current_hp = max_hp
	initialize_spawned_instance()


func initialize_spawned_instance() -> void:
	if _initialized or not is_inside_tree():
		return

	_resolve_node_references()

	if not health_changed.is_connected(_on_health_changed):
		health_changed.connect(_on_health_changed)

	_configure_body_collision()
	_configure_hurtbox()
	_configure_detection_area()
	_configure_attack_area()
	_enter_idle()
	_update_health_bar()
	_set_telegraph(false)
	_refresh_visual()

	_initialized = true
	_pending_floor_snap = snap_to_floor_on_spawn
	_ensure_nodes_ready()


func _resolve_node_references() -> void:
	visual = get_node_or_null("ColorRect") as CanvasItem
	telegraph = get_node_or_null("Telegraph") as Label
	health_bar = get_node_or_null("HealthBar") as ProgressBar
	hurtbox = get_node_or_null("Hurtbox") as Area2D
	body_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	detection_area = get_node_or_null("DetectionArea") as Area2D
	detection_collision = (
		get_node_or_null("DetectionArea/CollisionShape2D") as CollisionShape2D
	)
	attack_area = get_node_or_null("AttackArea") as Area2D
	attack_collision = (
		get_node_or_null("AttackArea/CollisionShape2D") as CollisionShape2D
	)


func _ensure_nodes_ready() -> void:
	if _dead:
		return

	_resolve_node_references()

	if is_instance_valid(hurtbox):
		_configure_hurtbox()
	if is_instance_valid(detection_area):
		_configure_detection_area()
	if is_instance_valid(attack_area):
		_configure_attack_area()
	if is_instance_valid(health_bar):
		_update_health_bar()
	if is_instance_valid(telegraph) and not _telegraph_visible:
		_set_telegraph(false)

	var all_ready := (
		is_instance_valid(hurtbox)
		and is_instance_valid(detection_area)
		and is_instance_valid(attack_area)
		and is_instance_valid(health_bar)
		and is_instance_valid(telegraph)
	)
	if all_ready:
		_node_resolve_attempts = 0
		return

	if _node_resolve_attempts >= MAX_NODE_RESOLVE_ATTEMPTS:
		return

	_node_resolve_attempts += 1
	call_deferred("_ensure_nodes_ready")


func _physics_process(delta: float) -> void:
	if _dead:
		return

	if _pending_floor_snap:
		_pending_floor_snap = false
		_snap_to_floor()

	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)
	_update_player_reference()
	_apply_gravity(delta)
	_state_time += delta

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
		if _hit_flash_timer <= 0.0:
			_refresh_visual()

	match state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HURT:
			_process_hurt(delta)

	move_and_slide()

	if state == State.ATTACK and _attack_phase == AttackPhase.ACTIVE:
		_try_hit_player()


func take_damage(
	amount: int,
	knockback_direction: float = 0.0,
	knockback_force: float = -1.0
) -> bool:
	if amount <= 0 or _dead:
		return false

	current_hp = clampi(current_hp - amount, 0, max_hp)
	health_changed.emit(current_hp, max_hp)

	var direction := signf(knockback_direction)
	if is_zero_approx(direction):
		direction = -facing

	_hit_flash_timer = HIT_FLASH_DURATION
	_play_hit_feedback(direction)

	if current_hp <= 0:
		_set_state(State.DEAD)
		return true

	var force := knockback_force if knockback_force >= 0.0 else hit_knockback_force

	if state == State.HURT:
		_hurt_timer = maxf(_hurt_timer, hurt_duration)
		_refresh_visual()
	else:
		_hurt_timer = hurt_duration
		_set_state(State.HURT)

	velocity.x = direction * force
	velocity.y = hit_knockback_lift
	return true


func stun_enemy(duration: float) -> void:
	if _dead or duration <= 0.0:
		return

	var stun_time := maxf(duration, hurt_duration)
	if state == State.HURT:
		_hurt_timer = maxf(_hurt_timer, stun_time)
		_refresh_visual()
		return

	_hurt_timer = stun_time
	_set_state(State.HURT)


func _process_idle(delta: float) -> void:
	if is_instance_valid(player):
		_set_state(State.CHASE)
		return

	if _patrol_wait > 0.0:
		_patrol_wait = maxf(_patrol_wait - delta, 0.0)
		_decelerate(delta)
		return

	var offset := global_position.x - _patrol_origin_x
	if (
		(_patrol_direction > 0.0 and offset >= patrol_range)
		or (_patrol_direction < 0.0 and offset <= -patrol_range)
		or is_on_wall()
	):
		_reverse_patrol()
		return

	_set_facing(_patrol_direction)
	velocity.x = move_toward(
		velocity.x,
		_patrol_direction * patrol_speed,
		acceleration * delta
	)


func _process_chase(delta: float) -> void:
	if not is_instance_valid(player):
		_set_state(State.IDLE)
		return

	var offset := player.global_position - global_position
	var direction := signf(offset.x)
	if is_zero_approx(direction):
		direction = facing
	_set_facing(direction)

	if offset.length() <= attack_range:
		_decelerate(delta)
		if is_on_floor() and _attack_cooldown_timer <= 0.0:
			_set_state(State.ATTACK)
		return

	velocity.x = move_toward(
		velocity.x,
		direction * chase_speed,
		acceleration * delta
	)


func _process_attack(delta: float) -> void:
	_decelerate(delta)

	var active_start := telegraph_time
	var active_end := active_start + attack_active_time
	var recovery_end := active_end + attack_recovery_time

	if _state_time < active_start:
		_set_telegraph(true)
		return

	if _state_time < active_end:
		if _attack_phase != AttackPhase.ACTIVE:
			_start_attack_strike()
		return

	if _state_time < recovery_end:
		if _attack_phase != AttackPhase.RECOVERY:
			_attack_phase = AttackPhase.RECOVERY
			_refresh_visual()
		return

	_attack_cooldown_timer = attack_cooldown_time
	_set_state(State.CHASE if is_instance_valid(player) else State.IDLE)


func _process_hurt(delta: float) -> void:
	_decelerate(delta)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	if _hurt_timer > 0.0:
		return
	_set_state(State.CHASE if is_instance_valid(player) else State.IDLE)


func _try_hit_player() -> void:
	if _attack_hit or not is_instance_valid(attack_area):
		return

	for body in attack_area.get_overlapping_bodies():
		var target := body as Node2D
		if target == null or not target.is_in_group("player"):
			continue
		if not target.has_method("take_damage"):
			continue

		_attack_hit = true
		var direction := facing
		var horizontal_offset := target.global_position.x - global_position.x
		if not is_zero_approx(horizontal_offset):
			direction = signf(horizontal_offset)

		var damaged := bool(target.call("take_damage", attack_damage, self))
		if damaged and target.has_method("apply_knockback"):
			target.call("apply_knockback", direction, attack_knockback_force)
		if damaged:
			_play_attack_impact(target, direction)
		return


func _set_state(next_state: State) -> void:
	if state == next_state:
		return

	_exit_state(state)
	state = next_state
	_state_time = 0.0
	_enter_state(state)
	_refresh_visual()


func _exit_state(previous_state: State) -> void:
	if previous_state == State.ATTACK:
		_attack_phase = AttackPhase.NONE
		_set_telegraph(false)


func _enter_state(next_state: State) -> void:
	match next_state:
		State.IDLE:
			_enter_idle()
		State.CHASE:
			_patrol_wait = 0.0
		State.ATTACK:
			_enter_attack()
		State.HURT:
			_set_telegraph(false)
		State.DEAD:
			_enter_dead()


func _enter_idle() -> void:
	_patrol_origin_x = global_position.x
	_patrol_wait = patrol_pause_time * 0.5
	_set_facing(_patrol_direction)


func _enter_attack() -> void:
	_attack_phase = AttackPhase.WINDUP
	_attack_hit = false
	velocity.x = 0.0

	if is_instance_valid(player):
		var direction := signf(player.global_position.x - global_position.x)
		if not is_zero_approx(direction):
			_set_facing(direction)

	_set_telegraph(true)


func _start_attack_strike() -> void:
	_attack_phase = AttackPhase.ACTIVE
	_attack_hit = false
	_set_telegraph(false)
	_refresh_visual()
	_play_scale_punch(ATTACK_LUNGE_SCALE)
	_spawn_attack_swing()


func _enter_dead() -> void:
	_dead = true
	_attack_phase = AttackPhase.NONE
	_set_telegraph(false)
	_update_health_bar()
	velocity = Vector2.ZERO
	if is_instance_valid(body_collision):
		body_collision.set_deferred("disabled", true)
	if is_instance_valid(hurtbox):
		hurtbox.set_deferred("monitorable", false)
	if is_instance_valid(attack_area):
		attack_area.set_deferred("monitoring", false)
	if is_instance_valid(detection_area):
		detection_area.set_deferred("monitoring", false)
	EventBus.enemy_killed.emit(self, global_position)
	_spawn_drops.call_deferred()
	_play_death_effect()


func _reverse_patrol() -> void:
	_patrol_direction *= -1.0
	_patrol_wait = patrol_pause_time
	_set_facing(_patrol_direction)


func _set_telegraph(show_telegraph: bool) -> void:
	if not is_instance_valid(telegraph):
		return

	if show_telegraph:
		if _telegraph_visible and telegraph.visible:
			return
	elif not _telegraph_visible and not telegraph.visible:
		return

	_telegraph_visible = show_telegraph
	if _telegraph_tween != null and _telegraph_tween.is_valid():
		_telegraph_tween.kill()
		_telegraph_tween = null

	if not show_telegraph:
		telegraph.visible = false
		telegraph.scale = Vector2.ONE
		telegraph.modulate.a = 1.0
		return

	telegraph.visible = true
	telegraph.pivot_offset = telegraph.size * 0.5
	telegraph.scale = Vector2(0.6, 0.6)
	telegraph.modulate.a = 0.0
	_telegraph_tween = create_tween()
	_telegraph_tween.set_parallel(true)
	_telegraph_tween.tween_property(telegraph, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_telegraph_tween.tween_property(telegraph, "modulate:a", 1.0, 0.1)


func _on_health_changed(_current: int, _maximum: int) -> void:
	_update_health_bar()


func _update_health_bar() -> void:
	if not is_instance_valid(health_bar):
		return

	var maximum := maxi(max_hp, 1)
	health_bar.show_percentage = false
	health_bar.max_value = float(maximum)
	health_bar.value = clampf(float(current_hp), 0.0, float(maximum))
	health_bar.visible = not _dead and current_hp > 0


func _refresh_visual() -> void:
	if not is_instance_valid(visual):
		return

	if _hit_flash_timer > 0.0:
		visual.modulate = HIT_FLASH_COLOR
		return

	match state:
		State.HURT:
			visual.modulate = HURT_COLOR
		State.ATTACK:
			match _attack_phase:
				AttackPhase.WINDUP:
					visual.modulate = WARNING_COLOR
				AttackPhase.ACTIVE:
					visual.modulate = STRIKE_COLOR
				_:
					visual.modulate = Color.WHITE
		_:
			visual.modulate = Color.WHITE


func _play_hit_feedback(direction: float) -> void:
	_refresh_visual()
	_play_scale_punch(HIT_SQUASH_SCALE)
	if not is_inside_tree():
		return
	JuiceFX.spawn_hit_spark(
		global_position + Vector2(0.0, -12.0),
		HIT_SPARK_COLOR,
		direction,
		0.7
	)
	JuiceFX.shake_camera(HIT_SHAKE_INTENSITY, HIT_SHAKE_DURATION)


func _play_attack_impact(target: Node2D, direction: float) -> void:
	var impact_position := global_position + Vector2(facing * attack_range * 0.5, -8.0)
	if is_instance_valid(target):
		impact_position = target.global_position + Vector2(0.0, -8.0)
	JuiceFX.spawn_hit_spark(impact_position, PLAYER_HIT_SPARK_COLOR, direction, 0.9)
	JuiceFX.shake_camera(ATTACK_SHAKE_INTENSITY, ATTACK_SHAKE_DURATION)
	JuiceFX.flash_screen(ATTACK_FLASH_COLOR, 0.12)
	_play_scale_punch(IMPACT_SQUASH_SCALE)


func _play_scale_punch(target_scale: Vector2) -> void:
	var control := visual as Control
	if control == null:
		return
	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	control.pivot_offset = control.size * 0.5
	control.scale = target_scale
	_visual_tween = create_tween()
	_visual_tween.tween_property(control, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _spawn_attack_swing() -> void:
	if not is_inside_tree():
		return
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return

	var swing := Line2D.new()
	swing.name = "EnemyAttackSwing"
	swing.width = 4.0
	swing.default_color = SWING_COLOR
	swing.z_index = 5
	var points := PackedVector2Array()
	var arc_radius := maxf(attack_range * 0.85, 16.0)
	for index in range(9):
		var angle := lerpf(-0.9, 0.9, float(index) / 8.0)
		points.append(Vector2(cos(angle), sin(angle)) * arc_radius)
	swing.points = points
	parent.add_child(swing)
	swing.global_position = global_position + Vector2(facing * attack_range * 0.45, -8.0)
	swing.scale = Vector2(facing, 1.0)

	var tween := swing.create_tween()
	tween.set_parallel(true)
	tween.tween_property(swing, "scale", Vector2(facing * 1.35, 1.25), 0.14)
	tween.tween_property(swing, "modulate:a", 0.0, 0.16)
	tween.finished.connect(swing.queue_free)


func _update_player_reference() -> void:
	if not is_instance_valid(detection_area):
		player = null
		return

	var found: Node2D = null
	for body in detection_area.get_overlapping_bodies():
		var candidate := body as Node2D
		if candidate != null and candidate.is_in_group("player"):
			found = candidate
			break
	player = found


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return

	var default_gravity := float(
		ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	)
	velocity.y += default_gravity * gravity_scale * delta


func _decelerate(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)


func _set_facing(direction: float) -> void:
	if is_zero_approx(direction):
		return

	facing = signf(direction)
	_update_attack_area_position()


func _update_attack_area_position() -> void:
	if is_instance_valid(attack_area):
		attack_area.position.x = facing * attack_range * 0.5


func _configure_body_collision() -> void:
	collision_layer = ENEMY_BODY_LAYER
	collision_mask = BODY_COLLISION_MASK


func _snap_to_floor() -> void:
	if not snap_to_floor_on_spawn or not is_inside_tree() or is_queued_for_deletion():
		return

	var space := get_world_2d().direct_space_state
	if space == null:
		return

	var max_distance := maxf(floor_snap_max_distance, 1.0)
	var exclude: Array[RID] = [get_rid()]
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node is CollisionObject2D:
		exclude.append((player_node as CollisionObject2D).get_rid())

	var body_bottom := _get_body_bottom_offset()
	var body_height := _get_body_height()
	var floor_y := NAN
	var down_query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2.DOWN * max_distance,
		WORLD_LAYER,
		exclude
	)
	down_query.collide_with_areas = false
	down_query.collide_with_bodies = true
	var down_hit := space.intersect_ray(down_query)
	if not down_hit.is_empty():
		var down_normal: Vector2 = down_hit.get("normal", Vector2.ZERO)
		if down_normal.y < -0.5:
			var down_position: Vector2 = down_hit.get("position", global_position)
			floor_y = down_position.y

	if is_nan(floor_y):
		var up_start := global_position + Vector2.UP * max_distance
		var up_query := PhysicsRayQueryParameters2D.create(
			up_start,
			global_position + Vector2.DOWN * max_distance,
			WORLD_LAYER,
			exclude
		)
		up_query.collide_with_areas = false
		up_query.collide_with_bodies = true
		var up_hit := space.intersect_ray(up_query)
		if up_hit.is_empty():
			return
		var up_normal: Vector2 = up_hit.get("normal", Vector2.ZERO)
		if up_normal.y >= -0.5:
			return
		var up_position: Vector2 = up_hit.get("position", global_position)
		floor_y = up_position.y

	for _attempt in range(4):
		var candidate_y := floor_y - body_bottom - floor_snap_clearance
		if not _overlaps_world_at(candidate_y, space, exclude):
			break
		var overhead_query := PhysicsRayQueryParameters2D.create(
			Vector2(global_position.x, candidate_y - body_height - 8.0),
			Vector2(global_position.x, candidate_y + 8.0),
			WORLD_LAYER,
			exclude
		)
		overhead_query.collide_with_areas = false
		overhead_query.collide_with_bodies = true
		var overhead_hit := space.intersect_ray(overhead_query)
		if overhead_hit.is_empty():
			break
		var overhead_normal: Vector2 = overhead_hit.get("normal", Vector2.ZERO)
		if overhead_normal.y >= -0.5:
			break
		var overhead_position: Vector2 = overhead_hit.get("position", global_position)
		if is_equal_approx(overhead_position.y, floor_y):
			break
		floor_y = overhead_position.y

	_place_on_floor(floor_y, body_bottom)


func _place_on_floor(floor_y: float, body_bottom: float) -> void:
	global_position.y = floor_y - body_bottom - floor_snap_clearance
	velocity = Vector2.ZERO


func _overlaps_world_at(
	candidate_y: float,
	space: PhysicsDirectSpaceState2D,
	exclude: Array[RID]
) -> bool:
	if not is_instance_valid(body_collision) or body_collision.shape == null:
		return false

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body_collision.shape
	var shape_transform := body_collision.global_transform
	shape_transform.origin.y += candidate_y - global_position.y
	query.transform = shape_transform
	query.collision_mask = WORLD_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclude
	return not space.intersect_shape(query, 8).is_empty()


func _get_body_bottom_offset() -> float:
	if is_instance_valid(body_collision) and body_collision.shape != null:
		var shape_rect := body_collision.shape.get_rect()
		return (body_collision.position.y + shape_rect.end.y) * absf(global_scale.y)
	return 32.0


func _get_body_height() -> float:
	if is_instance_valid(body_collision) and body_collision.shape != null:
		return body_collision.shape.get_rect().size.y * absf(global_scale.y)
	return 64.0


func _configure_hurtbox() -> void:
	if not is_instance_valid(hurtbox):
		return

	hurtbox.collision_layer = HURTBOX_LAYER
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.monitorable = true


func _configure_detection_area() -> void:
	if not is_instance_valid(detection_area):
		return

	detection_area.collision_layer = 0
	detection_area.collision_mask = PLAYER_BODY_LAYER
	detection_area.monitoring = true
	detection_area.monitorable = false

	if not is_instance_valid(detection_collision):
		return

	var shape := detection_collision.shape
	if shape is CircleShape2D:
		var circle := (shape as CircleShape2D).duplicate() as CircleShape2D
		circle.radius = maxf(detection_range, 1.0)
		detection_collision.shape = circle


func _configure_attack_area() -> void:
	if not is_instance_valid(attack_area):
		return

	attack_area.collision_layer = 0
	attack_area.collision_mask = PLAYER_BODY_LAYER
	attack_area.monitoring = true
	attack_area.monitorable = false

	if not is_instance_valid(attack_collision):
		_update_attack_area_position()
		return

	var shape := attack_collision.shape
	if shape is RectangleShape2D:
		var rectangle := (shape as RectangleShape2D).duplicate() as RectangleShape2D
		rectangle.size = Vector2(maxf(attack_range, 1.0), maxf(attack_height, 1.0))
		attack_collision.shape = rectangle

	_update_attack_area_position()


func _spawn_drops() -> void:
	if drop_table == null:
		return

	var parent := get_parent()
	if parent == null or parent.is_queued_for_deletion():
		return

	ItemDropSpawner.spawn_table(drop_table, parent, global_position + drop_spawn_offset)


func _play_death_effect() -> void:
	JuiceFX.spawn_hit_spark(
		global_position + Vector2(0.0, -12.0),
		HIT_SPARK_COLOR,
		0.0,
		1.1
	)
	JuiceFX.shake_camera(HIT_SHAKE_INTENSITY * 1.4, HIT_SHAKE_DURATION * 1.5)
	if not is_instance_valid(visual):
		queue_free()
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "modulate:a", 0.0, 0.35)
	tween.tween_property(self, "scale", Vector2(1.15, 0.2), 0.35)
	tween.finished.connect(queue_free)
