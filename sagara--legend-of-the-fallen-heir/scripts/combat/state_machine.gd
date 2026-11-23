class_name PlayerStateMachine
extends Node

@export var initial_state_name: StringName = &"Idle"

var actor: SagaraPlayer
var current_state: PlayerState
var current_state_name: StringName = &""

var _states: Dictionary = {}


func _ready() -> void:
	_collect_states()


func initialize(p_actor: SagaraPlayer) -> void:
	actor = p_actor
	if _states.is_empty():
		_collect_states()
	for state: PlayerState in _states.values():
		state.setup(actor, self)
	transition_to(initial_state_name)


func _collect_states() -> void:
	_states.clear()
	for child in get_children():
		if child is PlayerState:
			_states[StringName(child.name)] = child


func transition_to(target: StringName, data: Dictionary = {}) -> void:
	if not _states.has(target):
		push_error("State tidak ditemukan: %s" % target)
		return

	var next_state: PlayerState = _states[target]
	var force_restart := bool(data.get("force_restart", false))
	if current_state == next_state and not force_restart:
		return

	var previous := current_state_name
	if current_state != null:
		current_state.exit()

	current_state = next_state
	current_state_name = target
	current_state.enter(previous, data)


func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func is_current_state_invulnerable() -> bool:
	return current_state != null and current_state.is_invulnerable()


func try_current_state_parry(source: Node, amount: int) -> bool:
	if current_state == null:
		return false
	return current_state.try_parry(source, amount)
