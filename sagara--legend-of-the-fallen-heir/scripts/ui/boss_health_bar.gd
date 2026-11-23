class_name BossHealthBar
extends Control

const FADE_IN_TIME := 0.25
const FADE_OUT_TIME := 0.35
const VICTORY_HOLD_TIME := 1.25

@onready var boss_name_label: Label = get_node_or_null("NameLabel") as Label
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar") as ProgressBar
@onready var health_value: Label = get_node_or_null("HealthValue") as Label

var _fade_tween: Tween = null
var _max_health: int = 1
var _fight_active: bool = false


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_fight_active = false
	_connect_event_bus()
	_reset_display()


func _connect_event_bus() -> void:
	if not EventBus.boss_fight_started.is_connected(_on_boss_fight_started):
		EventBus.boss_fight_started.connect(_on_boss_fight_started)
	if not EventBus.boss_health_changed.is_connected(_on_boss_health_changed):
		EventBus.boss_health_changed.connect(_on_boss_health_changed)
	if not EventBus.boss_fight_ended.is_connected(_on_boss_fight_ended):
		EventBus.boss_fight_ended.connect(_on_boss_fight_ended)


func _on_boss_fight_started(display_name: String, max_health: int) -> void:
	if max_health <= 0:
		_fight_active = false
		_finish_hide()
		return
	_fight_active = true
	_max_health = maxi(max_health, 1)
	if boss_name_label != null:
		boss_name_label.text = display_name
	if health_bar != null:
		health_bar.max_value = float(_max_health)
		health_bar.value = float(_max_health)
	_update_health_text(_max_health)
	visible = true
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_TIME)


func _on_boss_health_changed(current_health: int, max_health: int) -> void:
	if not _fight_active:
		return
	_max_health = maxi(max_health, 1)
	if health_bar != null:
		health_bar.max_value = float(_max_health)
		health_bar.value = clampf(float(current_health), 0.0, float(_max_health))
	_update_health_text(current_health)


func _on_boss_fight_ended(_boss_name: String, victory: bool) -> void:
	_fight_active = false
	if not visible:
		return
	if victory:
		if health_bar != null:
			health_bar.value = 0.0
		_update_health_text(0)
		_hide_after(VICTORY_HOLD_TIME)
	else:
		_hide_after(0.0)


func _update_health_text(current_health: int) -> void:
	if health_value == null:
		return
	var safe_current := clampi(current_health, 0, _max_health)
	health_value.text = "%d / %d" % [safe_current, _max_health]


func _hide_after(delay: float) -> void:
	_kill_fade_tween()
	_fade_tween = create_tween()
	if delay > 0.0:
		_fade_tween.tween_interval(delay)
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	_fade_tween.tween_callback(_finish_hide)


func _finish_hide() -> void:
	visible = false
	_reset_display()


func _reset_display() -> void:
	_max_health = 1
	if health_bar != null:
		health_bar.max_value = 1.0
		health_bar.value = 1.0
	_update_health_text(1)


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
