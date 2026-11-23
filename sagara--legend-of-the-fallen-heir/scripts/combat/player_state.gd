class_name PlayerState
extends Node

var player: SagaraPlayer
var state_machine: PlayerStateMachine


func setup(p_player: SagaraPlayer, p_state_machine: PlayerStateMachine) -> void:
	player = p_player
	state_machine = p_state_machine


func enter(_previous_state: StringName, _data: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func is_invulnerable() -> bool:
	return false


func try_parry(_source: Node, _amount: int) -> bool:
	return false
