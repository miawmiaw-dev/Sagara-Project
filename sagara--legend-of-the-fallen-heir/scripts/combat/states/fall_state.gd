extends PlayerState


func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	player.restore_visual_color()
	player.play_animation(&"fall")


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)

	if player.is_on_floor():
		_transition_to_grounded()
		return

	if player.is_climbing_available() and player.is_climb_input_pressed():
		state_machine.transition_to(&"Climb")
		return

	if player.can_start_dodge() and player.consume_dodge_buffer():
		state_machine.transition_to(&"Dodge")
		return

	if player.should_start_dive_attack():
		player.consume_attack_buffer()
		state_machine.transition_to(&"Dive")
		return

	if player.try_start_special_attack():
		return

	if player.try_start_attack():
		return

	var wall_sliding := player.is_wall_sliding()
	if wall_sliding:
		player.velocity.y = minf(player.velocity.y, player.wall_slide_speed)
		player.play_animation(&"wall_slide")

	if player.has_jump_buffer():
		if wall_sliding:
			player.consume_jump_buffer()
			player.perform_wall_jump()
			state_machine.transition_to(&"Jump", {"preserve_velocity": true})
			return
		if player.coyote_timer > 0.0:
			player.consume_jump_buffer()
			player.perform_jump()
			state_machine.transition_to(&"Jump", {"preserve_velocity": true})
			return
		if player.can_double_jump():
			player.consume_jump_buffer()
			player.perform_double_jump()
			state_machine.transition_to(&"Jump", {"preserve_velocity": true})
			return

	var axis := player.get_move_axis()
	player.update_horizontal(axis, delta, false)
	player.move_and_slide()

	if player.is_on_floor():
		_transition_to_grounded()


func _transition_to_grounded() -> void:
	var axis := player.get_move_axis()
	var grounded_state := &"Run" if not is_zero_approx(axis) else &"Idle"
	state_machine.transition_to(grounded_state)
