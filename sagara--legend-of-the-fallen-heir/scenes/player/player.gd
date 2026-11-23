class_name SagaraPlayer
extends CharacterBody2D

enum Stance {
	HARIMAU,
	ELANG,
	ULAR,
}

const HARIMAU_DAMAGE_MULTIPLIER := 1.5
const ELANG_SPEED_MULTIPLIER := 1.25
const ELANG_ATTACK_SPEED_MULTIPLIER := 1.5
const DOUBLE_JUMP_COLOR := Color(0.55, 0.9, 1.0, 1.0)
const DAMAGE_FLASH_COLOR := Color(1.0, 0.2, 0.2, 0.35)
const DAMAGE_FLASH_INTERVAL := 0.1
const DAMAGE_KNOCKBACK_FORCE := 320.0
const DAMAGE_KNOCKBACK_LIFT := -180.0
const KNOCKBACK_DURATION := 0.18
const CURSE_DAMAGE_MULTIPLIER := 2.0
const CURSE_KILLS_TO_CLEANSE := 10
const ANTIGRAV_FLOOR_DETACH_SPEED := 60.0

@export_group("Movement")
@export var move_speed: float = 250.0
@export var ground_acceleration: float = 2400.0
@export var ground_deceleration: float = 2600.0
@export var air_acceleration: float = 1600.0
@export var air_deceleration: float = 900.0
@export var jump_velocity: float = -400.0
@export var gravity_scale: float = 1.0
@export_range(0.0, 0.5, 0.01) var coyote_time: float = 0.15
@export_range(0.0, 0.5, 0.01) var jump_buffer_time: float = 0.12
@export_range(0.0, 0.5, 0.01) var attack_buffer_time: float = 0.18
@export_range(0.0, 0.5, 0.01) var dodge_buffer_time: float = 0.14
@export_range(0.0, 0.5, 0.01) var parry_buffer_time: float = 0.12
@export_range(0.0, 0.5, 0.01) var special_buffer_time: float = 0.18
@export var wall_slide_speed: float = 70.0
@export var wall_jump_velocity: float = -380.0
@export var wall_jump_push: float = 340.0
@export_range(0.0, 1.0, 0.01) var wall_jump_lock_time: float = 0.12
@export var climb_speed: float = 105.0
@export_range(0.0, 1.0, 0.01) var climb_horizontal_multiplier: float = 0.55

@export_group("Combat")
@export var current_weapon: WeaponData
@export var dodge_data: DodgeData
@export_range(0.0, 2.0, 0.01) var combo_reset_time: float = 0.65
@export_range(0.0, 5.0, 0.05) var invincibility_duration: float = 1.0
@export_range(0.0, 5.0, 0.05) var special_cooldown: float = 0.6

@export_group("Status")
@export_range(0.0, 2.0, 0.05) var boss_stun_duration: float = 0.65

@onready var visual: ColorRect = $ColorRect
@onready var attack_effect: Node2D = $AttackEffect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var combat: PlayerCombat = $Combat
@onready var weapon_hitbox: WeaponHitbox = get_node_or_null("Combat/WeaponHitbox") as WeaponHitbox
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var stun_indicator: StunIndicator = get_node_or_null("StunIndicator") as StunIndicator

var stance: Stance = Stance.HARIMAU
var facing: float = 1.0
var spawn_position: Vector2 = Vector2.ZERO

var environmental_force: Vector2 = Vector2.ZERO
var _climb_contacts: Array[Node] = []
var _wind_sources: Dictionary = {}
var _gravity_sources: Dictionary = {}
var _effective_gravity_scale: float = 1.0
var _antigrav_upward_acceleration: float = 0.0
var _antigrav_max_rise_speed: float = 0.0
var _antigrav_vertical_damping: float = 0.0
var _pull_toward_center: bool = false
var _pull_strength: float = 0.0
var _gravity_center: Vector2 = Vector2.ZERO

var combo_step: int = 0
var combo_reset_timer: float = 0.0

var jump_buffer_timer: float = 0.0
var attack_buffer_timer: float = 0.0
var dodge_buffer_timer: float = 0.0
var parry_buffer_timer: float = 0.0
var special_buffer_timer: float = 0.0

var coyote_timer: float = 0.0
var wall_jump_lock_timer: float = 0.0
var double_jump_used: bool = false

var attack_cooldown_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var parry_cooldown_timer: float = 0.0
var special_cooldown_timer: float = 0.0

var knockback_timer: float = 0.0
var knockback_direction: float = 1.0
var knockback_force: float = DAMAGE_KNOCKBACK_FORCE

var stunned: bool = false
var stun_timer: float = 0.0

var invincibility_timer: float = 0.0
var invincible: bool = false
var damage_flash_timer: float = 0.0
var damage_flash_on: bool = false

var attack_damage_bonus: int = 0
var damage_multiplier: float = 1.0
var is_cursed: bool = false
var curse_kill_count: int = 0

var _original_color: Color = Color.WHITE
var _original_collision_shape: Shape2D
var _original_collision_position: Vector2 = Vector2.ZERO
var _original_collision_scale: Vector2 = Vector2.ONE
var _last_dodge_ready: bool = true
var _attack_effect_generation: int = 0


func _ready() -> void:
	if current_weapon == null:
		current_weapon = WeaponData.new()
	if dodge_data == null:
		dodge_data = DodgeData.new()

	reset_combo()
	_apply_pending_spawn_tag()
	spawn_position = global_position
	if visual != null:
		_original_color = visual.color

	if collision_shape != null:
		_original_collision_shape = collision_shape.shape
		_original_collision_position = collision_shape.position
		_original_collision_scale = collision_shape.scale

	GameState.set_health(GameState.current_health, false)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	state_machine.initialize(self)
	_sync_dodge_ready(true)


func _apply_pending_spawn_tag() -> void:
	if not is_instance_valid(LevelTransition):
		return
	var spawn_tag := LevelTransition.consume_spawn_tag()
	if spawn_tag.is_empty():
		return

	var marker := _find_spawn_marker(spawn_tag)
	if marker == null:
		push_warning("SagaraPlayer: spawn marker '%s' tidak ditemukan." % spawn_tag)
		return

	global_position = marker.global_position
	velocity = Vector2.ZERO
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reset_smoothing()


func _find_spawn_marker(spawn_tag: String) -> Node2D:
	for node in get_tree().get_nodes_in_group("level_spawn"):
		if node is Node2D and (
			String(node.name) == spawn_tag
			or String(node.get_meta("spawn_tag", "")) == spawn_tag
		):
			return node as Node2D
	return null


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_invincibility(delta)
	_update_ground_state(delta)

	if stunned:
		_update_stun(delta)
		_sync_dodge_ready()
		return

	_update_input_buffers(delta)

	if knockback_timer > 0.0:
		_update_knockback(delta)
		_sync_dodge_ready()
		return

	state_machine.physics_update(delta)
	_sync_dodge_ready()


func _unhandled_input(event: InputEvent) -> void:
	if stunned:
		return

	if event.is_action_pressed("switch_stance"):
		switch_stance()
		return

	if event.is_action_pressed("special_attack"):
		_queue_special_input()
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_queue_special_input()


func _queue_special_input() -> void:
	special_buffer_timer = maxf(special_buffer_timer, special_buffer_time)


func _update_input_buffers(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_pressed("attack"):
		attack_buffer_timer = attack_buffer_time
	if Input.is_action_just_pressed("roll"):
		dodge_buffer_timer = dodge_buffer_time
	if Input.is_action_just_pressed("parry"):
		parry_buffer_timer = parry_buffer_time
	if Input.is_action_just_pressed("special_attack"):
		_queue_special_input()

	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	attack_buffer_timer = maxf(attack_buffer_timer - delta, 0.0)
	dodge_buffer_timer = maxf(dodge_buffer_timer - delta, 0.0)
	parry_buffer_timer = maxf(parry_buffer_timer - delta, 0.0)
	special_buffer_timer = maxf(special_buffer_timer - delta, 0.0)


func _update_timers(delta: float) -> void:
	attack_cooldown_timer = maxf(attack_cooldown_timer - delta, 0.0)
	dodge_cooldown_timer = maxf(dodge_cooldown_timer - delta, 0.0)
	parry_cooldown_timer = maxf(parry_cooldown_timer - delta, 0.0)
	special_cooldown_timer = maxf(special_cooldown_timer - delta, 0.0)
	wall_jump_lock_timer = maxf(wall_jump_lock_timer - delta, 0.0)
	_update_combo_timer(delta)


func _update_combo_timer(delta: float) -> void:
	if state_machine.current_state_name == &"Attack":
		return
	if combo_reset_timer <= 0.0:
		if combo_step != 0:
			reset_combo()
		return
	combo_reset_timer = maxf(combo_reset_timer - delta, 0.0)
	if combo_reset_timer <= 0.0 and combo_step != 0:
		reset_combo()


func _update_ground_state(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
		double_jump_used = false
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)


func _update_knockback(delta: float) -> void:
	knockback_timer = maxf(knockback_timer - delta, 0.0)
	velocity.x = knockback_direction * knockback_force
	apply_gravity(delta)
	move_and_slide()


func _update_stun(delta: float) -> void:
	stun_timer = maxf(stun_timer - delta, 0.0)

	if knockback_timer > 0.0:
		_update_knockback(delta)
	else:
		var deceleration := ground_deceleration if is_on_floor() else air_deceleration
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		apply_gravity(delta)
		move_and_slide()

	if stun_timer <= 0.0:
		_end_stun()


func _begin_stun(duration: float) -> void:
	if duration <= 0.0:
		return
	stunned = true
	stun_timer = maxf(stun_timer, duration)
	_clear_input_buffers()
	deactivate_weapon_hitbox()
	state_machine.transition_to(&"Idle", {"force_restart": true})
	if stun_indicator != null:
		stun_indicator.show_stun()


func _end_stun() -> void:
	if not stunned:
		return
	stunned = false
	stun_timer = 0.0
	knockback_timer = 0.0
	_clear_input_buffers()
	if stun_indicator != null:
		stun_indicator.hide_stun()
	state_machine.transition_to(&"Idle", {"force_restart": true})


func _reset_stun_state() -> void:
	stunned = false
	stun_timer = 0.0
	if stun_indicator != null:
		stun_indicator.hide_stun()


func _clear_input_buffers() -> void:
	jump_buffer_timer = 0.0
	attack_buffer_timer = 0.0
	dodge_buffer_timer = 0.0
	parry_buffer_timer = 0.0
	special_buffer_timer = 0.0


func _update_invincibility(delta: float) -> void:
	if not invincible:
		return
	invincibility_timer -= delta
	damage_flash_timer -= delta
	if damage_flash_timer <= 0.0:
		damage_flash_timer = DAMAGE_FLASH_INTERVAL
		damage_flash_on = not damage_flash_on
		if visual != null:
			visual.modulate = DAMAGE_FLASH_COLOR if damage_flash_on else Color.WHITE
	if invincibility_timer <= 0.0:
		invincible = false
		if visual != null:
			visual.modulate = Color.WHITE


func get_gravity_force() -> float:
	var default_gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	return default_gravity * gravity_scale


func get_move_axis() -> float:
	return Input.get_axis("move_left", "move_right")


func is_down_pressed() -> bool:
	return Input.is_action_pressed("down")


func get_move_speed() -> float:
	var speed_multiplier := ELANG_SPEED_MULTIPLIER if stance == Stance.ELANG else 1.0
	return move_speed * speed_multiplier


func get_stance_damage_multiplier() -> float:
	return HARIMAU_DAMAGE_MULTIPLIER if stance == Stance.HARIMAU else 1.0


func get_attack_speed_multiplier() -> float:
	var stance_multiplier := ELANG_ATTACK_SPEED_MULTIPLIER if stance == Stance.ELANG else 1.0
	var weapon_speed := current_weapon.attack_speed if current_weapon != null else 1.0
	return maxf(weapon_speed * stance_multiplier, 0.01)


func get_attack_cooldown() -> float:
	var cooldown := current_weapon.cooldown if current_weapon != null else 0.2
	return cooldown / get_attack_speed_multiplier()


func get_attack_range() -> float:
	return maxf(current_weapon.range_px if current_weapon != null else 1.0, 1.0)


func get_weapon_combo_count() -> int:
	if current_weapon == null:
		return 1
	return current_weapon.get_combo_count()


func get_weapon_combo_step(index: int) -> AttackStepData:
	if current_weapon == null:
		return null
	return current_weapon.get_combo_step(index)


func get_attack_combo_index() -> int:
	return clampi(combo_step, 0, maxi(get_weapon_combo_count() - 1, 0))


func get_current_attack_step() -> AttackStepData:
	return get_weapon_combo_step(get_attack_combo_index())


func get_attack_damage(step: AttackStepData = null) -> int:
	var step_multiplier := step.damage_multiplier if step != null else 1.0
	var weapon_damage := current_weapon.damage if current_weapon != null else 1.0
	var raw_damage := weapon_damage + float(attack_damage_bonus) + float(GameState.get_calculated_attack_power())
	raw_damage *= get_stance_damage_multiplier()
	raw_damage *= step_multiplier
	raw_damage *= damage_multiplier
	return maxi(roundi(raw_damage), 1)


func get_current_special_skill() -> SpecialSkillData:
	if current_weapon == null:
		return null
	return current_weapon.get_special_skill(stance == Stance.ELANG)


func get_special_damage(skill: SpecialSkillData) -> int:
	if skill == null:
		return 0
	var weapon_damage := current_weapon.damage if current_weapon != null else 1.0
	var raw_damage := weapon_damage + float(attack_damage_bonus) + float(GameState.get_calculated_attack_power())
	raw_damage *= get_stance_damage_multiplier()
	raw_damage *= maxf(skill.damage_multiplier, 0.0)
	raw_damage *= damage_multiplier
	return maxi(roundi(raw_damage), 1)


func get_dive_damage() -> int:
	var weapon_damage := current_weapon.damage if current_weapon != null else 1.0
	var raw_damage := weapon_damage + 1.0 + float(attack_damage_bonus) + float(GameState.get_calculated_attack_power())
	raw_damage *= damage_multiplier
	return maxi(roundi(raw_damage), 1)


func begin_attack_step(index: int) -> void:
	combo_step = clampi(index, 0, maxi(get_weapon_combo_count() - 1, 0))
	combo_reset_timer = combo_reset_time
	attack_cooldown_timer = get_attack_cooldown()
	play_attack_animation(combo_step)


func finish_attack_step() -> void:
	var count := get_weapon_combo_count()
	if count <= 1:
		reset_combo()
		return
	combo_step = (get_attack_combo_index() + 1) % count
	combo_reset_timer = combo_reset_time


func reset_combo() -> void:
	combo_step = 0
	combo_reset_timer = 0.0


func apply_gravity(delta: float) -> void:
	var effective_gravity := get_gravity_force() * _effective_gravity_scale
	var has_lift := (
		_antigrav_upward_acceleration > 0.0
		and _antigrav_max_rise_speed > 0.0
	)
	if not is_on_floor():
		velocity.y += effective_gravity * delta
	if has_lift:
		if is_on_floor():
			if _antigrav_upward_acceleration > effective_gravity:
				velocity.y = minf(velocity.y, -ANTIGRAV_FLOOR_DETACH_SPEED)
		elif velocity.y > -_antigrav_max_rise_speed:
			velocity.y = move_toward(
				velocity.y,
				-_antigrav_max_rise_speed,
				_antigrav_upward_acceleration * delta
			)
		if velocity.y > 0.0 and _antigrav_vertical_damping > 0.0:
			velocity.y = move_toward(
				velocity.y, 0.0, _antigrav_vertical_damping * delta
			)
	if _pull_toward_center and _pull_strength > 0.0:
		var offset := _gravity_center - global_position
		if offset.length_squared() > 0.0001:
			velocity += offset.normalized() * _pull_strength * delta
	if not environmental_force.is_zero_approx():
		velocity.y += environmental_force.y * delta


func update_horizontal(axis: float, delta: float, grounded: bool = true) -> void:
	if not is_zero_approx(axis):
		facing = signf(axis)

	if wall_jump_lock_timer > 0.0:
		return

	var target_speed := axis * get_move_speed()
	var rate := 0.0
	if grounded:
		rate = ground_acceleration if not is_zero_approx(axis) else ground_deceleration
	else:
		rate = air_acceleration if not is_zero_approx(axis) else air_deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	velocity.x += environmental_force.x * delta


func perform_jump() -> void:
	velocity.y = jump_velocity
	coyote_timer = 0.0
	double_jump_used = false


func perform_double_jump() -> void:
	velocity.y = jump_velocity
	double_jump_used = true
	coyote_timer = 0.0
	combat.spawn_ring(18.0, 27.0, DOUBLE_JUMP_COLOR, 0.24)


func can_double_jump() -> bool:
	return stance == Stance.ELANG and not double_jump_used


func perform_wall_jump() -> void:
	var push_direction := get_wall_normal().x
	if is_zero_approx(push_direction):
		push_direction = -facing
	velocity.x = push_direction * wall_jump_push
	velocity.y = wall_jump_velocity
	wall_jump_lock_timer = wall_jump_lock_time
	facing = 1.0 if push_direction > 0.0 else -1.0
	coyote_timer = 0.0
	double_jump_used = false


func is_wall_sliding() -> bool:
	return not is_on_floor() and is_on_wall() and velocity.y > 0.0


func add_climb_contact(source: Node) -> void:
	if not is_instance_valid(source) or _climb_contacts.has(source):
		return
	_climb_contacts.append(source)


func remove_climb_contact(source: Node) -> void:
	_climb_contacts.erase(source)


func is_climbing_available() -> bool:
	for source in _climb_contacts.duplicate():
		if not is_instance_valid(source):
			_climb_contacts.erase(source)
	return not _climb_contacts.is_empty()


func is_climb_input_pressed() -> bool:
	return Input.is_action_pressed("jump") or Input.is_action_pressed("down")


func is_climb_up_pressed() -> bool:
	return Input.is_action_pressed("jump")


func add_wind_source(source: Node, force: Vector2) -> void:
	if not is_instance_valid(source):
		return
	_wind_sources[source] = force
	_recalculate_environmental_force()


func remove_wind_source(source: Node) -> void:
	_wind_sources.erase(source)
	_recalculate_environmental_force()


func _recalculate_environmental_force() -> void:
	var total := Vector2.ZERO
	var stale_sources: Array = []
	for source in _wind_sources.keys():
		if not is_instance_valid(source):
			stale_sources.append(source)
			continue
		total += Vector2(_wind_sources[source])
	for source in stale_sources:
		_wind_sources.erase(source)
	environmental_force = total


func add_gravity_source(_source: Node, data: Dictionary) -> void:
	_gravity_sources[_source] = data
	_recalculate_gravity()


func remove_gravity_source(_source: Node) -> void:
	_gravity_sources.erase(_source)
	_recalculate_gravity()


func _recalculate_gravity() -> void:
	_effective_gravity_scale = 1.0
	_antigrav_upward_acceleration = 0.0
	_antigrav_max_rise_speed = 0.0
	_antigrav_vertical_damping = 0.0
	_pull_toward_center = false
	_pull_strength = 0.0
	_gravity_center = global_position
	for data in _gravity_sources.values():
		if not data is Dictionary:
			continue
		var source := data as Dictionary
		_effective_gravity_scale = minf(
			_effective_gravity_scale,
			float(source.get("gravity_scale", 1.0))
		)
		var lift := maxf(float(source.get("upward_acceleration", 0.0)), 0.0)
		if lift > _antigrav_upward_acceleration:
			_antigrav_upward_acceleration = lift
			_antigrav_max_rise_speed = maxf(
				float(source.get("max_rise_speed", 0.0)), 0.0
			)
			_antigrav_vertical_damping = maxf(
				float(source.get("vertical_damping", 0.0)), 0.0
			)
			var lift_center: Variant = source.get("center_position", global_position)
			if lift_center is Vector2:
				_gravity_center = lift_center
		if bool(source.get("pull_toward_center", false)):
			var pull_value: Variant = source.get("pull_strength", 0.0)
			var pull_amount := 0.0
			if pull_value is Vector2:
				pull_amount = (pull_value as Vector2).length()
			else:
				pull_amount = maxf(float(pull_value), 0.0)
			if pull_amount > _pull_strength:
				_pull_toward_center = true
				_pull_strength = pull_amount
				var pull_center: Variant = source.get("center_position", global_position)
				if pull_center is Vector2:
					_gravity_center = pull_center


func has_jump_buffer() -> bool:
	return jump_buffer_timer > 0.0


func consume_jump_buffer() -> bool:
	if jump_buffer_timer <= 0.0:
		return false
	jump_buffer_timer = 0.0
	return true


func has_attack_buffer() -> bool:
	return attack_buffer_timer > 0.0


func consume_attack_buffer() -> bool:
	if attack_buffer_timer <= 0.0:
		return false
	attack_buffer_timer = 0.0
	return true


func clear_attack_buffer() -> void:
	attack_buffer_timer = 0.0


func try_start_attack() -> bool:
	if not has_attack_buffer() or not can_start_attack():
		return false
	consume_attack_buffer()
	state_machine.transition_to(
		&"Attack",
		{"combo_index": get_attack_combo_index(), "force_restart": true}
	)
	return true


func has_special_buffer() -> bool:
	return special_buffer_timer > 0.0


func consume_special_buffer() -> bool:
	if special_buffer_timer <= 0.0:
		return false
	special_buffer_timer = 0.0
	return true


func can_start_special() -> bool:
	return (
		not stunned
		and special_cooldown_timer <= 0.0
		and knockback_timer <= 0.0
		and state_machine.current_state_name != &"Dodge"
		and state_machine.current_state_name != &"Dive"
		and state_machine.current_state_name != &"Special"
	)


func try_start_special_attack() -> bool:
	if not has_special_buffer() or not can_start_special():
		return false

	var skill := get_current_special_skill()
	if skill == null:
		consume_special_buffer()
		show_message("SKILL SPESIAL TIDAK TERSEDIA")
		EventBus.special_skill_failed.emit("skill")
		return false

	if not GameState.has_special_energy(skill.energy_cost):
		consume_special_buffer()
		show_message("ENERGI JIWA TIDAK CUKUP")
		EventBus.special_skill_failed.emit("energy")
		return false

	consume_special_buffer()
	if not GameState.spend_special_energy(skill.energy_cost):
		show_message("ENERGI JIWA TIDAK CUKUP")
		EventBus.special_skill_failed.emit("energy")
		return false

	special_cooldown_timer = maxf(skill.cooldown, 0.0)
	EventBus.special_skill_used.emit(skill.skill_name, int(skill.style))
	state_machine.transition_to(&"Special", {"skill": skill})
	return true


func consume_dodge_buffer() -> bool:
	if dodge_buffer_timer <= 0.0:
		return false
	dodge_buffer_timer = 0.0
	return true


func consume_parry_buffer() -> bool:
	if parry_buffer_timer <= 0.0:
		return false
	parry_buffer_timer = 0.0
	return true


func can_start_attack() -> bool:
	return (
		not stunned
		and attack_cooldown_timer <= 0.0
		and knockback_timer <= 0.0
	)


func can_start_dodge() -> bool:
	return (
		not stunned
		and dodge_cooldown_timer <= 0.0
		and knockback_timer <= 0.0
		and state_machine.current_state_name != &"Dodge"
	)


func can_parry() -> bool:
	return (
		not stunned
		and stance == Stance.HARIMAU
		and is_on_floor()
		and parry_cooldown_timer <= 0.0
		and knockback_timer <= 0.0
	)


func can_dive() -> bool:
	return not stunned and stance == Stance.ELANG and not is_on_floor()


func start_dodge_cooldown() -> void:
	if dodge_data != null:
		dodge_cooldown_timer = dodge_data.cooldown


func should_start_dive_attack() -> bool:
	return has_attack_buffer() and can_dive() and is_down_pressed()


func enter_dodge_collision() -> void:
	if collision_shape == null or not (_original_collision_shape is RectangleShape2D):
		return
	var source_shape := _original_collision_shape as RectangleShape2D
	var roll_shape := source_shape.duplicate() as RectangleShape2D
	var original_height := source_shape.size.y
	roll_shape.size = Vector2(source_shape.size.x, maxf(original_height * 0.5, 1.0))
	collision_shape.shape = roll_shape
	var height_reduction := original_height * 0.25
	collision_shape.position = _original_collision_position + Vector2(0.0, height_reduction)
	collision_shape.scale = _original_collision_scale


func restore_dodge_collision() -> void:
	if collision_shape == null:
		return
	_restore_dodge_collision_deferred.call_deferred()


func _restore_dodge_collision_deferred() -> void:
	if not is_instance_valid(collision_shape):
		return
	if _original_collision_shape != null:
		collision_shape.shape = _original_collision_shape
	collision_shape.position = _original_collision_position
	collision_shape.scale = _original_collision_scale


func spawn_afterimage(alpha: float, fade_duration: float) -> void:
	var parent := get_parent()
	if parent == null or visual == null:
		return

	var ghost := ColorRect.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 0
	ghost.size = visual.size
	ghost.color = Color(visual.color.r, visual.color.g, visual.color.b, alpha)
	parent.add_child(ghost)
	ghost.global_position = visual.global_position

	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, fade_duration)
	tween.finished.connect(ghost.queue_free)


func show_attack_effect(effect_duration: float, step_index: int = 0) -> void:
	if attack_effect == null:
		return
	_attack_effect_generation += 1
	var generation := _attack_effect_generation
	attack_effect.position = Vector2(facing * 34.0, 0.0)
	attack_effect.visible = true
	var slash := attack_effect.get_node_or_null("Slash")
	if slash is ColorRect:
		var slash_rect := slash as ColorRect
		var clamped_step := clampi(step_index, 0, 2)
		slash_rect.scale = Vector2(1.0 + 0.2 * float(clamped_step), 1.0)
		slash_rect.rotation = deg_to_rad(-12.0 + 12.0 * float(clamped_step))
	var timer := get_tree().create_timer(maxf(effect_duration, 0.01))
	timer.timeout.connect(_hide_attack_effect.bind(generation))


func activate_weapon_hitbox(step: AttackStepData, lifetime: float) -> void:
	if combat == null:
		return
	combat.attack(step, get_attack_damage(step), facing, current_weapon, lifetime)


func deactivate_weapon_hitbox() -> void:
	if combat != null:
		combat.cancel_attack_hitbox()


func is_weapon_hitbox_active() -> bool:
	return weapon_hitbox != null and weapon_hitbox.is_active()


func _hide_attack_effect(generation: int) -> void:
	if generation == _attack_effect_generation and is_instance_valid(attack_effect):
		attack_effect.visible = false


func set_visual_color(color: Color) -> void:
	if visual != null:
		visual.color = color


func restore_visual_color() -> void:
	if visual != null:
		visual.color = _original_color


func play_animation(animation_name: StringName) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	animation_player.play(animation_name)


func play_attack_animation(step_index: int) -> void:
	if animation_player == null:
		return
	var step_animation := StringName("attack_%d" % (clampi(step_index, 0, 2) + 1))
	if animation_player.has_animation(step_animation):
		animation_player.play(step_animation)
		return
	if animation_player.has_animation(&"attack"):
		animation_player.play(&"attack")


func play_special_animation(skill: SpecialSkillData) -> void:
	if skill == null:
		return
	if (
		animation_player != null
		and not String(skill.animation_name).is_empty()
		and animation_player.has_animation(skill.animation_name)
	):
		animation_player.play(skill.animation_name)
		return
	play_animation(&"special")


func stop_animation() -> void:
	if animation_player != null:
		animation_player.stop()


func switch_stance() -> void:
	if stunned:
		return
	var state_name := state_machine.current_state_name
	if state_name == &"Dodge" or state_name == &"Dive":
		return
	if state_name == &"Parry":
		state_machine.transition_to(&"Idle")
	stance = Stance.ELANG if stance == Stance.HARIMAU else Stance.HARIMAU
	if animation_player != null:
		animation_player.speed_scale = get_attack_speed_multiplier()
	var stance_text := "ELANG" if stance == Stance.ELANG else "HARIMAU"
	show_message("STANCE: %s" % stance_text)


func take_damage(amount: int, source: Node = null) -> bool:
	if amount <= 0 or knockback_timer > 0.0:
		return false
	if state_machine.is_current_state_invulnerable() or invincible:
		return false
	if state_machine.try_current_state_parry(source, amount):
		return false
	if is_cursed:
		GameState.reset_health()
		_apply_soul_save_bonus()
		respawn()
		_start_invincibility()
		return true

	var applied := GameState.apply_damage(amount)
	if applied <= 0:
		return false

	if _is_boss_damage(source):
		JuiceFX.player_big_damage(applied)

	if GameState.current_health <= 0:
		GameState.reset_health()
		_apply_soul_save_bonus()
		respawn()
	else:
		restore_visual_color()
		if _is_boss_damage(source):
			_begin_stun(boss_stun_duration)
	_start_invincibility()
	return true


func _is_boss_damage(source: Node) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	if source.has_method("is_fight_active"):
		return true
	return source.is_in_group("boss_attack")


func _apply_soul_save_bonus() -> void:
	if GameState.upgrade_soul_save_level <= 0:
		return
	var saved_souls := int(GameState.total_souls * 0.25)
	GameState.add_souls(saved_souls)


func _start_invincibility() -> void:
	invincible = true
	invincibility_timer = invincibility_duration
	damage_flash_timer = 0.0
	damage_flash_on = true
	if visual != null:
		visual.modulate = DAMAGE_FLASH_COLOR


func apply_knockback(
	direction: float,
	force: float = DAMAGE_KNOCKBACK_FORCE,
	stun_duration: float = 0.0
) -> void:
	if state_machine.is_current_state_invulnerable():
		return
	if is_zero_approx(direction):
		direction = -facing
	knockback_direction = signf(direction)
	if is_zero_approx(knockback_direction):
		knockback_direction = -facing
	knockback_force = force
	knockback_timer = KNOCKBACK_DURATION
	velocity.x = knockback_direction * knockback_force
	velocity.y = DAMAGE_KNOCKBACK_LIFT
	state_machine.transition_to(&"Idle", {"force_restart": true})
	restore_visual_color()
	if stun_duration > 0.0:
		_begin_stun(stun_duration)


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	deactivate_weapon_hitbox()
	reset_combo()
	restore_dodge_collision()
	restore_visual_color()
	if visual != null:
		visual.modulate = Color.WHITE

	_clear_input_buffers()
	_reset_stun_state()
	attack_cooldown_timer = 0.0
	dodge_cooldown_timer = 0.0
	parry_cooldown_timer = 0.0
	special_cooldown_timer = 0.0
	GameState.refill_special_energy()
	wall_jump_lock_timer = 0.0
	knockback_timer = 0.0
	coyote_timer = 0.0
	double_jump_used = false
	invincible = false
	invincibility_timer = 0.0

	state_machine.transition_to(&"Idle", {"force_restart": true})
	EventBus.player_respawned.emit(global_position)
	_sync_dodge_ready(true)


func heal(amount: int) -> void:
	GameState.heal(amount)


func add_souls(amount: int = 1) -> void:
	GameState.add_souls(amount)


func equip_weapon(weapon_name: String, damage_bonus: int) -> void:
	if current_weapon == null:
		return
	var upgraded := current_weapon.duplicate(true) as WeaponData
	if upgraded == null:
		return
	upgraded.weapon_name = weapon_name
	upgraded.damage += float(damage_bonus)
	equip_weapon_data(upgraded, 0, false)


func equip_weapon_data(
	data: WeaponData,
	damage_bonus: int = 0,
	notify: bool = true
) -> void:
	if data == null:
		return
	deactivate_weapon_hitbox()
	reset_combo()
	current_weapon = data
	attack_damage_bonus = maxi(damage_bonus, 0)
	EventBus.weapon_equipped.emit(data)
	if notify:
		show_message("%s diperoleh!" % data.weapon_name)


func apply_curse_buff() -> void:
	is_cursed = true
	curse_kill_count = 0
	damage_multiplier = CURSE_DAMAGE_MULTIPLIER
	if visual == null:
		return
	var tween := create_tween()
	tween.set_loops(6)
	tween.tween_property(visual, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.1)
	tween.tween_property(visual, "modulate", Color.WHITE, 0.1)


func on_enemy_killed() -> void:
	_register_curse_kill()


func _on_enemy_killed(_enemy: Node, _at_position: Vector2) -> void:
	_register_curse_kill()


func _register_curse_kill() -> void:
	if not is_cursed:
		return
	curse_kill_count += 1
	if curse_kill_count < CURSE_KILLS_TO_CLEANSE:
		return
	is_cursed = false
	damage_multiplier = 1.0
	if visual != null:
		visual.modulate = Color.WHITE


func show_message(text: String) -> void:
	if text.is_empty():
		return
	EventBus.notification_requested.emit(text)


func _sync_dodge_ready(force: bool = false) -> void:
	var is_ready := can_start_dodge()
	if not force and is_ready == _last_dodge_ready:
		return
	_last_dodge_ready = is_ready
	EventBus.dodge_ready_changed.emit(is_ready)
