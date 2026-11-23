extends PlayerState

const DIVE_SPEED := 800.0
const DIVE_RADIUS := 60.0
const DIVE_EFFECT_OFFSET := 28.0
const DIVE_EFFECT_DURATION := 0.28
const DIVE_COLOR := Color(1.0, 0.45, 0.1, 1.0)


func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	player.velocity.x *= 0.35
	player.velocity.y = DIVE_SPEED
	player.set_visual_color(DIVE_COLOR)
	player.play_animation(&"dive")


func physics_update(delta: float) -> void:
	if player.can_start_dodge() and player.consume_dodge_buffer():
		state_machine.transition_to(&"Dodge")
		return

	player.velocity.x = move_toward(
		player.velocity.x,
		0.0,
		player.get_move_speed() * 4.0 * delta
	)
	player.velocity.y = DIVE_SPEED
	player.move_and_slide()

	var hit_surface := player.is_on_floor() or player.get_slide_collision_count() > 0
	if not hit_surface:
		return

	_impact()
	if player.is_on_floor():
		state_machine.transition_to(&"Idle")
	else:
		state_machine.transition_to(&"Fall")


func _impact() -> void:
	if player == null or player.combat == null:
		return
	JuiceFX.shake_camera(5.5, 0.22, 30.0)
	player.combat.dive_impact(
		DIVE_RADIUS,
		DIVE_EFFECT_OFFSET,
		player.get_dive_damage(),
		player.facing
	)
	player.combat.spawn_ring(
		12.0,
		DIVE_RADIUS,
		DIVE_COLOR,
		DIVE_EFFECT_DURATION,
		DIVE_EFFECT_OFFSET,
		0.35
	)


func exit() -> void:
	player.restore_visual_color()
