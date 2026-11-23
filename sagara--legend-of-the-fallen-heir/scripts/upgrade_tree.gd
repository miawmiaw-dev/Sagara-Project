extends CanvasLayer

@onready var souls_label: Label = $Control/Panel/SoulsLabel
@onready var hp_button: Button = $Control/Panel/VBoxContainer/HPButton
@onready var potion_button: Button = $Control/Panel/VBoxContainer/PotionButton
@onready var soul_save_button: Button = $Control/Panel/VBoxContainer/SoulSaveButton
@onready var close_button: Button = $Control/Panel/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if hp_button:
		hp_button.pressed.connect(buy_hp_upgrade)
	if potion_button:
		potion_button.pressed.connect(buy_potion_upgrade)
	if soul_save_button:
		soul_save_button.pressed.connect(buy_soul_save)
	if close_button:
		close_button.pressed.connect(close_ui)
	update_ui()

func update_ui() -> void:
	if souls_label:
		souls_label.text = "Souls: " + str(GameState.total_souls)

func get_hp_price() -> int:
	return GameState.get_hp_upgrade_cost()

func get_potion_price() -> int:
	return GameState.get_potion_upgrade_cost()

func get_soul_save_price() -> int:
	return GameState.get_soul_save_upgrade_cost()

func buy_hp_upgrade() -> void:
	if GameState.buy_hp_upgrade():
		update_ui()

func buy_potion_upgrade() -> void:
	if GameState.buy_potion_upgrade():
		update_ui()

func buy_soul_save() -> void:
	if GameState.buy_soul_save_upgrade():
		update_ui()

func close_ui() -> void:
	get_tree().paused = false
	queue_free()
