extends CanvasLayer

const HEALTH_GREEN := Color(0.2, 0.82, 0.32)
const HEALTH_RED := Color(0.9, 0.18, 0.18)
const ROLL_READY_COLOR := Color(0.25, 0.62, 1.0)
const ROLL_COOLDOWN_COLOR := Color(0.45, 0.45, 0.45)
const ROLL_READY_TEXT_COLOR := Color(0.65, 0.85, 1.0)
const ROLL_COOLDOWN_TEXT_COLOR := Color(0.7, 0.7, 0.7)

@onready var health_bar: ProgressBar = $HUDControl/Status/HealthBar
@onready var health_value: Label = $HUDControl/Status/HealthValue
@onready var dash_indicator: ColorRect = $HUDControl/Status/DashStatus/DashIndicator
@onready var dash_label: Label = $HUDControl/Status/DashStatus/DashLabel
@onready var souls_label: Label = $HUDControl/Status/SoulStatus/SoulLabel
@onready var energy_bar: ProgressBar = $HUDControl/Status/EnergyBar
@onready var energy_value: Label = $HUDControl/Status/EnergyValue
@onready var notification_label: Label = $HUDControl/Notification

var _health_fill: StyleBoxFlat
var _notification_tween: Tween = null

func _ready() -> void:
	var fill := health_bar.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		_health_fill = fill.duplicate() as StyleBoxFlat
		health_bar.add_theme_stylebox_override("fill", _health_fill)

	EventBus.health_changed.connect(_on_health_changed)
	EventBus.souls_changed.connect(_on_souls_changed)
	EventBus.dodge_ready_changed.connect(update_roll_ready)
	EventBus.special_energy_changed.connect(update_special_energy)
	EventBus.notification_requested.connect(show_notification)

	_on_health_changed(GameState.current_health, GameState.max_health)
	_on_souls_changed(GameState.total_souls)
	update_special_energy(GameState.special_energy, GameState.max_special_energy)
	update_roll_ready(true)


func _on_health_changed(current_health: int, max_health: int) -> void:
	update_health(float(current_health), float(max_health))


func _on_souls_changed(total_souls: int) -> void:
	update_souls(total_souls)

func update_health(current_health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = clampf(current_health, 0.0, max_health)
	if _health_fill != null:
		var ratio := 0.0 if max_health <= 0.0 else clampf(current_health / max_health, 0.0, 1.0)
		_health_fill.bg_color = HEALTH_RED.lerp(HEALTH_GREEN, ratio)
	health_value.text = "%d / %d" % [roundi(current_health), roundi(max_health)]

func update_roll_ready(is_ready: bool) -> void:
	dash_indicator.color = ROLL_READY_COLOR if is_ready else ROLL_COOLDOWN_COLOR
	dash_label.text = "ROLL SIAP" if is_ready else "ROLL COOLDOWN"
	dash_label.add_theme_color_override(
		"font_color",
		ROLL_READY_TEXT_COLOR if is_ready else ROLL_COOLDOWN_TEXT_COLOR
	)

func update_dash_ready(is_ready: bool) -> void:
	update_roll_ready(is_ready)

func update_souls(amount: int) -> void:
	souls_label.text = "JIWA MURNI: %d" % amount

func update_special_energy(current_energy: float, max_energy: float) -> void:
	var safe_max := maxf(max_energy, 1.0)
	energy_bar.max_value = safe_max
	energy_bar.value = clampf(current_energy, 0.0, safe_max)
	energy_value.text = "ENERGI JIWA %d / %d" % [
		roundi(clampf(current_energy, 0.0, safe_max)),
		roundi(safe_max),
	]

func show_notification(text: String) -> void:
	if text.is_empty():
		return
	notification_label.text = text
	notification_label.visible = true
	notification_label.modulate.a = 0.0
	if _notification_tween != null and _notification_tween.is_valid():
		_notification_tween.kill()
	_notification_tween = create_tween()
	_notification_tween.tween_property(notification_label, "modulate:a", 1.0, 0.15)
	_notification_tween.tween_interval(1.8)
	_notification_tween.tween_property(notification_label, "modulate:a", 0.0, 0.4)
	_notification_tween.tween_callback(_hide_notification)

func _hide_notification() -> void:
	notification_label.visible = false
