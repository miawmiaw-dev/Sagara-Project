class_name EliteRevenant
extends CharacterBody2D

enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	HURT,
	DEAD,
}

enum AttackMode {
	NONE,
	SLASH,
	HEX_BOLT,
	DASH,
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
const HEX_ACTIVE_TIME := 0.06
const DEFAULT_HEX_BOLT_SCENE := preload("res://scenes/enemies/hex_bolt.tscn")
const DEFAULT_DROP_TABLE := preload("res://resources/items/elite_revenant_drops.tres")

const HIT_FLASH_COLOR := Color(3.0, 2.5, 3.0, 1.0)
const HURT_COLOR := Color(1.0, 0.25, 0.25, 1.0)
const SLASH_WARNING_COLOR := Color(1.0, 0.55, 0.18, 1.0)
const SLASH_STRIKE_COLOR := Color(1.0, 0.92, 0.6, 1.0)
const HEX_WARNING_COLOR := Color(0.82, 0.35, 1.0, 1.0)
const HEX_STRIKE_COLOR := Color(0.8, 0.78, 1.0, 1.0)
const DASH_WARNING_COLOR := Color(0.55, 0.9, 1.0, 1.0)
const DASH_STRIKE_COLOR := Color(0.8, 0.98, 1.0, 1.0)
const HIT_FLASH_DURATION := 0.12
const HIT_SQUASH_SCALE := Vector2(1.35, 0.75)
const ATTACK_LUNGE_SCALE := Vector2(1.2, 0.84)
const CAST_PUNCH_SCALE := Vector2(0.88, 1.14)
const IMPACT_SQUASH_SCALE := Vector2(1.3, 0.8)
const HIT_SPARK_COLOR := Color(1.0, 0.8, 0.5, 1.0)
const PLAYER_HIT_SPARK_COLOR := Color(1.0, 0.35, 0.6, 1.0)
const SWING_COLOR := Color(1.0, 0.72, 0.32, 1.0)
const HEX_COLOR := Color(0.78, 0.35, 1.0, 1.0)
const HIT_SHAKE_INTENSITY := 1.9
const HIT_SHAKE_DURATION := 0.09
const ATTACK_SHAKE_INTENSITY := 2.8
const ATTACK_SHAKE_DURATION := 0.12
const ATTACK_FLASH_COLOR := Color(0.82, 0.22, 0.4, 0.055)

signal health_changed(current: int, maximum: int)

@export_group("Stats")
@export_range(1, 5000, 1) var max_hp: int = 150
var current_hp: int = 150
@export_range(1, 200, 1) var slash_damage: int = 16
@export_range(1, 200, 1) var hex_damage: int = 12

@export_group("Movement")
@export var patrol_speed: float = 48.0
@export var chase_speed: float = 142.0
@export var retreat_speed: float = 92.0
@export var acceleration: float = 900.0
@export var deceleration: float = 1250.0
@export var patrol_range: float = 120.0
@export var patrol_pause_time: float = 1.0
@export var idle_duration: float = 0.6
@export var gravity_scale: float = 1.0

@export_group("Detection")
@export var detection_range: float = 280.0
@export var lose_interest_time: float = 1.2
@export var attack_range: float = 74.0
@export var attack_height: float = 66.0

@export_group("Slash Attack")
@export_range(0.1, 3.0, 0.05) var slash_telegraph_time: float = 0.55
@export_range(0.05, 1.0, 0.01) var slash_active_time: float = 0.14
@export_range(0.0, 2.0, 0.05) var slash_recovery_time: float = 0.38
@export_range(0.1, 10.0, 0.05) var slash_cooldown_time: float = 1.5
@export_range(0.0, 1000.0, 1.0) var slash_knockback_force: float = 280.0

@export_group("Hex Bolt")
@export var hex_bolt_scene: PackedScene = DEFAULT_HEX_BOLT_SCENE
@export_range(0.1, 3.0, 0.05) var hex_telegraph_time: float = 0.7
@export_range(0.0, 2.0, 0.05) var hex_recovery_time: float = 0.5
@export_range(0.1, 10.0, 0.05) var hex_cooldown_time: float = 3.2
@export_range(0.0, 1200.0, 1.0) var hex_min_range: float = 110.0
@export_range(60.0, 2000.0, 1.0) var hex_max_range: float = 360.0
@export_range(1.0, 1500.0, 1.0) var hex_speed: float = 260.0
@export_range(0.0, 1000.0, 1.0) var hex_knockback_force: float = 240.0
@export var hex_spawn_offset: Vector2 = Vector2(30.0, -18.0)
@export_range(0.0, 1.0, 0.01) var attack_interval: float = 0.25

@export_group("Phantom Rush")
@export var dash_min_range: float = 90.0
@export var dash_max_range: float = 240.0
@export_range(100.0, 1200.0, 1.0) var dash_speed: float = 480.0
@export_range(0.1, 3.0, 0.05) var dash_telegraph_time: float = 0.35
@export_range(0.05, 1.0, 0.01) var dash_active_time: float = 0.45
@export_range(0.0, 2.0, 0.05) var dash_recovery_time: float = 0.35
@export_range(0.1, 10.0, 0.05) var dash_cooldown_time: float = 3.0
@export_range(1, 200, 1) var dash_damage: int = 18
@export_range(0.0, 1000.0, 1.0) var dash_knockback_force: float = 320.0

@export_group("Enrage")
@export_range(0.05, 1.0, 0.01) var enrage_health_ratio: float = 0.5
@export_range(1.0, 2.0, 0.01) var enrage_speed_multiplier: float = 1.18
@export_range(0.5, 1.0, 0.01) var enrage_cooldown_multiplier: float = 0.78
@export_range(0.5, 1.0, 0.01) var enrage_telegraph_multiplier: float = 0.85

@export_group("Damage Reaction")
@export var hurt_duration: float = 0.28
@export var hit_knockback_force: float = 250.0
@export var hit_knockback_lift: float = -130.0

@export_group("Drops")
@export var drop_table: ItemDropTable = DEFAULT_DROP_TABLE
@export var drop_spawn_offset: Vector2 = Vector2(0.0, -18.0)

@export_group("Boss Encounter")
@export var boss_id: String = ""
@export var boss_display_name: String = "Murka Leluhur"

@export_group("Spawn")
@export var snap_to_floor_on_spawn: bool = true
@export var floor_snap_max_distance: float = 192.0
@export var floor_snap_clearance: float = 1.0

@onready var visual: CanvasItem = get_node_or_null("Visual") as CanvasItem
@onready var telegraph: Label = get_node_or_null("Telegraph") as Label
@onready var attack_label: Label = get_node_or_null("AttackLabel") as Label
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
@onready var cast_point: Marker2D = get_node_or_null("CastPoint") as Marker2D

var state: State = State.IDLE
var facing: float = 1.0
var player: Node2D = null

var _state_time: float = 0.0
var _attack_mode: AttackMode = AttackMode.NONE
var _attack_phase: AttackPhase = AttackPhase.NONE
var _attack_hit: bool = false
var _hex_fired: bool = false
var _slash_cooldown_timer: float = 0.0
var _hex_cooldown_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _last_attack_mode: AttackMode = AttackMode.NONE
var _rng := RandomNumberGenerator.new()
var _hurt_timer: float = 0.0
var _lost_sight_timer: float = 0.0
var _patrol_direction: float = 1.0
var _patrol_origin_x: float = 0.0
var _patrol_wait: float = 0.0
var _dead: bool = false
var _enraged: bool = false
var _telegraph_visible: bool = false
var _telegraph_tween: Tween = null
var _telegraph_visual: Line2D = null
var _hit_flash_timer: float = 0.0
var _visual_tween: Tween = null
var _pending_floor_snap: bool = false
var _fight_active: bool = false
var _fight_serial: int = -1
var _arena_enabled: bool = false
var _arena_left_x: float = 0.0
var _arena_right_x: float = 0.0
var _home_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_rng.randomize()
	max_hp = maxi(max_hp, 1)
	current_hp = max_hp
	health_changed.connect(_on_health_changed)
	_configure_body_collision()
	_configure_areas()
	_patrol_origin_x = global_position.x
	_home_position = global_position
	_enter_idle()
	_update_health_bar()
	_set_telegraph(false)
	_set_attack_label("")
	_refresh_visual()
	_play_aura_pulse()
	_pending_floor_snap = snap_to_floor_on_spawn

	if _is_boss_mode():
		if not is_in_group("boss"):
			add_to_group("boss")
		if not EventBus.player_respawned.is_connected(_on_player_respawned):
			EventBus.player_respawned.connect(_on_player_respawned)
		set_dormant()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _is_boss_mode() and not _fight_active:
		return

	if _pending_floor_snap:
		_pending_floor_snap = false
		_snap_to_floor()

	_tick_timers(delta)
	_apply_gravity(delta)
	_state_time += delta

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
		if _hit_flash_timer <= 0.0:
			_refresh_visual()

	_update_player_reference(delta)

	match state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HURT:
			_process_hurt(delta)

	move_and_slide()
	_enforce_arena_bounds()

	if (
		state == State.ATTACK
		and _attack_phase == AttackPhase.ACTIVE
		and (_attack_mode == AttackMode.SLASH or _attack_mode == AttackMode.DASH)
	):
		_try_hit_player()


func take_damage(
	amount: int,
	knockback_direction: float = 0.0,
	knockback_force: float = -1.0
) -> bool:
	if amount <= 0 or _dead:
		return false
	if _is_boss_mode() and not _fight_active:
		return false

	current_hp = clampi(current_hp - amount, 0, max_hp)
	health_changed.emit(current_hp, max_hp)
	if _is_boss_mode():
		EventBus.boss_health_changed.emit(current_hp, max_hp)

	var direction := signf(knockback_direction)
	if is_zero_approx(direction):
		direction = -facing

	_hit_flash_timer = HIT_FLASH_DURATION
	_play_hit_feedback(direction)

	if current_hp <= 0:
		_set_state(State.DEAD)
		return true

	_activate_enrage_if_needed()

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


func configure_arena(left_x: float, right_x: float) -> void:
	if not _is_boss_mode():
		return
	if is_nan(left_x) or is_nan(right_x) or left_x >= right_x:
		return
	_arena_enabled = true
	_arena_left_x = left_x
	_arena_right_x = right_x


func set_boss_id(new_boss_id: String) -> void:
	var trimmed := new_boss_id.strip_edges()
	if trimmed.is_empty():
		return
	boss_id = trimmed


func set_home_position(new_position: Vector2) -> void:
	if _dead or not is_inside_tree():
		return
	_home_position = new_position
	_patrol_origin_x = new_position.x
	global_position = new_position
	velocity = Vector2.ZERO


func activate_fight(target: Node2D = null) -> bool:
	if not _is_boss_mode() or _dead or _fight_active:
		return false
	if not GameState.begin_boss_fight(boss_id):
		return false
	_fight_serial = GameState.get_active_boss_serial(boss_id)

	if is_instance_valid(target) and target.is_in_group("player"):
		player = target
	else:
		player = _find_player()

	_fight_active = true
	_dead = false
	_enraged = false
	_attack_mode = AttackMode.NONE
	_attack_phase = AttackPhase.NONE
	_attack_hit = false
	_hex_fired = false
	_attack_cooldown_timer = 0.0
	_slash_cooldown_timer = 0.0
	_hex_cooldown_timer = 0.0
	_dash_cooldown_timer = 0.0
	_last_attack_mode = AttackMode.NONE
	_hurt_timer = 0.0
	_hit_flash_timer = 0.0
	_lost_sight_timer = 0.0
	_state_time = 0.0
	current_hp = max_hp
	velocity = Vector2.ZERO
	global_position = _home_position
	_patrol_origin_x = _home_position.x
	visible = true
	modulate.a = 1.0
	if is_instance_valid(visual):
		visual.visible = true
		visual.modulate.a = 1.0
	if is_instance_valid(body_collision):
		body_collision.set_deferred("disabled", false)
	if is_instance_valid(hurtbox):
		hurtbox.set_deferred("monitorable", true)
	if is_instance_valid(detection_area):
		detection_area.set_deferred("monitoring", true)
	if is_instance_valid(attack_area):
		attack_area.set_deferred("monitoring", true)
	_update_health_bar()
	_set_state(State.CHASE if _has_target() else State.IDLE)
	EventBus.boss_fight_started.emit(boss_display_name, max_hp)
	EventBus.boss_health_changed.emit(current_hp, max_hp)
	EventBus.notification_requested.emit("%s terbangun!" % boss_display_name)
	JuiceFX.magic_burst(global_position + Vector2(0.0, -18.0), HEX_COLOR, 1.1)
	return true


func is_fight_active() -> bool:
	return _fight_active and not _dead


func set_dormant() -> void:
	if not _is_boss_mode() or _dead:
		return

	_fight_active = false
	_fight_serial = -1
	_enraged = false
	player = null
	_attack_mode = AttackMode.NONE
	_attack_phase = AttackPhase.NONE
	_attack_hit = false
	_hex_fired = false
	_attack_cooldown_timer = 0.0
	_slash_cooldown_timer = 0.0
	_hex_cooldown_timer = 0.0
	_dash_cooldown_timer = 0.0
	_last_attack_mode = AttackMode.NONE
	_hurt_timer = 0.0
	_hit_flash_timer = 0.0
	_lost_sight_timer = 0.0
	_state_time = 0.0
	current_hp = max_hp
	velocity = Vector2.ZERO
	global_position = _home_position
	_patrol_origin_x = _home_position.x
	_set_telegraph(false)
	_set_attack_label("")
	_clear_telegraph_visual()
	if is_instance_valid(body_collision):
		body_collision.set_deferred("disabled", true)
	if is_instance_valid(hurtbox):
		hurtbox.set_deferred("monitorable", false)
	if is_instance_valid(detection_area):
		detection_area.set_deferred("monitoring", false)
	if is_instance_valid(attack_area):
		attack_area.set_deferred("monitoring", false)
	visible = false
	_update_health_bar()
	if state != State.IDLE:
		_set_state(State.IDLE)


func _is_boss_mode() -> bool:
	return not boss_id.strip_edges().is_empty()


func _find_player() -> Node2D:
	if not is_inside_tree():
		return null
	var node := get_tree().get_first_node_in_group("player")
	if node is Node2D:
		return node as Node2D
	return null


func _on_player_respawned(_at_position: Vector2) -> void:
	if not _is_boss_mode() or not _fight_active or _dead:
		return

	GameState.finish_boss_fight(boss_id, false, _fight_serial)
	_fight_serial = -1
	EventBus.boss_fight_ended.emit(boss_display_name, false)
	set_dormant()


func _process_idle(delta: float) -> void:
	_decelerate(delta)

	if _has_target():
		_set_state(State.CHASE)
		return

	if _state_time >= idle_duration:
		_set_state(State.PATROL)


func _process_patrol(delta: float) -> void:
	if _has_target():
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
	if not _has_target():
		_set_state(State.IDLE)
		return

	var offset := player.global_position - global_position
	var distance := offset.length()
	var direction := signf(offset.x)
	if is_zero_approx(direction):
		direction = facing
	_set_facing(direction)

	if _attack_cooldown_timer <= 0.0 and _can_see_player():
		if _choose_attack(distance):
			return

	if distance <= attack_range * 0.55 and _slash_cooldown_timer > 0.0:
		velocity.x = move_toward(
			velocity.x,
			-direction * retreat_speed,
			acceleration * delta
		)
		return

	if distance <= attack_range * 0.9:
		_decelerate(delta)
		return

	velocity.x = move_toward(
		velocity.x,
		direction * _get_chase_speed(),
		acceleration * delta
	)


func _process_attack(delta: float) -> void:
	_decelerate(delta)

	var telegraph_time := _get_telegraph_duration()
	var active_time := slash_active_time
	var recovery_time := slash_recovery_time
	if _attack_mode == AttackMode.HEX_BOLT:
		active_time = HEX_ACTIVE_TIME
		recovery_time = hex_recovery_time
	elif _attack_mode == AttackMode.DASH:
		active_time = dash_active_time
		recovery_time = dash_recovery_time

	var active_end := telegraph_time + active_time
	var recovery_end := active_end + recovery_time

	if _state_time < telegraph_time:
		_attack_phase = AttackPhase.WINDUP
		if _attack_mode == AttackMode.HEX_BOLT:
			_update_hex_aim_line()
		return

	if _state_time < active_end:
		if _attack_phase != AttackPhase.ACTIVE:
			_start_attack_strike()
		if _attack_mode == AttackMode.DASH:
			var multiplier := enrage_speed_multiplier if _enraged else 1.0
			velocity.x = facing * dash_speed * multiplier
		return

	if _state_time < recovery_end:
		if _attack_phase != AttackPhase.RECOVERY:
			_attack_phase = AttackPhase.RECOVERY
			_refresh_visual()
		return

	_finish_attack()


func _process_hurt(delta: float) -> void:
	_decelerate(delta)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	if _hurt_timer > 0.0:
		return
	_set_state(State.CHASE if _has_target() else State.IDLE)


func _choose_attack(distance: float) -> bool:
	if not _has_target():
		return false

	var vertical_offset := absf(player.global_position.y - global_position.y)
	var options: Array[AttackMode] = []
	var weights: Array[float] = []

	if (
		_slash_cooldown_timer <= 0.0
		and distance <= attack_range
		and vertical_offset <= attack_height
	):
		options.append(AttackMode.SLASH)
		weights.append(1.4)
	if (
		_dash_cooldown_timer <= 0.0
		and distance >= dash_min_range
		and distance <= dash_max_range
		and vertical_offset <= attack_height
	):
		options.append(AttackMode.DASH)
		weights.append(1.6 if _enraged else 1.25)
	if (
		_hex_cooldown_timer <= 0.0
		and distance <= hex_max_range
		and (distance >= hex_min_range or vertical_offset > attack_height * 0.6)
	):
		options.append(AttackMode.HEX_BOLT)
		weights.append(1.0)

	if options.is_empty():
		return false

	var chosen := _pick_weighted_attack(options, weights)
	if options.size() > 1 and chosen == _last_attack_mode:
		var filtered_options: Array[AttackMode] = []
		var filtered_weights: Array[float] = []
		for index in range(options.size()):
			if options[index] == _last_attack_mode:
				continue
			filtered_options.append(options[index])
			filtered_weights.append(weights[index])
		if not filtered_options.is_empty():
			chosen = _pick_weighted_attack(filtered_options, filtered_weights)

	_last_attack_mode = chosen
	_begin_attack(chosen)
	return true


func _pick_weighted_attack(options: Array[AttackMode], weights: Array[float]) -> AttackMode:
	var total := 0.0
	for weight in weights:
		total += maxf(weight, 0.0)
	if total <= 0.0:
		return options[0]

	var roll := _rng.randf_range(0.0, total)
	for index in range(options.size()):
		roll -= maxf(weights[index], 0.0)
		if roll <= 0.0:
			return options[index]
	return options[options.size() - 1]


func _begin_attack(mode: AttackMode) -> void:
	_attack_mode = mode
	_set_state(State.ATTACK)


func _enter_attack() -> void:
	_attack_phase = AttackPhase.WINDUP
	_attack_hit = false
	_hex_fired = false
	velocity.x = 0.0
	_face_player()
	_clear_telegraph_visual()

	if _attack_mode == AttackMode.SLASH:
		_set_telegraph(true, "!", SLASH_WARNING_COLOR)
		_set_attack_label("TEBASAN BAYANGAN", SLASH_WARNING_COLOR)
		_spawn_slash_preview()
	elif _attack_mode == AttackMode.DASH:
		_set_telegraph(true, "»", DASH_WARNING_COLOR)
		_set_attack_label("SERBUAN BAYANGAN", DASH_WARNING_COLOR)
		_spawn_dash_preview()
	else:
		_set_telegraph(true, "✦", HEX_WARNING_COLOR)
		_set_attack_label("HEX LELUHUR", HEX_WARNING_COLOR)
		_spawn_hex_aim_line()

	_refresh_visual()


func _start_attack_strike() -> void:
	_attack_phase = AttackPhase.ACTIVE
	_set_telegraph(false)
	_clear_telegraph_visual()

	if _attack_mode == AttackMode.SLASH:
		_play_scale_punch(ATTACK_LUNGE_SCALE)
		_spawn_attack_swing()
	elif _attack_mode == AttackMode.DASH:
		_play_scale_punch(ATTACK_LUNGE_SCALE)
		_spawn_dash_streak()
	else:
		_hex_fired = true
		_play_scale_punch(CAST_PUNCH_SCALE)
		_spawn_hex_bolt()

	_refresh_visual()


func _finish_attack() -> void:
	match _attack_mode:
		AttackMode.SLASH:
			_slash_cooldown_timer = slash_cooldown_time * _get_cooldown_multiplier()
		AttackMode.HEX_BOLT:
			_hex_cooldown_timer = hex_cooldown_time * _get_cooldown_multiplier()
		AttackMode.DASH:
			_dash_cooldown_timer = dash_cooldown_time * _get_cooldown_multiplier()

	_attack_cooldown_timer = attack_interval * _get_cooldown_multiplier()
	var next_state := State.CHASE if _has_target() else State.IDLE
	_set_state(next_state)


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
		_attack_mode = AttackMode.NONE
		_set_telegraph(false)
		_set_attack_label("")
		_clear_telegraph_visual()


func _enter_state(next_state: State) -> void:
	match next_state:
		State.IDLE:
			_enter_idle()
		State.PATROL:
			_patrol_wait = 0.0
		State.ATTACK:
			_enter_attack()
		State.HURT:
			_set_telegraph(false)
			_set_attack_label("")
			_clear_telegraph_visual()
		State.DEAD:
			_enter_dead()


func _enter_idle() -> void:
	_patrol_origin_x = global_position.x
	_patrol_wait = 0.0
	_set_facing(_patrol_direction)


func _reverse_patrol() -> void:
	_patrol_direction *= -1.0
	_patrol_wait = patrol_pause_time
	_set_facing(_patrol_direction)


func _face_player() -> void:
	if not is_instance_valid(player):
		return
	var direction := signf(player.global_position.x - global_position.x)
	if not is_zero_approx(direction):
		_set_facing(direction)


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

		var damage := slash_damage
		var knockback := slash_knockback_force
		if _attack_mode == AttackMode.DASH:
			damage = dash_damage
			knockback = dash_knockback_force
		var damaged := bool(target.call("take_damage", damage, self))
		if damaged and target.has_method("apply_knockback"):
			target.call("apply_knockback", direction, knockback)
		if damaged:
			_play_attack_impact(target, direction)
		return


func _spawn_hex_bolt() -> void:
	if hex_bolt_scene == null:
		return

	var parent := _resolve_attack_parent()
	if parent == null:
		return

	var bolt := hex_bolt_scene.instantiate()
	if bolt == null:
		return

	parent.add_child(bolt)
	if not is_instance_valid(bolt) or not bolt is Node2D:
		if is_instance_valid(bolt):
			bolt.queue_free()
		return

	var spawn_position := global_position + hex_spawn_offset
	if is_instance_valid(cast_point):
		spawn_position = cast_point.global_position
	var bolt_node := bolt as Node2D
	bolt_node.global_position = spawn_position

	if "knockback_force" in bolt:
		bolt.set("knockback_force", hex_knockback_force)

	if not bolt.has_method("launch_toward"):
		bolt.queue_free()
		return

	var launched := bool(
		bolt.call("launch_toward", _get_aim_position(), hex_damage, hex_speed, self)
	)
	if not launched:
		bolt.queue_free()
		return

	JuiceFX.magic_burst(spawn_position, HEX_COLOR, 0.65)


func _spawn_attack_swing() -> void:
	if not is_inside_tree():
		return
	var parent := _resolve_attack_parent()
	if parent == null:
		return

	var swing := Line2D.new()
	swing.name = "EliteSlashSwing"
	swing.width = 5.0
	swing.default_color = SWING_COLOR
	swing.z_index = 6
	var points := PackedVector2Array()
	var arc_radius := maxf(attack_range * 0.9, 20.0)
	for index in range(11):
		var angle := lerpf(-0.9, 0.9, float(index) / 10.0)
		points.append(Vector2(cos(angle), sin(angle)) * arc_radius)
	swing.points = points
	parent.add_child(swing)
	swing.global_position = global_position + Vector2(facing * attack_range * 0.4, -6.0)
	swing.scale = Vector2(facing, 1.0)

	var tween := swing.create_tween()
	tween.set_parallel(true)
	tween.tween_property(swing, "scale", Vector2(facing * 1.35, 1.25), 0.16)
	tween.tween_property(swing, "modulate:a", 0.0, 0.18)
	tween.finished.connect(swing.queue_free)


func _spawn_slash_preview() -> void:
	_clear_telegraph_visual()

	var line := Line2D.new()
	line.name = "SlashTelegraph"
	line.width = 4.0
	line.default_color = Color(
		SLASH_WARNING_COLOR.r,
		SLASH_WARNING_COLOR.g,
		SLASH_WARNING_COLOR.b,
		0.42
	)
	line.z_index = 6
	line.modulate.a = 0.3

	var reach := maxf(attack_range, 16.0)
	var points := PackedVector2Array()
	for index in range(11):
		var angle := lerpf(-0.85, 0.85, float(index) / 10.0)
		points.append(
			Vector2(cos(angle) * reach * facing, sin(angle) * reach - 6.0)
		)
	line.points = points
	add_child(line)
	_telegraph_visual = line

	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 1.0, 0.2)


func _spawn_dash_preview() -> void:
	_clear_telegraph_visual()

	var line := Line2D.new()
	line.name = "DashTelegraph"
	line.width = 6.0
	line.default_color = Color(
		DASH_WARNING_COLOR.r,
		DASH_WARNING_COLOR.g,
		DASH_WARNING_COLOR.b,
		0.35
	)
	line.z_index = 6
	line.modulate.a = 0.25

	var reach := maxf(dash_speed * dash_active_time, 24.0)
	line.points = PackedVector2Array([
		Vector2(0.0, -6.0),
		Vector2(reach * facing, -6.0),
	])
	add_child(line)
	_telegraph_visual = line

	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 1.0, 0.2)


func _spawn_dash_streak() -> void:
	if not is_inside_tree():
		return
	var parent := _resolve_attack_parent()
	if parent == null:
		return

	var streak := Line2D.new()
	streak.name = "EliteDashStreak"
	streak.width = 10.0
	streak.default_color = DASH_STRIKE_COLOR
	streak.z_index = 6
	var reach := maxf(dash_speed * dash_active_time, 24.0)
	streak.points = PackedVector2Array([
		Vector2(-facing * reach, -10.0),
		Vector2(0.0, -10.0),
	])
	parent.add_child(streak)
	streak.global_position = global_position

	var tween := streak.create_tween()
	tween.set_parallel(true)
	tween.tween_property(streak, "modulate:a", 0.0, 0.24)
	tween.tween_property(streak, "scale", Vector2(1.15, 1.0), 0.24)
	tween.finished.connect(streak.queue_free)
	JuiceFX.magic_burst(global_position + Vector2(0.0, -18.0), HEX_COLOR, 0.5)


func _spawn_hex_aim_line() -> void:
	_clear_telegraph_visual()

	var line := Line2D.new()
	line.name = "HexAimLine"
	line.width = 2.0
	line.default_color = Color(
		HEX_WARNING_COLOR.r,
		HEX_WARNING_COLOR.g,
		HEX_WARNING_COLOR.b,
		0.55
	)
	line.z_index = 6
	line.modulate.a = 0.35
	add_child(line)
	_telegraph_visual = line
	_update_hex_aim_line()

	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 1.0, 0.2)


func _update_hex_aim_line() -> void:
	if not is_instance_valid(_telegraph_visual):
		return

	var origin := global_position + hex_spawn_offset
	if is_instance_valid(cast_point):
		origin = cast_point.global_position
	var target := _get_aim_position()
	_telegraph_visual.points = PackedVector2Array([
		to_local(origin),
		to_local(target),
	])


func _get_aim_position() -> Vector2:
	if is_instance_valid(player):
		return player.global_position + Vector2(0.0, -8.0)
	return global_position + Vector2(facing * 240.0, -8.0)


func _clear_telegraph_visual() -> void:
	if is_instance_valid(_telegraph_visual):
		_telegraph_visual.queue_free()
	_telegraph_visual = null


func _set_telegraph(
	show_telegraph: bool,
	text: String = "!",
	color: Color = SLASH_WARNING_COLOR
) -> void:
	if not is_instance_valid(telegraph):
		return

	telegraph.text = text
	telegraph.add_theme_color_override("font_color", color)
	telegraph.add_theme_color_override(
		"font_outline_color",
		Color(0.08, 0.0, 0.12, 1.0)
	)

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


func _set_attack_label(text: String, color: Color = Color.WHITE) -> void:
	if not is_instance_valid(attack_label):
		return

	attack_label.text = text
	attack_label.visible = not text.is_empty()
	attack_label.add_theme_color_override("font_color", color)


func _update_player_reference(delta: float) -> void:
	if not is_instance_valid(detection_area):
		_lost_sight_timer += delta
		if _lost_sight_timer >= lose_interest_time:
			player = null
		return

	var candidate: Node2D = null
	for body in detection_area.get_overlapping_bodies():
		var node := body as Node2D
		if node != null and node.is_in_group("player"):
			candidate = node
			break

	if candidate != null and _has_line_of_sight(candidate):
		player = candidate
		_lost_sight_timer = 0.0
		return

	_lost_sight_timer += delta
	if _lost_sight_timer >= lose_interest_time or not is_instance_valid(player):
		player = null


func _has_line_of_sight(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or not is_inside_tree():
		return false

	var space := get_world_2d().direct_space_state
	if space == null:
		return false

	var exclude: Array[RID] = [get_rid()]
	if target is CollisionObject2D:
		exclude.append((target as CollisionObject2D).get_rid())

	var query := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0.0, -12.0),
		target.global_position + Vector2(0.0, -12.0),
		WORLD_LAYER,
		exclude
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query).is_empty()


func _has_target() -> bool:
	return is_instance_valid(player)


func _can_see_player() -> bool:
	return is_instance_valid(player) and _has_line_of_sight(player)


func _get_chase_speed() -> float:
	var multiplier := enrage_speed_multiplier if _enraged else 1.0
	return chase_speed * multiplier


func _get_cooldown_multiplier() -> float:
	return enrage_cooldown_multiplier if _enraged else 1.0


func _get_telegraph_multiplier() -> float:
	return enrage_telegraph_multiplier if _enraged else 1.0


func _get_telegraph_duration() -> float:
	if _attack_mode == AttackMode.HEX_BOLT:
		return hex_telegraph_time * _get_telegraph_multiplier()
	if _attack_mode == AttackMode.DASH:
		return dash_telegraph_time * _get_telegraph_multiplier()
	return slash_telegraph_time * _get_telegraph_multiplier()


func _activate_enrage_if_needed() -> void:
	if _enraged:
		return
	if current_hp > int(float(max_hp) * enrage_health_ratio):
		return

	_enraged = true
	JuiceFX.magic_burst(global_position + Vector2(0.0, -18.0), HEX_COLOR, 1.1)
	JuiceFX.shake_camera(3.0, 0.18)
	EventBus.notification_requested.emit("%s mengamuk!" % boss_display_name)
	_refresh_visual()


func _tick_timers(delta: float) -> void:
	_slash_cooldown_timer = maxf(_slash_cooldown_timer - delta, 0.0)
	_hex_cooldown_timer = maxf(_hex_cooldown_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)


func _enforce_arena_bounds() -> void:
	if not _arena_enabled or _dead:
		return

	var clamped_x := clampf(global_position.x, _arena_left_x, _arena_right_x)
	if is_equal_approx(global_position.x, clamped_x):
		return

	global_position.x = clamped_x
	velocity.x = 0.0


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


func _configure_areas() -> void:
	_configure_hurtbox()
	_configure_detection_area()
	_configure_attack_area()


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
					if _attack_mode == AttackMode.HEX_BOLT:
						visual.modulate = HEX_WARNING_COLOR
					elif _attack_mode == AttackMode.DASH:
						visual.modulate = DASH_WARNING_COLOR
					else:
						visual.modulate = SLASH_WARNING_COLOR
				AttackPhase.ACTIVE:
					if _attack_mode == AttackMode.HEX_BOLT:
						visual.modulate = HEX_STRIKE_COLOR
					elif _attack_mode == AttackMode.DASH:
						visual.modulate = DASH_STRIKE_COLOR
					else:
						visual.modulate = SLASH_STRIKE_COLOR
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
		global_position + Vector2(0.0, -14.0),
		HIT_SPARK_COLOR,
		direction,
		0.75
	)
	JuiceFX.shake_camera(HIT_SHAKE_INTENSITY, HIT_SHAKE_DURATION)


func _play_attack_impact(target: Node2D, direction: float) -> void:
	var impact_position := target.global_position + Vector2(0.0, -8.0)
	JuiceFX.spawn_hit_spark(
		impact_position,
		PLAYER_HIT_SPARK_COLOR,
		direction,
		1.0
	)
	JuiceFX.shake_camera(ATTACK_SHAKE_INTENSITY, ATTACK_SHAKE_DURATION)
	JuiceFX.flash_screen(ATTACK_FLASH_COLOR, 0.14)
	_play_scale_punch(IMPACT_SQUASH_SCALE)


func _play_scale_punch(target_scale: Vector2) -> void:
	if not is_instance_valid(visual):
		return
	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	if visual is Control:
		(visual as Control).pivot_offset = (visual as Control).size * 0.5
	visual.scale = target_scale
	_visual_tween = create_tween()
	_visual_tween.tween_property(visual, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_aura_pulse() -> void:
	var aura := get_node_or_null("Visual/Aura") as CanvasItem
	if aura == null:
		return
	aura.modulate.a = 0.55
	var tween := create_tween().set_loops()
	tween.tween_property(aura, "modulate:a", 1.0, 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(aura, "modulate:a", 0.45, 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _enter_dead() -> void:
	_dead = true
	_fight_active = false
	_attack_mode = AttackMode.NONE
	_attack_phase = AttackPhase.NONE
	_set_telegraph(false)
	_set_attack_label("")
	_clear_telegraph_visual()
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

	if _is_boss_mode():
		GameState.finish_boss_fight(boss_id, true, _fight_serial)
		_fight_serial = -1
		EventBus.boss_health_changed.emit(0, max_hp)
		EventBus.boss_fight_ended.emit(boss_display_name, true)
		EventBus.notification_requested.emit("%s dikalahkan!" % boss_display_name)

	EventBus.enemy_killed.emit(self, global_position)
	_spawn_drops.call_deferred()
	_play_death_effect()


func _snap_to_floor() -> void:
	if not snap_to_floor_on_spawn or not is_inside_tree() or is_queued_for_deletion():
		return

	var space := get_world_2d().direct_space_state
	if space == null:
		return

	var exclude: Array[RID] = [get_rid()]
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node is CollisionObject2D:
		exclude.append((player_node as CollisionObject2D).get_rid())

	var max_distance := maxf(floor_snap_max_distance, 1.0)
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2.DOWN * max_distance,
		WORLD_LAYER,
		exclude
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return

	var normal: Vector2 = hit.get("normal", Vector2.ZERO)
	if normal.y >= -0.5:
		return

	var floor_position: Vector2 = hit.get("position", global_position)
	global_position.y = floor_position.y - _get_body_bottom_offset() - floor_snap_clearance
	velocity = Vector2.ZERO
	_patrol_origin_x = global_position.x


func _get_body_bottom_offset() -> float:
	if is_instance_valid(body_collision) and body_collision.shape != null:
		var shape_rect := body_collision.shape.get_rect()
		return (body_collision.position.y + shape_rect.end.y) * absf(global_scale.y)
	return 36.0


func _resolve_attack_parent() -> Node:
	if not is_inside_tree():
		return null
	var parent := get_parent()
	if (
		parent == null
		or not is_instance_valid(parent)
		or parent.is_queued_for_deletion()
		or not parent.is_inside_tree()
	):
		parent = get_tree().current_scene
	if parent == null or not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return null
	return parent


func _spawn_drops() -> void:
	if drop_table == null:
		return

	var parent := get_parent()
	if parent == null or parent.is_queued_for_deletion():
		return

	ItemDropSpawner.spawn_table(drop_table, parent, global_position + drop_spawn_offset)


func _play_death_effect() -> void:
	JuiceFX.magic_burst(global_position + Vector2(0.0, -18.0), HEX_COLOR, 1.3)
	JuiceFX.spawn_hit_spark(
		global_position + Vector2(0.0, -14.0),
		HIT_SPARK_COLOR,
		0.0,
		1.2
	)
	JuiceFX.shake_camera(HIT_SHAKE_INTENSITY * 1.5, HIT_SHAKE_DURATION * 1.6)

	if not is_instance_valid(visual):
		queue_free()
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "modulate:a", 0.0, 0.4)
	tween.tween_property(visual, "scale", Vector2(1.2, 0.2), 0.4)
	tween.finished.connect(queue_free)
