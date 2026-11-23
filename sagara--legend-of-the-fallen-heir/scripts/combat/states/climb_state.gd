extends PlayerState


func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	player.jump_buffer_timer = 0.0
	player.velocity = Vector2.ZERO
	player.restore_visual_color()
	player.play_animation(&"wall_slide")


func physics_update(delta: float) -> void:
	if not player.is_climbing_available():
		state_machine.transition_to(&"Fall")
		return

	if player.has_jump_buffer():
		player.consume_jump_buffer()
		player.perform_wall_jump()
		state_machine.transition_to(&"Jump", {"preserve_velocity": true})
		return

	var vertical_input := 0.0
	if Input.is_action_pressed("jump"):
		vertical_input -= 1.0
	if Input.is_action_pressed("down"):
		vertical_input += 1.0

	var axis := player.get_move_axis()
	player.velocity.y = vertical_input * player.climb_speed
	player.velocity.x = axis * player.get_move_speed() * player.climb_horizontal_multiplier
	if not is_zero_approx(axis):
		player.facing = signf(axis)

	player.move_and_slide()

	if player.is_on_floor():
		var grounded_state := &"Run" if not is_zero_approx(axis) else &"Idle"
		state_machine.transition_to(grounded_state)
		return

	if not player.is_climbing_available():
		state_machine.transition_to(&"Fall")
