extends SceneTree


func _initialize() -> void:
	var shadowed_position := Vector2.ZERO
	print("[WARN-TEST] ", shadowed_position)
	quit(0)


func test_shadowing(position: Vector2, is_visible: bool) -> void:
	print(position, is_visible)
