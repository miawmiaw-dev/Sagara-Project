extends Area2D
class_name BiomePortal

const PULSE_DURATION := 1.1
const PULSE_MIN_ALPHA := 0.4
const INACTIVE_CORE_COLOR := Color(0.45, 0.58, 0.68, 0.35)
const ACTIVE_CORE_COLOR := Color(0.32, 0.9, 1.0, 0.55)
const ACTIVATION_COLOR := Color(0.45, 0.95, 1.0, 1.0)
const ACTIVATION_FLASH_COLOR := Color(0.45, 0.95, 1.0, 0.12)
const REVEAL_DURATION := 0.38
const PORTAL_RING_RADIUS := 34.0
const SFX_MIX_RATE := 22050
const CHIME_NOTES := [523.25, 659.25, 783.99, 1046.5]

@export_file("*.tscn") var target_scene: String = ""
@export var target_spawn_tag: String = ""
@export var fade_duration: float = 0.45
@export var fade_in_duration: float = 0.35
@export var fade_color: Color = Color(0.02, 0.03, 0.05, 1.0)
@export var player_group: String = "player"
@export var start_disabled: bool = true
@export var activation_delay: float = 0.0
@export var required_boss_id: String = ""
@export var activation_sound_enabled: bool = true

@onready var _glow: ColorRect = get_node_or_null("Glow") as ColorRect
@onready var _core: ColorRect = get_node_or_null("Core") as ColorRect
@onready var _frame_kiri: ColorRect = get_node_or_null("FrameKiri") as ColorRect
@onready var _frame_kanan: ColorRect = get_node_or_null("FrameKanan") as ColorRect
@onready var _frame_atas: ColorRect = get_node_or_null("FrameAtas") as ColorRect
@onready var _collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

var _transitioning := false
var _active := false


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not required_boss_id.strip_edges().is_empty() and GameState.is_boss_defeated(
		required_boss_id
	):
		start_disabled = false
	if start_disabled:
		deactivate(false)
	else:
		activate(false)
	if activation_delay > 0.0 and not _active:
		monitoring = false
		var delay := get_tree().create_timer(activation_delay)
		await delay.timeout
		if is_inside_tree() and not _active:
			activate(true)


func activate(animated: bool = true) -> void:
	if _active:
		return
	_active = true
	_transitioning = false
	monitoring = true
	if is_instance_valid(_collision):
		_collision.set_deferred("disabled", false)
	if is_instance_valid(_core):
		_core.modulate = Color.WHITE
	if is_instance_valid(_glow):
		_glow.visible = true
	_set_visuals_visible(true)
	visible = true

	if animated:
		_play_reveal()
		_play_activation_juice()
	else:
		modulate = Color.WHITE
		if is_instance_valid(_core):
			_core.color = ACTIVE_CORE_COLOR
		if is_instance_valid(_glow):
			_glow.modulate.a = 1.0
		_start_glow_pulse()


func deactivate(_animated: bool = true) -> void:
	_active = false
	_transitioning = false
	monitoring = false
	if is_instance_valid(_collision):
		_collision.set_deferred("disabled", true)
	_stop_glow_pulse()
	if is_instance_valid(_glow):
		_glow.visible = false
		_glow.modulate.a = 1.0
	if is_instance_valid(_core):
		_core.color = INACTIVE_CORE_COLOR
		_core.modulate = Color.WHITE
	_set_visuals_visible(false)
	modulate = Color.WHITE
	visible = false


func is_active() -> bool:
	return _active


func _set_visuals_visible(showing: bool) -> void:
	for visual in [_glow, _core, _frame_kiri, _frame_kanan, _frame_atas]:
		if is_instance_valid(visual):
			(visual as CanvasItem).visible = showing


func _play_reveal() -> void:
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	if is_instance_valid(_core):
		_core.color = Color(1.0, 1.0, 1.0, 0.95)
	if is_instance_valid(_glow):
		_glow.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, REVEAL_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_core):
		tween.tween_property(_core, "color", ACTIVE_CORE_COLOR, REVEAL_DURATION + 0.22) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_glow):
		tween.tween_property(_glow, "modulate:a", 1.0, REVEAL_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_start_glow_pulse)


func _play_activation_juice() -> void:
	_spawn_portal_ring()
	if not is_inside_tree():
		return
	JuiceFX.checkpoint_activated(global_position + Vector2(0.0, -52.0), ACTIVATION_COLOR)
	JuiceFX.magic_burst(global_position + Vector2(0.0, -18.0), ACTIVATION_COLOR, 1.25)
	JuiceFX.flash_screen(ACTIVATION_FLASH_COLOR, 0.32)
	if activation_sound_enabled:
		_play_sound(_build_chime_stream(CHIME_NOTES, 0.085, 0.22))


func _spawn_portal_ring() -> void:
	if not is_inside_tree():
		return
	var host := get_tree().current_scene
	if host == null or not is_instance_valid(host):
		host = self

	var ring := Line2D.new()
	ring.name = "PortalActivationRing"
	ring.width = 3.0
	ring.default_color = ACTIVATION_COLOR
	ring.z_index = 24
	var points := PackedVector2Array()
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * PORTAL_RING_RADIUS)
	ring.points = points

	host.add_child(ring)
	ring.global_position = global_position + Vector2(0.0, -4.0)
	ring.scale = Vector2(0.35, 0.35)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.55) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(ring.queue_free)


func _start_glow_pulse() -> void:
	if not _active or not is_instance_valid(_glow):
		return
	_stop_glow_pulse()
	var tween := create_tween().set_loops()
	var fade_in := tween.tween_property(_glow, "modulate:a", PULSE_MIN_ALPHA, PULSE_DURATION)
	fade_in.set_trans(Tween.TRANS_SINE)
	fade_in.set_ease(Tween.EASE_IN_OUT)
	var fade_out := tween.tween_property(_glow, "modulate:a", 1.0, PULSE_DURATION)
	fade_out.set_trans(Tween.TRANS_SINE)
	fade_out.set_ease(Tween.EASE_IN_OUT)
	_glow.set_meta("_pulse_tween", tween)


func _stop_glow_pulse() -> void:
	if not is_instance_valid(_glow) or not _glow.has_meta("_pulse_tween"):
		return
	var old_tween: Variant = _glow.get_meta("_pulse_tween")
	if old_tween is Tween and old_tween.is_valid():
		old_tween.kill()
	_glow.remove_meta("_pulse_tween")


func _on_body_entered(body: Node2D) -> void:
	if not _active or _transitioning:
		return
	if not is_instance_valid(body):
		return
	if not body.is_in_group(player_group):
		return
	if LevelTransition.is_transitioning():
		return
	if target_scene.is_empty():
		push_warning("Portal belum memiliki target_scene.")
		return
	if not ResourceLoader.exists(target_scene):
		push_error("Portal tidak menemukan scene target: %s" % target_scene)
		return

	_transitioning = true
	set_deferred("monitoring", false)
	if body is CharacterBody2D:
		(body as CharacterBody2D).velocity = Vector2.ZERO

	var success: bool = await LevelTransition.transition_to_scene(
		target_scene,
		target_spawn_tag,
		fade_duration,
		fade_in_duration,
		fade_color
	)
	if success:
		return

	_active = false
	activate(false)


func _play_sound(stream: AudioStream) -> void:
	if stream == null or not is_inside_tree():
		return
	var player := AudioStreamPlayer.new()
	player.name = "PortalActivationSound"
	player.stream = stream
	player.volume_db = -2.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _build_chime_stream(notes: Array, note_spacing: float, volume: float) -> AudioStreamWAV:
	var sample_rate := SFX_MIX_RATE
	var tail := 0.32
	var spacing := maxf(note_spacing, 0.01)
	var total_duration := spacing * float(maxi(notes.size() - 1, 0)) + tail
	var frame_count := int(total_duration * float(sample_rate))
	var data := PackedByteArray()
	data.resize(frame_count * 2)

	for index in range(frame_count):
		var time := float(index) / float(sample_rate)
		var sample := 0.0
		for note_index in range(notes.size()):
			var local := time - spacing * float(note_index)
			if local < 0.0 or local > tail:
				continue
			var frequency := float(notes[note_index])
			var attack := minf(local / 0.015, 1.0)
			var decay := exp(-local * 4.2)
			sample += sin(TAU * frequency * local) * attack * decay * volume
			sample += sin(TAU * frequency * 2.0 * local) * attack * decay * volume * 0.22
		data.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
