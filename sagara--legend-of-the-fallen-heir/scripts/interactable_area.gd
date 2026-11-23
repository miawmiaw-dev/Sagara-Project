extends Area2D

const INTERACTION_KEYS := [KEY_E, KEY_F]

var _player_in_range: Node2D = null

@onready var _prompt: Label = get_node_or_null("Prompt") as Label


func _ready() -> void:
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process_unhandled_input(true)
	_on_interactable_ready()
	refresh_prompt()


func _on_interactable_ready() -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = body
	refresh_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body != _player_in_range:
		return
	_player_in_range = null
	refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_player_in_range):
		return
	if not can_interact():
		return
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if not INTERACTION_KEYS.has(event.keycode):
		return
	get_viewport().set_input_as_handled()
	interact(_player_in_range)


func can_interact() -> bool:
	return true


func get_prompt_text() -> String:
	return "E / F : Berinteraksi"


func interact(_player: Node2D) -> void:
	pass


func refresh_prompt() -> void:
	if _prompt == null:
		return
	if not is_instance_valid(_player_in_range) or not can_interact():
		_prompt.visible = false
		return
	var text := get_prompt_text()
	_prompt.visible = not text.is_empty()
	_prompt.text = text
