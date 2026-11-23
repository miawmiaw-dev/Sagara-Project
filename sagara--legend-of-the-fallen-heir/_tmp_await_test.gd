extends SceneTree

class Waiter:
	extends Node
	var marker := "waiter"

	func start() -> void:
		await get_tree().create_timer(0.3).timeout
		print("[AWAIT-TEST] resumed marker=", marker)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var node := Waiter.new()
	root.add_child(node)
	node.start()
	await create_timer(0.05).timeout
	node.queue_free()
	await create_timer(0.6).timeout
	print("[AWAIT-TEST] done")
	quit(0)
