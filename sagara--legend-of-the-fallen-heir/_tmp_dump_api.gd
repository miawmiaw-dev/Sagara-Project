extends SceneTree


func _initialize() -> void:
	var data: Dictionary = {}
	for class_name_value in ClassDB.get_class_list():
		var class_name_str := str(class_name_value)
		var entry: Dictionary = {
			"properties": [],
			"methods": [],
			"signals": [],
			"constants": [],
		}
		for property_info in ClassDB.class_get_property_list(class_name_str, false):
			entry["properties"].append(str(property_info.get("name", "")))
		for method_info in ClassDB.class_get_method_list(class_name_str, false):
			entry["methods"].append(str(method_info.get("name", "")))
		for signal_info in ClassDB.class_get_signal_list(class_name_str, false):
			entry["signals"].append(str(signal_info.get("name", "")))
		for constant_name in ClassDB.class_get_integer_constant_list(class_name_str, false):
			entry["constants"].append(str(constant_name))
		data[class_name_str] = entry

	var file := FileAccess.open("res://_tmp_api.json", FileAccess.WRITE)
	if file == null:
		push_error("cannot write api json")
		quit(1)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[API] classes=", data.size())
	quit(0)
