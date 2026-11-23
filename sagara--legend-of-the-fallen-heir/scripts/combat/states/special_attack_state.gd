extends PlayerState

const FALLBACK_DURATION := 0.35
const MIN_DURATION := 0.05

var _skill: SpecialSkillData
var _elapsed: float = 0.0
var _duration: float = FALLBACK_DURATION
var _windup: float = 0.0
var _damage: int = 0
var _effect_spawned: bool = false


func enter(_previous_state: StringName, data: Dictionary = {}) -> void:
	_elapsed = 0.0
	_effect_spawned = false
	_damage = 0
	_skill = data.get("skill") as SpecialSkillData
	if _skill == null and player != null:
		_skill = player.get_current_special_skill()

	if _skill == null:
		_duration = FALLBACK_DURATION
		_windup = 0.0
		return

	_duration = maxf(_skill.get_total_duration(), MIN_DURATION)
	_windup = clampf(_skill.windup_time, 0.0, _duration)
	_damage = player.get_special_damage(_skill)
	player.restore_visual_color()
	player.set_visual_color(_skill.effect_color)
	player.play_special_animation(_skill)


func physics_update(delta: float) -> void:
	if player == null or state_machine == null:
		return

	player.apply_gravity(delta)

	if _effect_spawned and player.can_start_dodge() and player.consume_dodge_buffer():
		state_machine.transition_to(&"Dodge")
		return

	var deceleration := (
		player.ground_deceleration if player.is_on_floor() else player.air_deceleration
	)
	player.velocity.x = move_toward(player.velocity.x, 0.0, deceleration * delta)

	_elapsed += delta
	if not _effect_spawned and _elapsed >= _windup:
		_spawn_effect()

	player.move_and_slide()

	if _elapsed < _duration:
		return

	var next_state := &"Idle" if player.is_on_floor() else &"Fall"
	state_machine.transition_to(next_state)


func _spawn_effect() -> void:
	_effect_spawned = true
	if _skill == null or player == null or player.combat == null or _damage <= 0:
		return
	var used := player.combat.use_special_skill(_skill, _damage, player.facing)
	if used:
		JuiceFX.special_skill(_skill.effect_color, _skill.damage_multiplier / 2.0)


func exit() -> void:
	if player != null:
		player.restore_visual_color()
