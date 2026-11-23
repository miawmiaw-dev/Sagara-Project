extends CanvasLayer
class_name AltarShopUI

signal closed

const SHOP_MODE := "shop"
const TELEPORT_MODE := "teleport"

@onready var overlay: ColorRect = $Control/Overlay
@onready var title_label: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var souls_display: Label = $Control/PanelContainer/MarginContainer/VBoxContainer/SoulsDisplay
@onready var upgrade_hp_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/UpgradeHPButton
@onready var upgrade_attack_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/UpgradeAttackButton
@onready var teleport_list: VBoxContainer = $Control/PanelContainer/MarginContainer/VBoxContainer/TeleportList
@onready var close_button: Button = $Control/PanelContainer/MarginContainer/VBoxContainer/CloseButton

var source_altar: AltarInteract = null
var open_mode: String = SHOP_MODE
var _panel_container: PanelContainer
var _open_tween: Tween = null
var _teleport_buttons: Array[Button] = []
var _is_closing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	get_tree().paused = true

	_panel_container = $Control/PanelContainer

	if upgrade_hp_button:
		upgrade_hp_button.pressed.connect(_buy_hp_upgrade)
	if upgrade_attack_button:
		upgrade_attack_button.pressed.connect(_buy_attack_upgrade)
	if close_button:
		close_button.pressed.connect(_close_shop)

	update_ui()
	_open_animation()


func _unhandled_input(event: InputEvent) -> void:
	if _is_closing:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_close_shop()


func _open_animation() -> void:
	if _panel_container == null:
		return
	_panel_container.visible = false
	overlay.visible = false

	await get_tree().process_frame

	if _is_closing or not is_instance_valid(_panel_container):
		return

	_panel_container.visible = true
	overlay.visible = true
	overlay.modulate.a = 0.0
	_panel_container.modulate.a = 0.0

	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = create_tween()
	_open_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_open_tween.tween_property(overlay, "modulate:a", 0.7, 0.3)
	_open_tween.tween_property(_panel_container, "modulate:a", 1.0, 0.3).set_delay(0.1)


func update_ui() -> void:
	if souls_display:
		souls_display.text = "Jiwa Murni: %d" % GameState.total_souls

	if open_mode == TELEPORT_MODE:
		_build_teleport_menu()
	else:
		_build_shop_menu()


func _build_shop_menu() -> void:
	if title_label:
		title_label.text = "ALTAR PUJIAN"

	_clear_teleport_buttons()
	if teleport_list:
		teleport_list.visible = false

	if upgrade_hp_button:
		var hp_cost := GameState.get_hp_upgrade_cost()
		var hp_level := GameState.upgrade_hp_level
		var can_afford := GameState.total_souls >= hp_cost
		upgrade_hp_button.text = "Upgrade Max HP (+20)\nLevel: %d | Biaya: %d Jiwa" % [hp_level, hp_cost]
		upgrade_hp_button.disabled = not can_afford
		upgrade_hp_button.visible = true
		if can_afford:
			upgrade_hp_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			upgrade_hp_button.add_theme_color_override("font_hover_color", Color(0.8, 1.0, 0.8))
		else:
			upgrade_hp_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			upgrade_hp_button.add_theme_color_override("font_hover_color", Color(0.5, 0.5, 0.5))

	if upgrade_attack_button:
		var atk_cost := GameState.get_attack_upgrade_cost()
		var atk_level := GameState.upgrade_attack_level
		var can_afford_atk := GameState.total_souls >= atk_cost
		upgrade_attack_button.text = "Upgrade Attack Power (+3)\nLevel: %d | Biaya: %d Jiwa" % [atk_level, atk_cost]
		upgrade_attack_button.disabled = not can_afford_atk
		upgrade_attack_button.visible = true
		if can_afford_atk:
			upgrade_attack_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			upgrade_attack_button.add_theme_color_override("font_hover_color", Color(1.0, 0.8, 0.8))
		else:
			upgrade_attack_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			upgrade_attack_button.add_theme_color_override("font_hover_color", Color(0.5, 0.5, 0.5))


func _build_teleport_menu() -> void:
	if title_label:
		title_label.text = "TELEPORTASI ALTAR"

	_clear_teleport_buttons()
	if upgrade_hp_button:
		upgrade_hp_button.visible = false
	if upgrade_attack_button:
		upgrade_attack_button.visible = false
	if teleport_list:
		teleport_list.visible = true

	var all_altars := _get_all_active_altars()

	if all_altars.is_empty():
		var no_altar_btn := Button.new()
		no_altar_btn.text = "Tidak ada altar aktif lain."
		no_altar_btn.disabled = true
		no_altar_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		no_altar_btn.add_theme_font_size_override("font_size", 14)
		_add_teleport_button(no_altar_btn)
		return

	var return_btn := Button.new()
	return_btn.text = "Kembali ke Altar Ini"
	return_btn.pressed.connect(_return_to_this_altar)
	_add_teleport_button(return_btn)

	for entry in all_altars:
		var altar := GameState.get_registered_altar_node(entry) as AltarInteract
		if altar == null or not is_instance_valid(altar):
			continue

		var teleport_btn := Button.new()

		var saved_position: Variant = entry.get("checkpoint_position", Vector2.ZERO)
		var save_pos := altar.global_position
		if saved_position is Vector2 and saved_position != Vector2.ZERO:
			save_pos = saved_position
		var pos_text := " (%d, %d)" % [int(save_pos.x), int(save_pos.y)]

		teleport_btn.text = "Teleport ke Altar%s" % pos_text
		teleport_btn.pressed.connect(_make_teleport_callback(altar))
		_add_teleport_button(teleport_btn)


func _add_teleport_button(button: Button) -> void:
	if teleport_list == null:
		return
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	teleport_list.add_child(button)
	_teleport_buttons.append(button)


func _make_teleport_callback(altar: AltarInteract) -> Callable:
	return func() -> void:
		_execute_teleport(altar)


func _return_to_this_altar() -> void:
	if source_altar != null and is_instance_valid(source_altar):
		var player: Node = null
		var current_scene := get_tree().current_scene
		if current_scene != null:
			player = current_scene.get_node_or_null("Player")
			if player == null:
				player = current_scene.get_node_or_null("CharacterBody2D")
		for child in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(child):
				player = child
				break
		if player is Node2D:
			(player as Node2D).global_position = source_altar.global_position + Vector2(0, -40)
			if player.has_method("show_message"):
				player.call("show_message", "Kembali ke altar ini.")
	JuiceFX.altar_upgrade_success(get_viewport().get_visible_rect().size / 2)
	_close_shop()


func _execute_teleport(target: AltarInteract) -> void:
	if source_altar != null and is_instance_valid(source_altar):
		if target == null or not is_instance_valid(target):
			_show_message("Altar tujuan tidak tersedia.")
			return
		if target == source_altar or target.get_altar_id() == source_altar.get_altar_id():
			_show_message("Kamu sudah berada di altar ini.")
			return

		var player: Node2D = null
		var current_scene := get_tree().current_scene
		if current_scene != null:
			player = current_scene.get_node_or_null("Player")
			if player == null:
				player = current_scene.get_node_or_null("CharacterBody2D")
		for child in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(child):
				player = child
				break

		if player == null:
			_show_message("Sagara tidak ditemukan.")
			return

		_close_shop()
		(source_altar as AltarInteract).start_teleport_sequence(target, player)
	else:
		_close_shop()


func _show_message(message: String) -> void:
	var player: Node2D = null
	var current_scene := get_tree().current_scene
	if current_scene != null:
		player = current_scene.get_node_or_null("Player")
		if player == null:
			player = current_scene.get_node_or_null("CharacterBody2D")
	for child in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(child):
			player = child
			break
	if player != null and player.has_method("show_message"):
		player.call("show_message", message)


func _clear_teleport_buttons() -> void:
	if teleport_list != null:
		for child in teleport_list.get_children():
			teleport_list.remove_child(child)
			child.queue_free()
	_teleport_buttons.clear()


func _get_all_active_altars() -> Array[Dictionary]:
	var current_id := ""
	if source_altar != null and is_instance_valid(source_altar):
		current_id = source_altar.get_altar_id()

	var result: Array[Dictionary] = []
	for entry in GameState.get_other_registered_altars(current_id):
		var altar := GameState.get_registered_altar_node(entry) as AltarInteract
		if altar == null or not is_instance_valid(altar):
			continue
		if altar == source_altar:
			continue
		if not current_id.is_empty() and altar.get_altar_id() == current_id:
			continue
		result.append(entry)
	return result


func _buy_hp_upgrade() -> void:
	if upgrade_hp_button == null or upgrade_hp_button.disabled:
		return
	if GameState.buy_hp_upgrade():
		update_ui()
		JuiceFX.altar_upgrade_success(get_viewport().get_visible_rect().size / 2)
		_show_success_feedback("MAX HP TINGKAT " + str(GameState.upgrade_hp_level))


func _buy_attack_upgrade() -> void:
	if upgrade_attack_button == null or upgrade_attack_button.disabled:
		return
	if GameState.buy_attack_upgrade():
		update_ui()
		JuiceFX.altar_upgrade_success(get_viewport().get_visible_rect().size / 2)
		_show_success_feedback("ATTACK POWER TINGKAT " + str(GameState.upgrade_attack_level))


func _show_success_feedback(message: String) -> void:
	if _panel_container == null:
		return

	var ui_root := get_node_or_null("Control") as Control
	if ui_root == null:
		return

	var feedback_label: Label = Label.new()
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_font_size_override("font_size", 16)
	feedback_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
	feedback_label.text = message
	feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_label.position = Vector2(
		_panel_container.position.x + (_panel_container.size.x - 300.0) * 0.5,
		_panel_container.position.y + _panel_container.size.y - 64.0
	)
	feedback_label.size = Vector2(300, 40)
	ui_root.add_child(feedback_label)
	feedback_label.modulate.a = 0.0

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(feedback_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.5)
	tween.tween_property(feedback_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(feedback_label.queue_free)


func _close_shop() -> void:
	if _is_closing:
		return
	_is_closing = true
	closed.emit()
	if is_inside_tree():
		get_tree().paused = false
	queue_free()
