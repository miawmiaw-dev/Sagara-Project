extends Node

const DEFAULT_SHAKE_FREQUENCY := 34.0
const MAX_HIT_STOP_DURATION := 0.25
const MIN_HIT_STOP_SCALE := 0.02
const HIT_STOP_COOLDOWN_MS := 45

const HEAVY_SLASH_INTENSITY := 6.5
const HEAVY_SLASH_DURATION := 0.26
const SPECIAL_INTENSITY := 9.5
const SPECIAL_DURATION := 0.34
const BOSS_DAMAGE_INTENSITY := 14.0
const BOSS_DAMAGE_DURATION := 0.5
const ENEMY_HIT_INTENSITY := 2.6
const ENEMY_HIT_DURATION := 0.14
const PARRY_INTENSITY := 4.5
const PARRY_DURATION := 0.18

const DEFAULT_SPARK_COLOR := Color(1.0, 0.88, 0.5, 1.0)
const DAMAGE_FLASH_COLOR := Color(1.0, 0.16, 0.12, 0.18)

const WOOD_SPLINTER_COLOR := Color(0.58, 0.38, 0.17, 1.0)
const WOOD_DUST_COLOR := Color(0.82, 0.7, 0.48, 0.85)
const WOOD_HIT_SPARK_COLOR := Color(0.9, 0.68, 0.36, 1.0)
const CHEST_REWARD_COLOR := Color(1.0, 0.86, 0.45, 1.0)
const CHECKPOINT_DEFAULT_COLOR := Color(0.35, 0.95, 1.0, 1.0)
const WOOD_BREAK_SHAKE_INTENSITY := 2.0
const INTERACT_SHAKE_INTENSITY := 2.2
const MICRO_SHAKE_DURATION := 0.13
const MICRO_SHAKE_FREQUENCY := 42.0

var _hit_stop_generation: int = 0
var _hit_stop_base_scale: float = 1.0
var _last_hit_stop_time_ms: int = -100000
var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
var _flash_tween: Tween
var _splinter_texture: Texture2D
var _glow_texture: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_flash_overlay()


func _exit_tree() -> void:
	_restore_time_scale()


func shake_camera(
	intensity: float,
	duration: float,
	frequency: float = DEFAULT_SHAKE_FREQUENCY
) -> void:
	var camera := _find_camera()
	if camera == null:
		return
	if not camera.has_method("shake"):
		return
	camera.call("shake", intensity, duration, frequency)


func heavy_slash() -> void:
	shake_camera(HEAVY_SLASH_INTENSITY, HEAVY_SLASH_DURATION)


func special_skill(
	effect_color: Color = Color(0.45, 0.9, 1.0, 1.0),
	strength: float = 1.0
) -> void:
	var multiplier := clampf(strength, 0.5, 2.0)
	shake_camera(SPECIAL_INTENSITY * multiplier, SPECIAL_DURATION * multiplier)
	hit_stop(0.045, 0.08)
	flash_screen(Color(effect_color.r, effect_color.g, effect_color.b, 0.1), 0.22)


func player_big_damage(amount: int = 0) -> void:
	if amount <= 0:
		return
	shake_camera(BOSS_DAMAGE_INTENSITY, BOSS_DAMAGE_DURATION)
	hit_stop(0.085, 0.045, true)
	flash_screen(DAMAGE_FLASH_COLOR, 0.3)
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		spawn_hit_spark(
			(player as Node2D).global_position + Vector2(0.0, -8.0),
			Color(1.0, 0.35, 0.28, 1.0),
			0.0,
			1.5
		)


func enemy_hit(
	target: Node,
	hit_position: Vector2,
	damage: int,
	color: Color = DEFAULT_SPARK_COLOR,
	direction: float = 0.0,
	heavy: bool = false
) -> void:
	if damage <= 0:
		return

	var is_boss := _is_boss_target(target)
	var killed := _is_target_dead(target)
	var spark_color := color
	if spark_color.a <= 0.0:
		spark_color = DEFAULT_SPARK_COLOR

	var spark_scale := 1.0
	if heavy:
		spark_scale += 0.35
	if is_boss:
		spark_scale += 0.3
	if killed:
		spark_scale += 0.5

	spawn_hit_spark(hit_position, spark_color, direction, spark_scale)

	if heavy or is_boss or killed:
		var shake_intensity := ENEMY_HIT_INTENSITY
		if is_boss:
			shake_intensity += 0.8
		if killed:
			shake_intensity += 0.6
		shake_camera(shake_intensity, ENEMY_HIT_DURATION)
		hit_stop(0.045 if heavy else 0.03, 0.05)
	else:
		hit_stop(0.025, 0.06)


func parry_success(at_position: Vector2, color: Color = Color(0.35, 0.95, 1.0, 1.0)) -> void:
	shake_camera(PARRY_INTENSITY, PARRY_DURATION)
	hit_stop(0.055, 0.06, true)
	spawn_hit_spark(at_position, color, 0.0, 1.3)
	flash_screen(Color(color.r, color.g, color.b, 0.08), 0.16)


func hit_stop(duration: float, time_scale: float = 0.05, force: bool = false) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null or tree.paused:
		return

	var now := Time.get_ticks_msec()
	if not force and now - _last_hit_stop_time_ms < HIT_STOP_COOLDOWN_MS:
		return
	_last_hit_stop_time_ms = now

	var safe_duration := clampf(duration, 0.01, MAX_HIT_STOP_DURATION)
	var safe_scale := clampf(time_scale, MIN_HIT_STOP_SCALE, 1.0)
	if _hit_stop_generation == 0:
		_hit_stop_base_scale = Engine.time_scale
	_hit_stop_generation += 1
	var generation := _hit_stop_generation
	Engine.time_scale = minf(safe_scale, _hit_stop_base_scale)

	var timer := tree.create_timer(safe_duration, true, false, true)
	timer.timeout.connect(_end_hit_stop.bind(generation))


func flash_screen(color: Color, duration: float = 0.2) -> void:
	if _flash_rect == null or not is_instance_valid(_flash_rect):
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	var safe_color := color
	safe_color.a = clampf(color.a, 0.0, 0.5)
	_flash_rect.color = safe_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(
		_flash_rect,
		"color:a",
		0.0,
		maxf(duration, 0.05)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func spawn_hit_spark(
	at_position: Vector2,
	color: Color = DEFAULT_SPARK_COLOR,
	direction: float = 0.0,
	size_multiplier: float = 1.0
) -> void:
	if not is_inside_tree():
		return
	var host := get_tree().current_scene
	if host == null or not is_instance_valid(host):
		host = self

	var spark := Node2D.new()
	spark.name = "JuiceHitSpark"
	spark.z_index = 30
	host.add_child(spark)
	spark.global_position = at_position

	var size := clampf(size_multiplier, 0.5, 3.0)
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(5.0, 0.0),
		Vector2(0.0, 10.0),
		Vector2(-5.0, 0.0),
	])
	flash.color = color
	flash.scale = Vector2(0.7, 0.7) * size
	spark.add_child(flash)

	var tween := spark.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2.2, 2.2) * size, 0.14)
	tween.tween_property(flash, "modulate:a", 0.0, 0.14)

	var base_angle := 0.0
	if not is_zero_approx(direction):
		base_angle = 0.0 if direction > 0.0 else PI

	for index in range(6):
		var angle := base_angle + randf_range(-0.9, 0.9)
		var length := randf_range(8.0, 18.0) * size
		var shard := Line2D.new()
		shard.width = randf_range(1.5, 3.0) * size
		shard.default_color = color
		shard.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0.0)])
		shard.rotation = angle
		spark.add_child(shard)
		if index % 2 == 0:
			shard.rotation += PI
		var travel := Vector2.from_angle(angle) * randf_range(16.0, 34.0) * size
		tween.tween_property(shard, "position", travel, 0.16)
		tween.tween_property(shard, "modulate:a", 0.0, 0.18)

	tween.chain().tween_callback(spark.queue_free)


func wood_hit(at_position: Vector2, direction: float = 0.0) -> void:
	if not is_inside_tree():
		return
	spawn_hit_spark(at_position, WOOD_HIT_SPARK_COLOR, direction, 0.85)
	_spawn_wood_splinters(at_position, direction, 0.65, 7)


func wood_break(
	at_position: Vector2,
	direction: float = 0.0,
	size_multiplier: float = 1.0
) -> void:
	if not is_inside_tree():
		return
	var size := clampf(size_multiplier, 0.5, 3.0)
	_spawn_wood_splinters(at_position, direction, size, int(round(18.0 * size)))
	_spawn_wood_dust(at_position, size)
	spawn_hit_spark(at_position, WOOD_HIT_SPARK_COLOR, direction, size)
	shake_camera(
		WOOD_BREAK_SHAKE_INTENSITY * size,
		MICRO_SHAKE_DURATION,
		MICRO_SHAKE_FREQUENCY
	)


func chest_open(at_position: Vector2) -> void:
	if not is_inside_tree():
		return
	_spawn_wood_splinters(at_position + Vector2(0.0, 8.0), 0.0, 0.55, 8)
	_spawn_magic_sparkles(at_position, CHEST_REWARD_COLOR, 0.9, 18)
	spawn_hit_spark(at_position, CHEST_REWARD_COLOR, 0.0, 1.35)
	shake_camera(INTERACT_SHAKE_INTENSITY, 0.16, MICRO_SHAKE_FREQUENCY)


func checkpoint_activated(
	at_position: Vector2,
	color: Color = CHECKPOINT_DEFAULT_COLOR
) -> void:
	if not is_inside_tree():
		return
	_spawn_magic_sparkles(at_position, color, 1.2, 24)
	spawn_hit_spark(at_position, color, 0.0, 1.25)
	shake_camera(1.7, 0.15, MICRO_SHAKE_FREQUENCY)
	flash_screen(Color(color.r, color.g, color.b, 0.06), 0.2)


func altar_upgrade_success(at_position: Vector2) -> void:
	if not is_inside_tree():
		return
	var gold_color := Color(1.0, 0.85, 0.3, 1.0)
	_spawn_magic_sparkles(at_position, gold_color, 1.5, 32)
	spawn_hit_spark(at_position, gold_color, 0.0, 1.8)
	shake_camera(2.5, 0.22, MICRO_SHAKE_FREQUENCY)
	flash_screen(Color(gold_color.r, gold_color.g, gold_color.b, 0.1), 0.25)


func magic_burst(
	at_position: Vector2,
	color: Color = CHECKPOINT_DEFAULT_COLOR,
	size_multiplier: float = 1.0
) -> void:
	if not is_inside_tree():
		return
	var size := clampf(size_multiplier, 0.5, 2.0)
	_spawn_magic_sparkles(at_position, color, size, int(round(16.0 * size)))


func _spawn_wood_splinters(
	at_position: Vector2,
	direction: float,
	size: float,
	count: int
) -> void:
	var effect := _spawn_effect_host("JuiceWoodSplinters", at_position, 26)
	var particles := CPUParticles2D.new()
	particles.texture = _get_splinter_texture()
	particles.amount = clampi(count, 4, 64)
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = _resolve_burst_direction(direction)
	particles.spread = 180.0 if is_zero_approx(direction) else 72.0
	particles.gravity = Vector2(0.0, 720.0)
	particles.initial_velocity_min = 80.0 * size
	particles.initial_velocity_max = 210.0 * size
	particles.scale_amount_min = 0.6 * size
	particles.scale_amount_max = 1.25 * size
	particles.angular_velocity_min = -540.0
	particles.angular_velocity_max = 540.0
	particles.color = WOOD_SPLINTER_COLOR
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(14.0, 18.0) * size
	particles.emitting = false
	effect.add_child(particles)
	particles.emitting = true
	_schedule_effect_free(effect, 0.8)


func _spawn_wood_dust(at_position: Vector2, size: float) -> void:
	var effect := _spawn_effect_host("JuiceWoodDust", at_position, 25)
	var particles := CPUParticles2D.new()
	particles.texture = _get_glow_texture()
	particles.amount = clampi(int(round(10.0 * size)), 4, 24)
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 70.0)
	particles.initial_velocity_min = 20.0 * size
	particles.initial_velocity_max = 75.0 * size
	particles.scale_amount_min = 1.2 * size
	particles.scale_amount_max = 2.4 * size
	particles.color = WOOD_DUST_COLOR
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(12.0, 8.0) * size
	particles.emitting = false
	effect.add_child(particles)
	particles.emitting = true
	_schedule_effect_free(effect, 0.7)


func _spawn_magic_sparkles(
	at_position: Vector2,
	color: Color,
	size: float,
	count: int
) -> void:
	var effect := _spawn_effect_host("JuiceMagicSparkles", at_position, 27)
	var particles := CPUParticles2D.new()
	particles.texture = _get_glow_texture()
	particles.amount = clampi(count, 6, 48)
	particles.lifetime = 0.75
	particles.one_shot = true
	particles.explosiveness = 0.75
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, -110.0)
	particles.damping_min = 20.0
	particles.damping_max = 40.0
	particles.initial_velocity_min = 30.0 * size
	particles.initial_velocity_max = 125.0 * size
	particles.scale_amount_min = 0.6 * size
	particles.scale_amount_max = 1.6 * size
	particles.color = color
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(18.0, 30.0) * size
	particles.emitting = false
	effect.add_child(particles)
	particles.emitting = true
	_schedule_effect_free(effect, 0.95)


func _spawn_effect_host(effect_name: String, at_position: Vector2, z: int) -> Node2D:
	var host := get_tree().current_scene
	if host == null or not is_instance_valid(host):
		host = self
	var effect := Node2D.new()
	effect.name = effect_name
	effect.z_index = z
	host.add_child(effect)
	effect.global_position = at_position
	return effect


func _resolve_burst_direction(direction: float) -> Vector2:
	if is_zero_approx(direction):
		return Vector2.UP
	return Vector2(direction, -1.0).normalized()


func _schedule_effect_free(effect: Node, lifetime: float) -> void:
	if not is_inside_tree():
		_free_if_valid(effect)
		return
	var timer := get_tree().create_timer(maxf(lifetime, 0.05), true, false, true)
	timer.timeout.connect(_free_if_valid.bind(effect))


func _free_if_valid(node = null) -> void:
	if is_instance_valid(node) and node is Node:
		node.queue_free()


func _get_splinter_texture() -> Texture2D:
	if _splinter_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color.WHITE)
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_LINEAR
		texture.fill_from = Vector2(0.0, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 4
		texture.height = 12
		_splinter_texture = texture
	return _splinter_texture


func _get_glow_texture() -> Texture2D:
	if _glow_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 1.0)
		texture.width = 16
		texture.height = 16
		_glow_texture = texture
	return _glow_texture


func _find_camera() -> Camera2D:
	if not is_inside_tree():
		return null
	var camera_node := get_tree().get_first_node_in_group("juice_camera")
	if camera_node is Camera2D:
		return camera_node as Camera2D
	var viewport_camera := get_viewport().get_camera_2d()
	if viewport_camera != null:
		return viewport_camera
	return null


func _is_boss_target(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.has_method("is_fight_active"):
		return bool(target.call("is_fight_active"))
	return target.is_in_group("boss")


func _is_target_dead(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var health: Variant = target.get("current_hp")
	if health == null:
		health = target.get("health")
	if health == null:
		return false
	return float(health) <= 0.0


func _end_hit_stop(generation: int) -> void:
	if generation != _hit_stop_generation:
		return
	_hit_stop_generation = 0
	Engine.time_scale = _hit_stop_base_scale


func _restore_time_scale() -> void:
	if _hit_stop_generation <= 0:
		return
	_hit_stop_generation = 0
	Engine.time_scale = _hit_stop_base_scale


func _build_flash_overlay() -> void:
	_flash_layer = CanvasLayer.new()
	_flash_layer.name = "JuiceFlashLayer"
	_flash_layer.layer = 50
	add_child(_flash_layer)

	_flash_rect = ColorRect.new()
	_flash_rect.name = "ScreenFlash"
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(_flash_rect)
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
