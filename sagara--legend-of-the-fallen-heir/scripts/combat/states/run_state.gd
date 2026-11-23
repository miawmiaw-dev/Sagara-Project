extends PlayerState


func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	player.restore_visual_color()
	player.play_animation(&"run")


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)

	if not player.is_on_floor():
		state_machine.transition_to(&"Fall")
		return

	if player.is_climbing_available() and player.is_on_wall() and player.is_climb_up_pressed():
		state_machine.transition_to(&"Climb")
		return

	if player.can_start_dodge() and player.consume_dodge_buffer():
		state_machine.transition_to(&"Dodge")
		return

	if player.try_start_special_attack():
		return

	if player.try_start_attack():
		return

	if player.can_parry() and player.consume_parry_buffer():
		state_machine.transition_to(&"Parry")
		return

	if player.has_jump_buffer():
		player.consume_jump_buffer()
		player.perform_jump()
		state_machine.transition_to(&"Jump", {"preserve_velocity": true})
		return

	var axis := player.get_move_axis()
	if is_zero_approx(axis):
		state_machine.transition_to(&"Idle")
		return

	player.update_horizontal(axis, delta, true)
	player.move_and_slide()

	if not player.is_on_floor():
		state_machine.transition_to(&"Fall")
