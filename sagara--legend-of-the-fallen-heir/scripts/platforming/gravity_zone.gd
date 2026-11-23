class_name GravityZone
extends Area2D

## Area anti-gravitasi yang benar-benar mengubah fisika Sagara selama ia berada
## di dalam zona. Efek dipasang melalui add_gravity_source()/remove_gravity_source()
## pada player sehingga tidak ada state global yang bocor ke luar area.

const DEFAULT_ZONE_SIZE := Vector2(320.0, 280.0)
const OVERLAP_POLL_INTERVAL := 0.25

@export_group("Anti-Gravity")
@export_range(0.0, 4.0, 0.05) var gravity_scale: float = 0.3
@export_range(0.0, 4000.0, 10.0) var upward_acceleration: float = 800.0
@export_range(0.0, 800.0, 5.0) var max_rise_speed: float = 130.0
@export_range(0.0, 40.0, 0.5) var vertical_damping: float = 4.0

@export_group("Current")
@export var player_group: String = "player"
@export var pull_toward_center: bool = false
@export var pull_strength: float = 0.0

@export_group("Area")
## Dipakai sebagai fallback bila scene tidak memiliki CollisionShape2D.
@export var zone_size: Vector2 = DEFAULT_ZONE_SIZE

@export_group("Visual")
@export_range(0.0, 8.0, 0.1) var pulse_speed: float = 2.5

var _bodies: Dictionary = {}
var _elapsed: float = 0.0
var _poll_timer: float = 0.0

@onready var _visual: CanvasItem = get_node_or_null("Visual") as CanvasItem
@onready var _rune: Polygon2D = get_node_or_null("Rune") as Polygon2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	monitoring = true
	_ensure_collision_shape()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	call_deferred("_register_current_overlaps")


func _process(delta: float) -> void:
	if not is_instance_valid(_visual):
		return
	_elapsed += delta
	var alpha := 0.5 + sin(_elapsed * pulse_speed) * 0.25
	_visual.modulate.a = alpha
	if is_instance_valid(_rune):
		var s := 1.0 + sin(_elapsed * pulse_speed * 0.7) * 0.15
		_rune.scale = Vector2(s, s)


func _physics_process(delta: float) -> void:
	# Polling berkala menjamin efek tetap aktif walaupun body sudah berada di
	# dalam area sebelum physics frame pertama atau sinyal body_entered terlewat.
	_poll_timer += delta
	if _poll_timer < OVERLAP_POLL_INTERVAL:
		return
	_poll_timer = 0.0
	_register_current_overlaps()


func _ensure_collision_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	if shape_node.shape == null:
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(maxf(zone_size.x, 1.0), maxf(zone_size.y, 1.0))
		shape_node.shape = rectangle


func _register_current_overlaps() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var current: Dictionary = {}
	for body in get_overlapping_bodies():
		if body is Node2D:
			_register_body(body)
			current[body] = true
	# Sinyal body_exited bisa terlewat ketika body di-teleport atau scene
	# di-reload. Polling ini memastikan efek gravitasi selalu dilepas.
	for body in _bodies.keys():
		if not current.has(body):
			_release_body(body)


func _exit_tree() -> void:
	for body in _bodies.keys():
		_release_body(body)
	_bodies.clear()


func _on_body_entered(body: Node2D) -> void:
	_register_body(body)


func _on_body_exited(body: Node2D) -> void:
	_release_body(body)


func _release_body(body: Node) -> void:
	if not _bodies.has(body):
		return
	_bodies.erase(body)
	if is_instance_valid(body) and body.has_method("remove_gravity_source"):
		body.call("remove_gravity_source", self)


func _register_body(body: Node2D) -> bool:
	if not is_instance_valid(body) or _bodies.has(body):
		return false
	if not body.is_in_group(player_group):
		return false
	if not body.has_method("add_gravity_source"):
		return false
	_bodies[body] = true
	body.call("add_gravity_source", self, {
		"gravity_scale": gravity_scale,
		"upward_acceleration": upward_acceleration,
		"max_rise_speed": max_rise_speed,
		"vertical_damping": vertical_damping,
		"pull_toward_center": pull_toward_center,
		"pull_strength": pull_strength,
		"center_position": global_position
	})
	return true
