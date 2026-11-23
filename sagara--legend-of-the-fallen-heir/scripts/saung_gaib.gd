extends Node2D
class_name SaungGaib

@onready var interaction_zone: Area2D = $MbahDukun/InteractionZone
@onready var label: Label = $Label

var player_in_zone: bool = false
var shop_ui_scene := preload("res://scenes/altar_shop_ui.tscn")

func _ready() -> void:
	if label:
		label.visible = false
	if interaction_zone:
		interaction_zone.body_entered.connect(_on_body_entered)
		interaction_zone.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = true
		if label:
			label.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_zone = false
		if label:
			label.visible = false

func _input(event: InputEvent) -> void:
	if not player_in_zone:
		return
	if event.is_action_pressed("interact"):
		open_altar_shop()

func open_altar_shop() -> void:
	if get_tree().paused:
		return
	var ui = shop_ui_scene.instantiate()
	ui.source_altar = null
	get_tree().root.add_child(ui)
	if label:
		label.visible = false
