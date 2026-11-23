extends PlayerState

const FALLBACK_DURATION := 0.2
const FALLBACK_HITBOX_START := 0.04
const FALLBACK_HITBOX_LIFETIME := 0.1
const FALLBACK_COMBO_START := 0.06
const FALLBACK_COMBO_END := 0.18
const ATTACK_COLOR := Color(1.0, 0.1, 0.1, 1.0)

var _elapsed: float = 0.0
var _duration: float = FALLBACK_DURATION
var _combo_index: int = 0
var _combo_queued: bool = false
var _hitbox_spawned: bool = false
var _hitbox_deactivated: bool = false
var _step: AttackStepData
var _combo_window_start: float = FALLBACK_COMBO_START
var _combo_window_end: float = FALLBACK_COMBO_END
var _hitbox_start_time: float = FALLBACK_HITBOX_START
var _hitbox_lifetime: float = FALLBACK_HITBOX_LIFETIME
var _hitbox_deactivate_time: float = FALLBACK_HITBOX_START + FALLBACK_HITBOX_LIFETIME


func enter(_previous_state: StringName, data: Dictionary = {}) -> void:
	var requested_index := int(data.get("combo_index", player.get_attack_combo_index()))
	player.begin_attack_step(requested_index)
	_combo_index = player.get_attack_combo_index()
	_step = player.get_current_attack_step()
	_combo_queued = false
	_hitbox_spawned = false
	_hitbox_deactivated = false
	_elapsed = 0.0

	var speed := player.get_attack_speed_multiplier()
	var base_duration := _step.duration if _step != null else FALLBACK_DURATION
	_duration = maxf(base_duration / speed, 0.05)
	_combo_window_start = (
		_step.combo_window_start if _step != null else FALLBACK_COMBO_START
	) / speed
	_combo_window_end = minf(
		(_step.combo_window_end if _step != null else FALLBACK_COMBO_END) / speed,
		_duration
	)
	_hitbox_start_time = minf(
		(_step.hitbox_start_time if _step != null else FALLBACK_HITBOX_START) / speed,
		maxf(_duration - 0.01, 0.0)
	)
	_hitbox_lifetime = minf(
		(_step.hitbox_lifetime if _step != null else FALLBACK_HITBOX_LIFETIME) / speed,
		maxf(_duration - _hitbox_start_time, 0.01)
	)
	_hitbox_deactivate_time = _hitbox_start_time + _hitbox_lifetime
	player.clear_attack_buffer()
	player.restore_visual_color()
	player.set_visual_color(ATTACK_COLOR)
	player.play_attack_animation(_combo_index)


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)

	if player.can_start_dodge() and player.consume_dodge_buffer():
		state_machine.transition_to(&"Dodge")
		return

	if player.try_start_special_attack():
		return

	if (
		player.has_attack_buffer()
		and _elapsed >= _combo_window_start
		and _elapsed <= _combo_window_end
	):
		_combo_queued = true
		player.clear_attack_buffer()

	if not _hitbox_spawned and _elapsed >= _hitbox_start_time:
		_hitbox_spawned = true
		_spawn_attack()

	if (
		_hitbox_spawned
		and not _hitbox_deactivated
		and _elapsed >= _hitbox_deactivate_time
	):
		_hitbox_deactivated = true
		player.deactivate_weapon_hitbox()

	var deceleration := (
		player.ground_deceleration if player.is_on_floor() else player.air_deceleration
	)
	player.velocity.x = move_toward(player.velocity.x, 0.0, deceleration * delta)
	_elapsed += delta
	player.move_and_slide()

	if _elapsed < _duration:
		return

	if _combo_queued and _combo_index + 1 < player.get_weapon_combo_count():
		state_machine.transition_to(
			&"Attack",
			{"combo_index": _combo_index + 1, "force_restart": true}
		)
		return

	player.finish_attack_step()
	var next_state := &"Idle" if player.is_on_floor() else &"Fall"
	state_machine.transition_to(next_state)


func _spawn_attack() -> void:
	player.activate_weapon_hitbox(_step, _hitbox_lifetime)
	player.show_attack_effect(maxf(_duration * 0.7, 0.08), _combo_index)
	if _combo_index >= maxi(player.get_weapon_combo_count() - 1, 0):
		JuiceFX.heavy_slash()


func exit() -> void:
	if player != null:
		player.deactivate_weapon_hitbox()
		player.restore_visual_color()
