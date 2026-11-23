class_name ItemDropSpawner
extends RefCounted

const DEFAULT_PICKUP_SCENE := preload("res://scenes/items/item_pickup.tscn")


static func spawn_table(
	table: ItemDropTable,
	parent: Node,
	at_position: Vector2
) -> Array[Node]:
	var spawned: Array[Node] = []
	if table == null or not _can_spawn_in(parent):
		return spawned

	for data in table.roll_drops():
		var pickup := spawn_pickup(data, parent, at_position)
		if pickup != null:
			spawned.append(pickup)
	return spawned


static func spawn_pickup(data: ItemDropData, parent: Node, at_position: Vector2) -> Node:
	if data == null or not _can_spawn_in(parent):
		return null

	var scene := data.pickup_scene
	if scene == null:
		scene = DEFAULT_PICKUP_SCENE
	if scene == null:
		push_warning("ItemDropSpawner: pickup scene untuk '%s' tidak tersedia." % data.item_id)
		return null

	var pickup := scene.instantiate()
	if pickup == null:
		push_warning("ItemDropSpawner: gagal membuat pickup '%s'." % data.item_id)
		return null

	if pickup.has_method("setup"):
		pickup.call("setup", data)

	parent.add_child(pickup)

	if pickup is Node2D:
		(pickup as Node2D).global_position = at_position + _get_scatter(data)

	return pickup


static func _can_spawn_in(parent: Node) -> bool:
	return parent != null and not parent.is_queued_for_deletion()


static func _get_scatter(data: ItemDropData) -> Vector2:
	var radius := maxf(data.scatter_radius, 0.0)
	if is_zero_approx(radius):
		return Vector2.ZERO
	return Vector2(
		randf_range(-radius, radius),
		randf_range(-radius, -radius * 0.35)
	)
