extends PlayerState


func enter(_previous_state: StringName, data: Dictionary = {}) -> void:
	if not bool(data.get("preserve_velocity", false)):
		player.perform_jump()
	player.restore_visual_color()
	player.play_animation(&"jump")


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)

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

	var axis := player.get_move_axis()
	player.update_horizontal(axis, delta, false)

	if player.has_jump_buffer() and player.can_double_jump():
		player.consume_jump_buffer()
		player.perform_double_jump()
		player.move_and_slide()
		return

	player.move_and_slide()

	if player.is_on_floor():
		var grounded_state := &"Run" if not is_zero_approx(axis) else &"Idle"
		state_machine.transition_to(grounded_state)
		return

	if player.velocity.y >= 0.0:
		state_machine.transition_to(&"Fall")
