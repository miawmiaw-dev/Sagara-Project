class_name ClimbableWall
extends Area2D

@export var player_group: String = "player"

var _bodies: Dictionary = {}


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


func _exit_tree() -> void:
	for body in _bodies.keys():
		if is_instance_valid(body) and body.has_method("remove_climb_contact"):
			body.call("remove_climb_contact", self)
	_bodies.clear()


func _on_body_entered(body: Node2D) -> void:
	_register_body(body)


func _on_body_exited(body: Node2D) -> void:
	if not _bodies.has(body):
		return
	_bodies.erase(body)
	if is_instance_valid(body) and body.has_method("remove_climb_contact"):
		body.call("remove_climb_contact", self)


func _register_body(body: Node2D) -> void:
	if not is_instance_valid(body) or _bodies.has(body):
		return
	if not body.is_in_group(player_group):
		return
	_bodies[body] = true
	if body.has_method("add_climb_contact"):
		body.call("add_climb_contact", self)
