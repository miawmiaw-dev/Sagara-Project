class_name WindZone
extends Area2D

@export var force: Vector2 = Vector2(0.0, -1200.0)
@export var player_group: String = "player"
@export_range(0.0, 8.0, 0.1) var pulse_speed: float = 2.2

var _bodies: Dictionary = {}
var _elapsed: float = 0.0

@onready var _visual: CanvasItem = get_node_or_null("Visual") as CanvasItem


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	for body in get_overlapping_bodies():
		_register_body(body)


func _process(delta: float) -> void:
	if not is_instance_valid(_visual):
		return
	_elapsed += delta
	_visual.modulate.a = 0.72 + sin(_elapsed * pulse_speed) * 0.18


func _exit_tree() -> void:
	for body in _bodies.keys():
		if is_instance_valid(body) and body.has_method("remove_wind_source"):
			body.call("remove_wind_source", self)
	_bodies.clear()


func _on_body_entered(body: Node2D) -> void:
	_register_body(body)


func _on_body_exited(body: Node2D) -> void:
	if not _bodies.has(body):
		return
	_bodies.erase(body)
	if is_instance_valid(body) and body.has_method("remove_wind_source"):
		body.call("remove_wind_source", self)


func _register_body(body: Node2D) -> void:
	if not is_instance_valid(body) or _bodies.has(body):
		return
	if not body.is_in_group(player_group):
		return
	_bodies[body] = true
	if body.has_method("add_wind_source"):
		body.call("add_wind_source", self, force)
