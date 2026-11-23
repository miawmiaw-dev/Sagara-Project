extends PlayerState

var _elapsed: float = 0.0
var _direction: float = 1.0
var _ghost_timer: float = 0.0


func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	_elapsed = 0.0
	_ghost_timer = 0.0

	var axis := player.get_move_axis()
	_direction = signf(axis)
	if is_zero_approx(_direction):
		_direction = player.facing
	if is_zero_approx(_direction):
		_direction = 1.0

	player.facing = _direction
	player.attack_cooldown_timer = 0.0
	player.clear_attack_buffer()
	player.enter_dodge_collision()
	player.restore_visual_color()
	player.stop_animation()
	player.play_animation(&"dodge")
	player.spawn_afterimage(player.dodge_data.ghost_alpha, player.dodge_data.ghost_fade_duration)


func physics_update(delta: float) -> void:
	_elapsed += delta

	var speed_multiplier := player.dodge_data.get_speed_multiplier(_elapsed)
	player.velocity.x = _direction * player.dodge_data.speed * speed_multiplier
	if player.is_on_floor():
		player.velocity.y = 0.0
	else:
		player.apply_gravity(delta)

	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = player.dodge_data.ghost_interval
		player.spawn_afterimage(
			player.dodge_data.ghost_alpha,
			player.dodge_data.ghost_fade_duration
		)

	if (
		player.dodge_data.can_cancel_into_attack
		and _elapsed >= player.dodge_data.attack_cancel_start_time
		and player.can_start_attack()
		and player.consume_attack_buffer()
	):
		state_machine.transition_to(&"Attack")
		return

	if (
		player.dodge_data.can_cancel_into_jump
		and _elapsed >= player.dodge_data.jump_cancel_start_time
		and player.is_on_floor()
		and player.consume_jump_buffer()
	):
		state_machine.transition_to(&"Jump")
		return

	player.move_and_slide()

	if _elapsed >= player.dodge_data.duration:
		_finish_dodge()


func _finish_dodge() -> void:
	var axis := player.get_move_axis()
	if not player.is_on_floor():
		state_machine.transition_to(&"Fall")
		return
	var grounded_state := &"Run" if not is_zero_approx(axis) else &"Idle"
	state_machine.transition_to(grounded_state)


func exit() -> void:
	player.restore_dodge_collision()
	player.start_dodge_cooldown()
	player.restore_visual_color()


func is_invulnerable() -> bool:
	return player.dodge_data.is_invulnerable(_elapsed)
