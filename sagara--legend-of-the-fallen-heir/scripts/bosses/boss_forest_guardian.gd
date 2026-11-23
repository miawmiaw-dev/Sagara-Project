class_name ForestGuardianBoss
extends CharacterBody2D

enum State {
	DORMANT,
	INTRO,
	IDLE,
	CHASE,
	SLASH,
	LEAP,
	DASH,
	PROJECTILE,
	GROUND_WAVE,
	ENERGY_THROW,
	HURT,
	DEAD,
}

enum AttackPhase {
	NONE,
	WINDUP,
	ACTIVE,
	RECOVERY,
}

const BOSS_ID := "penjaga_hutan_larangan"
const BOSS_NAME := "Penjaga Hutan Larangan"
const HURTBOX_LAYER := 2
const PLAYER_BODY_LAYER := 1
const WORLD_LAYER := 1
const ENEMY_BODY_LAYER := 4
const BODY_COLLISION_MASK := WORLD_LAYER | PLAYER_BODY_LAYER | ENEMY_BODY_LAYER
const DEFAULT_PROJECTILE_SCENE := preload("res://scenes/bosses/boss_projectile.tscn")
const DEFAULT_SHOCKWAVE_SCENE := preload("res://scenes/bosses/boss_ground_wave.tscn")
const DEFAULT_DROP_TABLE := preload("res://resources/items/melee_enemy_drops.tres")

const HIT_COLOR := Color(1.0, 0.25, 0.25, 1.0)
const WARNING_COLOR := Color(1.0, 0.62, 0.16, 1.0)
const STRIKE_COLOR := Color(1.0, 0.95, 0.65, 1.0)
const CAST_COLOR := Color(0.38, 0.95, 0.72, 1.0)

signal health_changed(current: int, maximum: int)

@export_group("Identity")
@export var boss_id: String = BOSS_ID

@export_group("Stats")
@export_range(1, 5000, 1) var max_hp: int = 420
@export_range(1, 500, 1) var poise_threshold: int = 85
@export_range(0.1, 2.0, 0.05) var hurt_duration: float = 0.42

@export_group("Movement")
@export var chase_speed: float = 135.0
@export var acceleration: float = 850.0
@export var deceleration: float = 1250.0
@export var gravity_scale: float = 1.0
@export_range(0.0, 3.0, 0.05) var intro_duration: float = 0.9
@export_range(0.0, 3.0, 0.05) var idle_duration: float = 0.55
@export_range(0.1, 4.0, 0.05) var attack_lock_time: float = 0.65

@export_group("Heavy Slash")
@export var slash_range: float = 124.0
@export var slash_height: float = 96.0
@export_range(1, 500, 1) var slash_damage: int = 24
@export_range(0.0, 1000.0, 1.0) var slash_knockback: float = 420.0
@export_range(0.1, 3.0, 0.05) var slash_telegraph_time: float = 0.55
@export_range(0.05, 1.0, 0.01) var slash_active_time: float = 0.16
@export_range(0.0, 2.0, 0.05) var slash_recovery_time: float = 0.45
@export_range(0.1, 10.0, 0.05) var slash_cooldown: float = 1.8

@export_group("Leaping Slam")
@export var leap_min_range: float = 150.0
@export var leap_max_range: float = 620.0
@export_range(0.1, 3.0, 0.05) var leap_telegraph_time: float = 0.35
@export var leap_velocity: float = -540.0
@export_range(1.0, 800.0, 1.0) var leap_min_horizontal_speed: float = 110.0
@export_range(1.0, 1000.0, 1.0) var leap_max_horizontal_speed: float = 370.0
@export_range(1.0, 400.0, 1.0) var leap_landing_radius: float = 108.0
@export_range(1, 500, 1) var leap_damage: int = 28
@export_range(0.0, 1000.0, 1.0) var leap_knockback: float = 470.0
@export_range(0.0, 2.0, 0.05) var leap_recovery_time: float = 0.55
@export_range(0.1, 10.0, 0.05) var leap_cooldown: float = 4.2

@export_group("Phantom Dash")
@export var dash_min_range: float = 110.0
@export var dash_max_range: float = 330.0
@export_range(100.0, 1200.0, 1.0) var dash_speed: float = 560.0
@export_range(0.1, 2.0, 0.05) var dash_telegraph_time: float = 0.4
@export_range(0.05, 1.0, 0.01) var dash_active_time: float = 0.5
@export_range(0.0, 2.0, 0.05) var dash_recovery_time: float = 0.4
@export_range(0.1, 10.0, 0.05) var dash_cooldown: float = 3.6
@export_range(1, 500, 1) var dash_damage: int = 22
@export_range(0.0, 1000.0, 1.0) var dash_knockback: float = 380.0
@export var dash_hit_range: float = 54.0
@export var dash_hit_height: float = 88.0

@export_group("Forest Projectiles")
@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@export_range(1, 12, 1) var projectile_count: int = 3
@export_range(0.0, 5.0, 0.05) var projectile_min_range: float = 130.0
@export_range(0.1, 3.0, 0.05) var projectile_windup_time: float = 0.65
@export_range(0.0, 2.0, 0.05) var projectile_recovery_time: float = 0.55
@export_range(0.1, 10.0, 0.05) var projectile_cooldown: float = 5.0
@export_range(1, 200, 1) var projectile_damage: int = 16
@export_range(1.0, 1000.0, 1.0) var projectile_speed: float = 300.0
@export_range(0.0, 1000.0, 1.0) var projectile_knockback: float = 280.0
@export var projectile_spacing: float = 18.0

@export_group("Ground Shockwave")
@export var shockwave_scene: PackedScene = DEFAULT_SHOCKWAVE_SCENE
@export_range(0.1, 3.0, 0.05) var shockwave_telegraph_time: float = 0.5
@export_range(0.0, 2.0, 0.05) var shockwave_recovery_time: float = 0.55
@export_range(0.1, 10.0, 0.05) var shockwave_cooldown: float = 3.2
@export_range(0.0, 5.0, 0.05) var shockwave_min_range: float = 72.0
@export_range(60.0, 1200.0, 1.0) var shockwave_max_range: float = 360.0
@export_range(1.0, 800.0, 1.0) var shockwave_speed: float = 280.0
@export_range(1, 200, 1) var shockwave_damage: int = 18
@export_range(0.0, 1000.0, 1.0) var shockwave_knockback: float = 340.0
@export var shockwave_spawn_offset: Vector2 = Vector2(28.0, 40.0)

@export_group("Energy Volley")
@export_range(0.1, 3.0, 0.05) var energy_telegraph_time: float = 0.55
@export_range(0.0, 2.0, 0.05) var energy_recovery_time: float = 0.45
@export_range(0.1, 10.0, 0.05) var energy_cooldown: float = 4.6
@export_range(0.0, 1200.0, 1.0) var energy_min_range: float = 300.0
@export_range(1, 12, 1) var energy_projectile_count: int = 1
@export_range(0.0, 45.0, 0.5) var energy_spread_degrees: float = 8.0
@export_range(1, 200, 1) var energy_damage: int = 20
@export_range(1.0, 1500.0, 1.0) var energy_speed: float = 340.0
@export_range(0.0, 1000.0, 1.0) var energy_knockback: float = 300.0
@export var energy_spawn_offset: Vector2 = Vector2(34.0, -16.0)

@export_group("Combo Pressure")
@export_range(0.0, 1.0, 0.01) var combo_chance: float = 0.32
@export_range(0.0, 1.0, 0.01) var phase_two_combo_chance: float = 0.55
@export_range(1, 4, 1) var max_combo_length: int = 2
@export_range(0.0, 1.0, 0.05) var combo_gap: float = 0.18
@export_range(0.0, 1.0, 0.01) var retreat_chance: float = 0.28
@export_range(0.0, 1.0, 0.05) var retreat_speed_multiplier: float = 0.72
@export_range(0.0, 1.0, 0.05) var close_pressure_speed_multiplier: float = 0.55
@export_range(0.1, 2.0, 0.05) var reposition_interval: float = 0.55

@export_group("Phase Two")
@export_range(0.0, 1.0, 0.01) var phase_two_health_ratio: float = 0.5
@export_range(1.0, 2.0, 0.01) var phase_two_speed_multiplier: float = 1.3
@export_range(0.2, 1.0, 0.01) var phase_two_cooldown_multiplier: float = 0.7

@export_group("Drops")
@export var drop_table: ItemDropTable = DEFAULT_DROP_TABLE
@export var drop_spawn_offset: Vector2 = Vector2(0.0, -20.0)

@export_group("Spawn")
@export var snap_to_floor_on_spawn: bool = true
@export var floor_snap_max_distance: float = 320.0
@export var floor_snap_clearance: float = 1.0
@export var floor_search_step: float = 32.0
@export var floor_search_radius: float = 300.0
@export var debug_spawn: bool = false

@export_group("Exit")
@export var exit_portal_path: NodePath
@export var exit_portal_group: String = "boss_exit_portal"
@export var auto_activate_exit_on_death: bool = true

var state: State = State.DORMANT
var current_hp: int = 420
var facing: float = -1.0

var _player: Node2D = null
var _home_position: Vector2 = Vector2.ZERO
var _state_time: float = 0.0
var _attack_phase: AttackPhase = AttackPhase.NONE
var _attack_hit: bool = false
var _fight_active: bool = false
var _fight_serial: int = -1
var _dead: bool = false
var _phase_two_active: bool = false
var _attack_lock_timer: float = 0.0
var _slash_cooldown_timer: float = 0.0
var _leap_cooldown_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _projectile_cooldown_timer: float = 0.0
var _shockwave_cooldown_timer: float = 0.0
var _energy_cooldown_timer: float = 0.0
var _hurt_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _poise_damage: int = 0
var _leap_launched: bool = false
var _leap_airborne: bool = false
var _leap_landed: bool = false
var _leap_land_time: float = 0.0
var _dash_started: bool = false
var _projectile_spawned: bool = false
var _shockwave_spawned: bool = false
var _energy_volley_spawned: bool = false
var _last_attack: int = -1
var _combo_count: int = 0
var _reposition_timer: float = 0.0
var _reposition_direction: float = 0.0
var _pending_floor_snap: bool = false
var _arena_enabled: bool = false
var _arena_left_x: float = 0.0
var _arena_right_x: float = 0.0
var _exit_portal: Node = null

var _rng := RandomNumberGenerator.new()

@onready var visual: CanvasItem = get_node_or_null("Visual") as CanvasItem
@onready var telegraph: Label = get_node_or_null("Telegraph") as Label
@onready var attack_label: Label = get_node_or_null("AttackName") as Label
@onready var body_collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
@onready var slash_area: Area2D = get_node_or_null("SlashArea") as Area2D
@onready var slash_collision: CollisionShape2D = (
	get_node_or_null("SlashArea/CollisionShape2D") as CollisionShape2D
)


func _ready() -> void:
	_rng.randomize()
	max_hp = maxi(max_hp, 1)
	current_hp = max_hp
	_resolve_node_references()

	if GameState.is_boss_defeated(boss_id):
		_apply_defeated_state()
		return

	_home_position = global_position
	_configure_body_collision()
	_configure_areas()
	_set_telegraph(false)
	_set_attack_label("")
	_refresh_visual()
	visible = false

	if debug_spawn:
		var parent_name := "null"
		if get_parent() != null:
			parent_name = str(get_parent().name)
		print(
			"[ForestGuardianBoss] _ready spawn global_position=%s parent=%s floor_snap=%s"
			% [global_position, parent_name, snap_to_floor_on_spawn]
		)

	if not EventBus.player_respawned.is_connected(_on_player_respawned):
		EventBus.player_respawned.connect(_on_player_respawned)

	_pending_floor_snap = snap_to_floor_on_spawn


func _physics_process(delta: float) -> void:
	if _dead:
		return

	if _pending_floor_snap:
		_pending_floor_snap = false
		_snap_to_floor()

	_tick_timers(delta)
	_apply_gravity(delta)
	_state_time += delta

	if not _fight_active:
		_decelerate(delta)
		move_and_slide()
		return

	_update_player_reference()

	match state:
		State.INTRO:
			_process_intro(delta)
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.SLASH:
			_process_slash(delta)
		State.LEAP:
			_process_leap(delta)
		State.DASH:
			_process_dash(delta)
		State.PROJECTILE:
			_process_projectile(delta)
		State.GROUND_WAVE:
			_process_ground_wave(delta)
		State.ENERGY_THROW:
			_process_energy_throw(delta)
		State.HURT:
			_process_hurt(delta)

	move_and_slide()
	_enforce_arena_bounds()

	if state == State.SLASH and _attack_phase == AttackPhase.ACTIVE:
		_try_slash_hit()


func configure_arena(left_x: float, right_x: float) -> void:
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
	global_position = new_position
	velocity = Vector2.ZERO


func activate_fight(player: Node2D = null) -> bool:
	if _dead or _fight_active or state != State.DORMANT:
		return false
	if not GameState.begin_boss_fight(boss_id):
		return false
	_fight_serial = GameState.get_active_boss_serial(boss_id)

	if _is_player_usable(player):
		_player = player
	else:
		_player = _find_player()
		if not _is_player_usable(_player):
			_player = null

	_fight_active = true
	current_hp = max_hp
	_dash_started = false
	_set_exit_portal_active(false)
	set_physics_process(true)
	visible = true
	modulate.a = 1.0
	if is_instance_valid(visual):
		visual.visible = true
		visual.modulate.a = 1.0
	_set_body_interaction(true)
	_set_state(State.INTRO)
	_set_attack_label("PENJAGA TERBANGUN")
	EventBus.boss_fight_started.emit(BOSS_NAME, max_hp)
	EventBus.boss_health_changed.emit(current_hp, max_hp)
	EventBus.notification_requested.emit("%s terbangun!" % BOSS_NAME)
	_spawn_shockwave(WARNING_COLOR)
	return true


func take_damage(
	amount: int,
	_knockback_direction: float = 0.0,
	_knockback_force: float = -1.0
) -> bool:
	if amount <= 0 or _dead or not _fight_active:
		return false
	if state == State.INTRO:
		return false

	current_hp = clampi(current_hp - amount, 0, max_hp)
	health_changed.emit(current_hp, max_hp)
	EventBus.boss_health_changed.emit(current_hp, max_hp)
	_hit_flash_timer = 0.09
	_refresh_visual()

	if current_hp <= 0:
		_die()
		return true

	_activate_phase_two_if_needed()
	_poise_damage += amount
	if _poise_damage >= maxi(poise_threshold, 1) and state != State.LEAP:
		_poise_damage = 0
		_hurt_timer = hurt_duration
		_set_state(State.HURT)
	return true


func stun_enemy(duration: float) -> void:
	if _dead or not _fight_active or duration <= 0.0:
		return
	if state == State.LEAP or state == State.INTRO:
		return
	_hurt_timer = maxf(_hurt_timer, maxf(duration, hurt_duration))
	if state == State.HURT:
		_refresh_visual()
		return
	_set_state(State.HURT)


func is_fight_active() -> bool:
	return _fight_active and not _dead


func set_dormant() -> void:
	if _dead:
		return
	_fight_active = false
	_fight_serial = -1
	_clear_projectiles()
	_set_exit_portal_active(false)
	current_hp = max_hp
	_poise_damage = 0
	_attack_lock_timer = 0.0
	_slash_cooldown_timer = 0.0
	_leap_cooldown_timer = 0.0
	_dash_cooldown_timer = 0.0
	_projectile_cooldown_timer = 0.0
	_shockwave_cooldown_timer = 0.0
	_energy_cooldown_timer = 0.0
	_hurt_timer = 0.0
	_hit_flash_timer = 0.0
	_phase_two_active = false
	_player = null
	_attack_phase = AttackPhase.NONE
	_attack_hit = false
	_last_attack = -1
	_combo_count = 0
	_reposition_timer = 0.0
	_reposition_direction = 0.0
	_leap_launched = false
	_leap_airborne = false
	_leap_landed = false
	_leap_land_time = 0.0
	_dash_started = false
	_projectile_spawned = false
	_shockwave_spawned = false
	_energy_volley_spawned = false
	_state_time = 0.0
	velocity = Vector2.ZERO
	global_position = _home_position
	_set_body_interaction(false)
	_set_state(State.DORMANT)
	visible = false
	_refresh_visual()


func _tick_timers(delta: float) -> void:
	_attack_lock_timer = maxf(_attack_lock_timer - delta, 0.0)
	_slash_cooldown_timer = maxf(_slash_cooldown_timer - delta, 0.0)
	_leap_cooldown_timer = maxf(_leap_cooldown_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_projectile_cooldown_timer = maxf(_projectile_cooldown_timer - delta, 0.0)
	_shockwave_cooldown_timer = maxf(_shockwave_cooldown_timer - delta, 0.0)
	_energy_cooldown_timer = maxf(_energy_cooldown_timer - delta, 0.0)

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
		if _hit_flash_timer <= 0.0:
			_refresh_visual()


func _process_intro(delta: float) -> void:
	_decelerate(delta)
	if _state_time < intro_duration:
		return
	_set_telegraph(false)
	_set_attack_label("")
	_set_state(State.CHASE)


func _process_idle(delta: float) -> void:
	_decelerate(delta)
	if _state_time < idle_duration:
		return
	_set_state(State.CHASE if _has_valid_player() else State.IDLE)


func _process_chase(delta: float) -> void:
	if not _has_valid_player():
		_set_state(State.IDLE)
		return

	var player := _player
	var horizontal_offset := player.global_position.x - global_position.x
	var distance := absf(horizontal_offset)
	var direction := signf(horizontal_offset)
	if is_zero_approx(direction):
		direction = facing
	_set_facing(direction)

	if _attack_lock_timer <= 0.0:
		var next_attack := _choose_attack(distance)
		if next_attack != State.CHASE:
			_set_state(next_attack)
			return

	var desired_speed := chase_speed * _get_speed_multiplier()
	if distance <= slash_range * 0.7:
		_apply_close_pressure(delta, direction, desired_speed, distance)
		return
	_reposition_timer = maxf(_reposition_timer - delta, 0.0)
	velocity.x = move_toward(velocity.x, direction * desired_speed, acceleration * delta)


func _apply_close_pressure(
	delta: float,
	direction: float,
	desired_speed: float,
	distance: float
) -> void:
	_reposition_timer = maxf(_reposition_timer - delta, 0.0)
	if _reposition_timer <= 0.0:
		_reposition_timer = maxf(reposition_interval, 0.1) * _rng.randf_range(0.75, 1.25)
		var retreat_weight := retreat_chance
		if _phase_two_active:
			retreat_weight = minf(retreat_weight * 1.3, 1.0)
		if _rng.randf() < retreat_weight:
			_reposition_direction = -direction
		else:
			_reposition_direction = direction
		if is_zero_approx(_reposition_direction):
			_reposition_direction = -facing

	if (
		is_equal_approx(_reposition_direction, direction)
		and distance <= slash_range * 0.35
	):
		_decelerate(delta)
		return

	var multiplier := close_pressure_speed_multiplier
	if not is_equal_approx(_reposition_direction, direction):
		multiplier = retreat_speed_multiplier
	velocity.x = move_toward(
		velocity.x,
		_reposition_direction * desired_speed * multiplier,
		acceleration * delta
	)


func _choose_attack(distance: float) -> State:
	var options: Array[State] = []
	var weights: Array[float] = []

	if distance <= slash_range and _slash_cooldown_timer <= 0.0:
		options.append(State.SLASH)
		weights.append(1.45 if _phase_two_active else 1.2)
	if (
		distance >= dash_min_range
		and distance <= dash_max_range
		and _dash_cooldown_timer <= 0.0
	):
		options.append(State.DASH)
		weights.append(2.4 if _phase_two_active else 1.5)
	if (
		distance >= shockwave_min_range
		and distance <= shockwave_max_range
		and _shockwave_cooldown_timer <= 0.0
	):
		options.append(State.GROUND_WAVE)
		weights.append(1.1)
	if (
		distance >= leap_min_range
		and distance <= leap_max_range
		and _leap_cooldown_timer <= 0.0
	):
		options.append(State.LEAP)
		weights.append(1.15)
	if distance >= projectile_min_range and _projectile_cooldown_timer <= 0.0:
		options.append(State.PROJECTILE)
		weights.append(0.85 if _phase_two_active else 1.0)
	if distance >= energy_min_range and _energy_cooldown_timer <= 0.0:
		options.append(State.ENERGY_THROW)
		weights.append(1.2 if _phase_two_active else 1.0)

	if options.is_empty():
		return State.CHASE

	var chosen := _pick_weighted_attack(options, weights)
	if options.size() > 1 and chosen == _last_attack:
		var filtered_options: Array[State] = []
		var filtered_weights: Array[float] = []
		for index in range(options.size()):
			if options[index] == _last_attack:
				continue
			filtered_options.append(options[index])
			filtered_weights.append(weights[index])
		if not filtered_options.is_empty():
			chosen = _pick_weighted_attack(filtered_options, filtered_weights)
	_last_attack = int(chosen)
	return chosen


func _pick_weighted_attack(options: Array[State], weights: Array[float]) -> State:
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


func _process_slash(delta: float) -> void:
	_decelerate(delta)
	var active_start := slash_telegraph_time * _get_telegraph_multiplier()
	var active_end := active_start + slash_active_time
	var recovery_end := active_end + slash_recovery_time

	if _state_time < active_start:
		_attack_phase = AttackPhase.WINDUP
		_set_telegraph(true)
		_refresh_visual()
		return

	if _state_time < active_end:
		if _attack_phase != AttackPhase.ACTIVE:
			_attack_phase = AttackPhase.ACTIVE
			_attack_hit = false
			_set_telegraph(false)
			_refresh_visual()
		_try_slash_hit()
		return

	if _state_time < recovery_end:
		_attack_phase = AttackPhase.RECOVERY
		_refresh_visual()
		return

	_slash_cooldown_timer = slash_cooldown * _get_cooldown_multiplier()
	_finish_attack()


func _process_leap(delta: float) -> void:
	if _state_time < leap_telegraph_time * _get_telegraph_multiplier():
		_decelerate(delta)
		_attack_phase = AttackPhase.WINDUP
		_set_telegraph(true)
		return

	if not _leap_launched:
		_launch_leap()

	if _leap_landed:
		_decelerate(delta)
		if _state_time - _leap_land_time >= leap_recovery_time:
			_leap_cooldown_timer = leap_cooldown * _get_cooldown_multiplier()
			_finish_attack()
		return

	if not is_on_floor():
		_leap_airborne = true

	if _leap_airborne and is_on_floor():
		_land_leap()


func _process_dash(delta: float) -> void:
	var windup := dash_telegraph_time * _get_telegraph_multiplier()

	if _state_time < windup:
		_decelerate(delta)
		_attack_phase = AttackPhase.WINDUP
		_set_telegraph(true)
		_refresh_visual()
		return

	if not _dash_started:
		_dash_started = true
		_attack_phase = AttackPhase.ACTIVE
		_attack_hit = false
		_set_telegraph(false)
		_set_attack_label("")
		_refresh_visual()
		_spawn_shockwave(WARNING_COLOR)

	if _state_time < windup + dash_active_time:
		velocity.x = facing * dash_speed * _get_speed_multiplier()
		_try_dash_hit()
		return

	if _attack_phase != AttackPhase.RECOVERY:
		_attack_phase = AttackPhase.RECOVERY
		_refresh_visual()

	_decelerate(delta)
	if _state_time >= windup + dash_active_time + dash_recovery_time:
		_finish_attack()


func _try_dash_hit() -> void:
	if _attack_hit:
		return
	_refresh_player_reference()
	var player := _player
	if not _is_player_usable(player):
		return

	var offset := player.global_position - global_position
	if (
		absf(offset.x) > maxf(dash_hit_range, 1.0)
		or absf(offset.y) > maxf(dash_hit_height, 1.0)
	):
		return

	var direction := signf(offset.x)
	if is_zero_approx(direction):
		direction = facing
	_attack_hit = true
	var damaged := bool(player.call("take_damage", dash_damage, self))
	if not damaged or not _fight_active or not _is_player_usable(player):
		return
	if player.has_method("apply_knockback"):
		player.call("apply_knockback", direction, dash_knockback)


func _process_projectile(delta: float) -> void:
	_decelerate(delta)
	var windup := projectile_windup_time * _get_telegraph_multiplier()

	if _state_time < windup:
		_attack_phase = AttackPhase.WINDUP
		_set_telegraph(true)
		return

	if not _projectile_spawned:
		_projectile_spawned = true
		_attack_phase = AttackPhase.ACTIVE
		_set_telegraph(false)
		_set_attack_label("")
		_refresh_visual()
		_spawn_projectiles()
		return

	if _state_time >= windup + projectile_recovery_time:
		_projectile_cooldown_timer = projectile_cooldown * _get_cooldown_multiplier()
		_finish_attack()


func _process_ground_wave(delta: float) -> void:
	_decelerate(delta)
	var windup := shockwave_telegraph_time * _get_telegraph_multiplier()

	if _state_time < windup:
		_attack_phase = AttackPhase.WINDUP
		_set_telegraph(true)
		return

	if not _shockwave_spawned:
		_shockwave_spawned = true
		_attack_phase = AttackPhase.ACTIVE
		_set_telegraph(false)
		_set_attack_label("")
		_refresh_visual()
		_spawn_ground_shockwaves()
		return

	if _state_time >= windup + shockwave_recovery_time:
		_shockwave_cooldown_timer = shockwave_cooldown * _get_cooldown_multiplier()
		_finish_attack()


func _process_energy_throw(delta: float) -> void:
	_decelerate(delta)
	var windup := energy_telegraph_time * _get_telegraph_multiplier()

	if _state_time < windup:
		_attack_phase = AttackPhase.WINDUP
		_set_telegraph(true)
		return

	if not _energy_volley_spawned:
		_energy_volley_spawned = true
		_attack_phase = AttackPhase.ACTIVE
		_set_telegraph(false)
		_set_attack_label("")
		_refresh_visual()
		_spawn_energy_volley()
		return

	if _state_time >= windup + energy_recovery_time:
		_energy_cooldown_timer = energy_cooldown * _get_cooldown_multiplier()
		_finish_attack()


func _process_hurt(delta: float) -> void:
	_decelerate(delta)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	if _hurt_timer > 0.0:
		return
	_set_state(State.CHASE if _has_valid_player() else State.IDLE)


func _enter_state(next_state: State) -> void:
	match next_state:
		State.DORMANT:
			_attack_phase = AttackPhase.NONE
			_set_body_interaction(false)
			_set_telegraph(false)
			_set_attack_label("")
			visible = false
		State.INTRO:
			_attack_phase = AttackPhase.NONE
			velocity.x = 0.0
			_face_player()
			_set_telegraph(true)
		State.IDLE:
			velocity.x = 0.0
		State.SLASH:
			_enter_slash()
		State.LEAP:
			_enter_leap()
		State.DASH:
			_enter_dash()
		State.PROJECTILE:
			_enter_projectile()
		State.GROUND_WAVE:
			_enter_ground_wave()
		State.ENERGY_THROW:
			_enter_energy_throw()
		State.HURT:
			_attack_phase = AttackPhase.NONE
			_combo_count = 0
			_set_telegraph(false)
			_set_attack_label("")
		State.DEAD:
			_enter_dead()


func _exit_state(previous_state: State) -> void:
	if previous_state == State.SLASH or previous_state == State.LEAP \
		or previous_state == State.DASH or previous_state == State.PROJECTILE \
		or previous_state == State.GROUND_WAVE or previous_state == State.ENERGY_THROW:
		_attack_phase = AttackPhase.NONE
		_set_telegraph(false)


func _enter_slash() -> void:
	_attack_phase = AttackPhase.WINDUP
	_attack_hit = false
	velocity.x = 0.0
	_face_player()
	_set_telegraph(true)
	_set_attack_label("TEBASAN BERAT")
	_refresh_visual()


func _enter_leap() -> void:
	_attack_phase = AttackPhase.WINDUP
	_leap_launched = false
	_leap_airborne = false
	_leap_landed = false
	_leap_land_time = 0.0
	velocity.x = 0.0
	_face_player()
	_set_telegraph(true)
	_set_attack_label("LOMPATAN PENGHANCUR")
	_refresh_visual()


func _enter_dash() -> void:
	_attack_phase = AttackPhase.WINDUP
	_attack_hit = false
	_dash_started = false
	_dash_cooldown_timer = dash_cooldown * _get_cooldown_multiplier()
	velocity.x = 0.0
	_face_player()
	_set_telegraph(true)
	_set_attack_label("TERJANGAN BAYANGAN")
	_refresh_visual()


func _enter_projectile() -> void:
	_attack_phase = AttackPhase.WINDUP
	_projectile_spawned = false
	velocity.x = 0.0
	_face_player()
	_set_telegraph(true)
	_set_attack_label("PANGGILAN HUTAN")
	_refresh_visual()


func _enter_ground_wave() -> void:
	_attack_phase = AttackPhase.WINDUP
	_shockwave_spawned = false
	velocity.x = 0.0
	_face_player()
	_set_telegraph(true)
	_set_attack_label("GELOMBANG TANAH")
	_refresh_visual()


func _enter_energy_throw() -> void:
	_attack_phase = AttackPhase.WINDUP
	_energy_volley_spawned = false
	velocity.x = 0.0
	_face_player()
	_set_telegraph(true)
	_set_attack_label("LEMPARAN ENERGI")
	_refresh_visual()


func _face_player() -> void:
	if not _refresh_player_reference():
		return
	var player := _player
	if not _is_player_usable(player):
		return
	var direction := signf(player.global_position.x - global_position.x)
	if not is_zero_approx(direction):
		_set_facing(direction)


func _launch_leap() -> void:
	_leap_launched = true
	_attack_phase = AttackPhase.ACTIVE
	_set_telegraph(false)
	_set_attack_label("LOMPATAN PENGHANCUR")
	_refresh_visual()
	_refresh_player_reference()

	var horizontal_speed := leap_min_horizontal_speed
	if _has_valid_player():
		var player := _player
		var distance := absf(player.global_position.x - global_position.x)
		var default_gravity := float(
			ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
		)
		var air_time := 2.0 * absf(leap_velocity) / maxf(default_gravity * gravity_scale, 1.0)
		horizontal_speed = clampf(
			distance / maxf(air_time, 0.1),
			leap_min_horizontal_speed,
			leap_max_horizontal_speed * _get_speed_multiplier()
		)
		var direction := signf(player.global_position.x - global_position.x)
		if not is_zero_approx(direction):
			_set_facing(direction)

	velocity = Vector2(facing * horizontal_speed, leap_velocity)


func _land_leap() -> void:
	_leap_landed = true
	_leap_land_time = _state_time
	_leap_airborne = false
	_attack_phase = AttackPhase.RECOVERY
	velocity.x = 0.0
	_set_telegraph(false)
	_set_attack_label("")
	_refresh_visual()
	_spawn_shockwave(WARNING_COLOR)
	_damage_player_in_landing_radius()


func _damage_player_in_landing_radius() -> void:
	_refresh_player_reference()
	var player := _player
	if not _is_player_usable(player):
		return
	if not player.has_method("take_damage"):
		return

	var offset := player.global_position - global_position
	if absf(offset.x) > leap_landing_radius or absf(offset.y) > leap_landing_radius * 1.4:
		return

	var direction := signf(offset.x)
	if is_zero_approx(direction):
		direction = facing
	var damaged := bool(player.call("take_damage", leap_damage, self))
	if not damaged or not _fight_active:
		return
	if not _is_player_usable(player):
		return
	if player.has_method("apply_knockback"):
		player.call("apply_knockback", direction, leap_knockback)


func _finish_attack() -> void:
	_attack_phase = AttackPhase.NONE
	_set_telegraph(false)
	_set_attack_label("")
	_poise_damage = 0
	_reposition_timer = 0.0

	var combo_limit := maxi(max_combo_length + (1 if _phase_two_active else 0), 1)
	var chain_allowed := _combo_count + 1 < combo_limit
	var chain_chance := phase_two_combo_chance if _phase_two_active else combo_chance
	if (
		chain_allowed
		and _has_valid_player()
		and _rng.randf() < clampf(chain_chance, 0.0, 1.0)
	):
		_combo_count += 1
		_attack_lock_timer = maxf(combo_gap, 0.0) * _get_cooldown_multiplier()
	else:
		_combo_count = 0
		_attack_lock_timer = attack_lock_time * _get_cooldown_multiplier()

	_set_state(State.CHASE if _has_valid_player() else State.IDLE)


func _set_state(next_state: State) -> void:
	if state == next_state:
		return

	_exit_state(state)
	state = next_state
	_state_time = 0.0
	_enter_state(state)
	_refresh_visual()


func _try_slash_hit() -> void:
	if _attack_hit or not is_instance_valid(slash_area):
		return

	for body in slash_area.get_overlapping_bodies():
		if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		var target := body as Node2D
		if not _is_player_usable(target) or not target.is_in_group("player"):
			continue
		if not target.has_method("take_damage"):
			continue

		_attack_hit = true
		var direction := facing
		var horizontal_offset := target.global_position.x - global_position.x
		if not is_zero_approx(horizontal_offset):
			direction = signf(horizontal_offset)

		var damaged := bool(target.call("take_damage", slash_damage, self))
		if not damaged or not _is_player_usable(target) or not _fight_active:
			return
		if target.has_method("apply_knockback"):
			target.call("apply_knockback", direction, slash_knockback)
		return


func _spawn_projectiles() -> void:
	if projectile_scene == null:
		return
	var parent := _resolve_attack_parent()
	if parent == null:
		return

	_face_player()
	var count := maxi(projectile_count + (1 if _phase_two_active else 0), 1)
	for index in range(count):
		var projectile := projectile_scene.instantiate()
		if projectile == null:
			continue
		parent.add_child(projectile)
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			continue
		if projectile is Node2D:
			var vertical_offset := (
				(float(index) - float(count - 1) * 0.5) * projectile_spacing
			)
			(projectile as Node2D).global_position = global_position + Vector2(
				facing * 42.0,
				vertical_offset - 8.0
			)
		if projectile.has_method("launch"):
			if projectile is BossProjectile:
				(projectile as BossProjectile).knockback_force = projectile_knockback
			projectile.call("launch", facing, projectile_damage, projectile_speed)
		else:
			projectile.queue_free()


func _spawn_ground_shockwaves() -> void:
	if shockwave_scene == null:
		return
	var parent := _resolve_attack_parent()
	if parent == null:
		return

	_refresh_player_reference()
	var direction := _get_player_direction()
	var directions: Array[float] = [direction]
	if _phase_two_active:
		directions.append(-direction)
	for wave_direction in directions:
		_spawn_ground_wave(parent, wave_direction)


func _spawn_ground_wave(parent: Node, wave_direction: float) -> void:
	if shockwave_scene == null:
		return
	var wave := shockwave_scene.instantiate()
	if wave == null:
		return
	parent.add_child(wave)
	if not is_instance_valid(wave) or wave.is_queued_for_deletion():
		return
	if wave is Node2D:
		(wave as Node2D).global_position = global_position + Vector2(
			wave_direction * shockwave_spawn_offset.x,
			shockwave_spawn_offset.y
		)
	if not wave.has_method("launch"):
		wave.queue_free()
		return
	if wave is BossGroundWave:
		(wave as BossGroundWave).knockback_force = shockwave_knockback
	wave.call("launch", wave_direction, shockwave_damage, shockwave_speed)


func _spawn_energy_volley() -> void:
	if projectile_scene == null:
		return
	var parent := _resolve_attack_parent()
	if parent == null:
		return

	_refresh_player_reference()
	var fallback_direction := _get_player_direction()
	_set_facing(fallback_direction)
	var spawn_position := global_position + Vector2(
		facing * energy_spawn_offset.x,
		energy_spawn_offset.y
	)
	var target := global_position + Vector2(fallback_direction * 320.0, -16.0)
	var player := _player
	if _has_valid_player() and _is_player_usable(player):
		var player_position := player.global_position
		if _is_valid_spawn_position(player_position):
			target = player_position

	var aim := target - spawn_position
	if aim.length_squared() <= 0.0001 or not _is_valid_spawn_position(aim):
		aim = Vector2(facing, 0.0)
	var base_angle := aim.angle()
	var count := maxi(energy_projectile_count + (1 if _phase_two_active else 0), 1)
	var spread := deg_to_rad(maxf(energy_spread_degrees, 0.0))

	for index in range(count):
		var projectile := projectile_scene.instantiate()
		if projectile == null:
			continue
		parent.add_child(projectile)
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			continue
		if projectile is Node2D:
			(projectile as Node2D).global_position = spawn_position
		if projectile is CanvasItem:
			(projectile as CanvasItem).modulate = CAST_COLOR
		if not projectile.has_method("launch_velocity"):
			projectile.queue_free()
			continue
		if projectile is BossProjectile:
			(projectile as BossProjectile).knockback_force = energy_knockback

		var angle_offset := 0.0
		if count > 1:
			angle_offset = spread * (float(index) / float(count - 1) - 0.5)
		var shot_velocity := Vector2.from_angle(base_angle + angle_offset) * maxf(
			energy_speed,
			1.0
		)
		var launched := bool(projectile.call("launch_velocity", shot_velocity, energy_damage))
		if not launched:
			projectile.queue_free()


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


func _get_player_direction() -> float:
	if _has_valid_player():
		var player := _player
		if _is_player_usable(player):
			var horizontal_offset := player.global_position.x - global_position.x
			if not is_zero_approx(horizontal_offset):
				return signf(horizontal_offset)
	if not is_zero_approx(facing):
		return signf(facing)
	return -1.0


func _activate_phase_two_if_needed() -> void:
	if _phase_two_active:
		return
	if current_hp > int(float(max_hp) * phase_two_health_ratio):
		return
	_phase_two_active = true
	_attack_lock_timer = 0.0
	_combo_count = 0
	_spawn_shockwave(CAST_COLOR)
	EventBus.notification_requested.emit("%s mengamuk!" % BOSS_NAME)


func _get_speed_multiplier() -> float:
	return phase_two_speed_multiplier if _phase_two_active else 1.0


func _get_cooldown_multiplier() -> float:
	return phase_two_cooldown_multiplier if _phase_two_active else 1.0


func _get_telegraph_multiplier() -> float:
	return 0.78 if _phase_two_active else 1.0


func _update_player_reference() -> void:
	if _has_valid_player():
		return
	_refresh_player_reference()


func _refresh_player_reference() -> bool:
	var candidate := _find_player()
	if _is_player_usable(candidate) and _is_player_in_battle_area(candidate):
		_player = candidate
	if not _is_player_usable(_player):
		_player = null
		return false
	return _is_player_in_battle_area(_player)


func _has_valid_player() -> bool:
	return _is_player_usable(_player) and _is_player_in_battle_area(_player)


func _is_player_usable(player: Variant) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if not player is Node2D:
		return false
	var player_node := player as Node2D
	if not player_node.is_inside_tree() or player_node.is_queued_for_deletion():
		return false
	return true


func _is_player_in_battle_area(player: Variant) -> bool:
	if not _is_player_usable(player):
		return false
	var player_node := player as Node2D
	if player_node == null:
		return false
	if not _arena_enabled:
		return true
	var player_x := player_node.global_position.x
	return player_x >= _arena_left_x and player_x <= _arena_right_x


func _find_player() -> Node2D:
	if not is_inside_tree():
		return null
	var node := get_tree().get_first_node_in_group("player")
	if node is Node2D:
		return node
	return null


func _die() -> void:
	if _dead:
		return
	_set_state(State.DEAD)


func _apply_defeated_state() -> void:
	_dead = true
	_fight_active = false
	_fight_serial = -1
	state = State.DEAD
	current_hp = 0
	velocity = Vector2.ZERO
	_home_position = global_position
	_set_telegraph(false)
	_set_attack_label("")
	_set_body_interaction(false)
	set_physics_process(false)
	visible = false
	modulate.a = 1.0
	if is_instance_valid(visual):
		visual.visible = false
	call_deferred("_set_exit_portal_active", true)


func _enter_dead() -> void:
	_dead = true
	_fight_active = false
	_attack_phase = AttackPhase.NONE
	current_hp = 0
	velocity = Vector2.ZERO
	_poise_damage = 0
	_clear_projectiles()
	_set_telegraph(false)
	_set_attack_label("")
	if is_instance_valid(body_collision):
		body_collision.set_deferred("disabled", true)
	if is_instance_valid(hurtbox):
		hurtbox.set_deferred("monitorable", false)
	if is_instance_valid(slash_area):
		slash_area.set_deferred("monitoring", false)

	health_changed.emit(0, max_hp)
	EventBus.boss_health_changed.emit(0, max_hp)
	EventBus.enemy_killed.emit(self, global_position)
	GameState.finish_boss_fight(boss_id, true, _fight_serial)
	_fight_serial = -1
	EventBus.boss_fight_ended.emit(BOSS_NAME, true)
	EventBus.notification_requested.emit("%s dikalahkan!" % BOSS_NAME)
	if auto_activate_exit_on_death:
		_set_exit_portal_active(true)
	_spawn_drops.call_deferred()
	_spawn_shockwave(STRIKE_COLOR)
	_play_death_effect()


func _on_player_respawned(_at_position: Vector2) -> void:
	if not _fight_active or _dead:
		return

	_fight_active = false
	_clear_projectiles()
	GameState.finish_boss_fight(boss_id, false, _fight_serial)
	_fight_serial = -1
	EventBus.boss_fight_ended.emit(BOSS_NAME, false)
	set_dormant()


func _resolve_node_references() -> void:
	visual = get_node_or_null("Visual") as CanvasItem
	telegraph = get_node_or_null("Telegraph") as Label
	attack_label = get_node_or_null("AttackName") as Label
	body_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	hurtbox = get_node_or_null("Hurtbox") as Area2D
	slash_area = get_node_or_null("SlashArea") as Area2D
	slash_collision = get_node_or_null("SlashArea/CollisionShape2D") as CollisionShape2D


func _configure_body_collision() -> void:
	_set_body_interaction(_fight_active)


func _set_body_interaction(enabled: bool) -> void:
	collision_layer = ENEMY_BODY_LAYER if enabled else 0
	collision_mask = BODY_COLLISION_MASK if enabled else WORLD_LAYER
	if is_instance_valid(hurtbox):
		hurtbox.set_deferred("monitorable", enabled)
	if is_instance_valid(slash_area):
		slash_area.set_deferred("monitoring", enabled)


func _is_valid_spawn_position(candidate_position: Vector2) -> bool:
	if is_nan(candidate_position.x) or is_nan(candidate_position.y):
		return false
	if is_inf(candidate_position.x) or is_inf(candidate_position.y):
		return false
	return true


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
	var origin := global_position
	var search_step := maxf(floor_search_step, 1.0)
	var search_radius := maxf(floor_search_radius, 0.0)
	var offsets: Array[float] = [0.0]
	var distance := search_step
	while distance <= search_radius:
		offsets.append(distance)
		offsets.append(-distance)
		distance += search_step

	for offset in offsets:
		var candidate_x := origin.x + offset
		var floor_y := _find_floor_y(candidate_x, origin.y, max_distance, space, exclude)
		if is_nan(floor_y):
			continue
		var candidate_y := floor_y - body_bottom - floor_snap_clearance
		var candidate := Vector2(candidate_x, candidate_y)
		if _overlaps_world_at(candidate, space, exclude):
			continue
		_place_on_floor(candidate)
		return

	if debug_spawn:
		push_warning(
			"[ForestGuardianBoss] tidak menemukan lantai valid di sekitar %s." % origin
		)


func _find_floor_y(
	x: float,
	reference_y: float,
	max_distance: float,
	space: PhysicsDirectSpaceState2D,
	exclude: Array[RID]
) -> float:
	var down_start := Vector2(x, reference_y)
	var down_query := PhysicsRayQueryParameters2D.create(
		down_start,
		down_start + Vector2.DOWN * max_distance,
		WORLD_LAYER,
		exclude
	)
	down_query.collide_with_areas = false
	down_query.collide_with_bodies = true
	var down_hit := space.intersect_ray(down_query)
	if not down_hit.is_empty():
		var down_normal: Vector2 = down_hit.get("normal", Vector2.ZERO)
		if down_normal.y <= -0.5:
			var down_position: Vector2 = down_hit.get("position", down_start)
			return down_position.y

	var sweep_start := Vector2(x, reference_y - max_distance)
	var sweep_query := PhysicsRayQueryParameters2D.create(
		sweep_start,
		Vector2(x, reference_y + max_distance),
		WORLD_LAYER,
		exclude
	)
	sweep_query.collide_with_areas = false
	sweep_query.collide_with_bodies = true
	var sweep_hit := space.intersect_ray(sweep_query)
	if sweep_hit.is_empty():
		return NAN
	var sweep_normal: Vector2 = sweep_hit.get("normal", Vector2.ZERO)
	if sweep_normal.y > -0.5:
		return NAN
	var sweep_position: Vector2 = sweep_hit.get("position", sweep_start)
	return sweep_position.y


func _place_on_floor(candidate: Vector2) -> void:
	global_position = candidate
	velocity = Vector2.ZERO
	if not _is_valid_spawn_position(global_position):
		global_position = _home_position
	_home_position = global_position
	if debug_spawn:
		print(
			"[ForestGuardianBoss] floor snap global_position=%s home=%s"
			% [global_position, _home_position]
		)


func _overlaps_world_at(
	candidate_position: Vector2,
	space: PhysicsDirectSpaceState2D,
	exclude: Array[RID]
) -> bool:
	if not is_instance_valid(body_collision) or body_collision.shape == null:
		return false

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body_collision.shape
	var shape_transform := body_collision.global_transform
	shape_transform.origin += candidate_position - global_position
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
	return 48.0


func _configure_areas() -> void:
	if is_instance_valid(hurtbox):
		hurtbox.collision_layer = HURTBOX_LAYER
		hurtbox.collision_mask = 0
		hurtbox.monitoring = false
		hurtbox.monitorable = _fight_active

	if not is_instance_valid(slash_area):
		return

	slash_area.collision_layer = 0
	slash_area.collision_mask = PLAYER_BODY_LAYER
	slash_area.monitoring = _fight_active
	slash_area.monitorable = false

	if is_instance_valid(slash_collision):
		var shape := slash_collision.shape
		if shape is RectangleShape2D:
			var rectangle := (shape as RectangleShape2D).duplicate() as RectangleShape2D
			rectangle.size = Vector2(maxf(slash_range, 1.0), maxf(slash_height, 1.0))
			slash_collision.shape = rectangle
	_update_slash_area_position()


func _set_facing(direction: float) -> void:
	if is_zero_approx(direction):
		return
	facing = signf(direction)
	if is_instance_valid(visual):
		visual.scale.x = facing
	_update_slash_area_position()


func _update_slash_area_position() -> void:
	if is_instance_valid(slash_area):
		slash_area.position.x = facing * slash_range * 0.5


func _set_telegraph(show_telegraph: bool) -> void:
	if not is_instance_valid(telegraph):
		return
	telegraph.visible = show_telegraph
	if show_telegraph:
		telegraph.scale = Vector2.ONE
		telegraph.modulate.a = 1.0


func _set_attack_label(text: String) -> void:
	if not is_instance_valid(attack_label):
		return
	attack_label.text = text
	attack_label.visible = not text.is_empty()


func _refresh_visual() -> void:
	if not is_instance_valid(visual):
		return

	visual.visible = true
	visual.modulate.a = 1.0

	if _hit_flash_timer > 0.0:
		visual.modulate = HIT_COLOR
		return

	match state:
		State.INTRO:
			visual.modulate = WARNING_COLOR
		State.SLASH:
			match _attack_phase:
				AttackPhase.WINDUP:
					visual.modulate = WARNING_COLOR
				AttackPhase.ACTIVE:
					visual.modulate = STRIKE_COLOR
				_:
					visual.modulate = Color.WHITE
		State.LEAP:
			visual.modulate = STRIKE_COLOR if _attack_phase == AttackPhase.ACTIVE else WARNING_COLOR
		State.DASH:
			match _attack_phase:
				AttackPhase.ACTIVE:
					visual.modulate = STRIKE_COLOR
				AttackPhase.RECOVERY:
					visual.modulate = Color.WHITE
				_:
					visual.modulate = WARNING_COLOR
		State.PROJECTILE:
			visual.modulate = CAST_COLOR if _attack_phase == AttackPhase.ACTIVE else WARNING_COLOR
		State.GROUND_WAVE:
			visual.modulate = STRIKE_COLOR if _attack_phase == AttackPhase.ACTIVE else WARNING_COLOR
		State.ENERGY_THROW:
			visual.modulate = CAST_COLOR if _attack_phase == AttackPhase.ACTIVE else WARNING_COLOR
		State.HURT:
			visual.modulate = HIT_COLOR
		_:
			visual.modulate = Color.WHITE


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var default_gravity := float(
		ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	)
	velocity.y += default_gravity * gravity_scale * delta


func _decelerate(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)


func _enforce_arena_bounds() -> void:
	if not _arena_enabled or _dead:
		return

	var clamped_x := clampf(global_position.x, _arena_left_x, _arena_right_x)
	if is_equal_approx(global_position.x, clamped_x):
		return

	global_position.x = clamped_x
	velocity.x = 0.0


func _spawn_shockwave(effect_color: Color) -> void:
	var parent := _resolve_attack_parent()
	if parent == null:
		return

	var effect := Line2D.new()
	effect.width = 4.0
	effect.default_color = effect_color
	effect.z_index = 4
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(Vector2(cos(angle), sin(angle)) * 22.0)
	effect.points = points

	parent.add_child(effect)
	effect.global_position = global_position + Vector2(0.0, 40.0)
	var tween := effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2(3.0, 1.2), 0.3)
	tween.tween_property(effect, "modulate:a", 0.0, 0.3)
	tween.finished.connect(effect.queue_free)


func _clear_projectiles() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	for projectile in tree.get_nodes_in_group("forest_guardian_projectile"):
		if is_instance_valid(projectile):
			projectile.queue_free()


func _spawn_drops() -> void:
	if drop_table == null:
		return
	var parent := get_parent()
	if parent == null or parent.is_queued_for_deletion():
		return
	ItemDropSpawner.spawn_table(drop_table, parent, global_position + drop_spawn_offset)


func _set_exit_portal_active(enabled: bool) -> void:
	var portal := _find_exit_portal()
	if portal == null:
		return

	if enabled:
		if portal.has_method("activate"):
			portal.call("activate", true)
			return
		if portal.has_method("open_gate"):
			portal.call("open_gate", true)
			return
		if portal is CanvasItem:
			(portal as CanvasItem).visible = true
		if "monitoring" in portal:
			portal.set("monitoring", true)
		if "monitorable" in portal:
			portal.set("monitorable", true)
		if portal.has_node("CollisionShape2D"):
			var col := portal.get_node("CollisionShape2D")
			if col is CollisionShape2D:
				col.set_deferred("disabled", false)
		return

	if portal.has_method("deactivate"):
		portal.call("deactivate", false)
		return
	if portal.has_method("close_gate"):
		portal.call("close_gate", false)
		return
	if portal is CanvasItem:
		(portal as CanvasItem).visible = false
	if "monitoring" in portal:
		portal.set("monitoring", false)
	if "monitorable" in portal:
		portal.set("monitorable", false)
	if portal.has_node("CollisionShape2D"):
		var col := portal.get_node("CollisionShape2D")
		if col is CollisionShape2D:
			col.set_deferred("disabled", true)


func _find_exit_portal() -> Node:
	if is_instance_valid(_exit_portal) and not _exit_portal.is_queued_for_deletion():
		return _exit_portal

	_exit_portal = null
	if not exit_portal_path.is_empty():
		var path_portal := get_node_or_null(exit_portal_path)
		if _is_valid_exit_portal(path_portal):
			_exit_portal = path_portal
			return _exit_portal

	if exit_portal_group.is_empty() or not is_inside_tree():
		return null

	for node in get_tree().get_nodes_in_group(exit_portal_group):
		if not _is_valid_exit_portal(node):
			continue
		if not _exit_portal_matches_boss(node):
			continue
		_exit_portal = node
		break
	return _exit_portal


func _is_valid_exit_portal(candidate: Variant) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if not candidate is Node:
		return false
	var node := candidate as Node
	return node.is_inside_tree() and not node.is_queued_for_deletion()


func _exit_portal_matches_boss(portal: Node) -> bool:
	var required_value: Variant = portal.get("required_boss_id")
	if required_value == null:
		return true
	var required := String(required_value).strip_edges()
	return required.is_empty() or required == boss_id


func _play_death_effect() -> void:
	if not is_instance_valid(visual):
		queue_free()
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "modulate:a", 0.0, 0.8)
	tween.tween_property(self, "scale", Vector2(1.2, 0.2), 0.8)
	tween.finished.connect(queue_free)
