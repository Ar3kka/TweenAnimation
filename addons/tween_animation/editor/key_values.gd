@tool
extends RefCounted
## Shared value descriptions and literal parsing for real and practice key capture.

const CONSTRUCTORS := {
	TYPE_VECTOR2: ["Vector2", 2], TYPE_VECTOR2I: ["Vector2i", 2],
	TYPE_VECTOR3: ["Vector3", 3], TYPE_VECTOR3I: ["Vector3i", 3],
	TYPE_VECTOR4: ["Vector4", 4], TYPE_VECTOR4I: ["Vector4i", 4],
	TYPE_COLOR: ["Color", 4], TYPE_RECT2: ["Rect2", 4], TYPE_RECT2I: ["Rect2i", 4],
	TYPE_QUATERNION: ["Quaternion", 4], TYPE_BASIS: ["Basis", 9],
	TYPE_TRANSFORM2D: ["Transform2D", 6], TYPE_TRANSFORM3D: ["Transform3D", 12],
}


static func property_info(target: Object, path: String) -> Dictionary:
	var parts := path.split(":")
	var owner: Variant = target
	for index in parts.size():
		if not owner is Object or not is_instance_valid(owner):
			return {}
		for info in owner.get_property_list():
			if str(info.name) == parts[index]:
				if index == parts.size() - 1:
					return info
				owner = owner.get_indexed(NodePath(parts[index]))
				break
	return {}


static func describe(current: Variant, property: String, info: Dictionary = {}) -> Dictionary:
	var type := typeof(current)
	var label := type_string(type)
	var examples := PackedStringArray()
	match type:
		TYPE_FLOAT:
			label += " · a finite number, decimals allowed"
			examples = ["0.0", "0.5", "1.0"] if property.ends_with(":a") else ["0.0", "100.0", "-25.5"]
			if property.ends_with(":a"):
				label += " · opacity: 0 invisible, 1 opaque"
		TYPE_INT:
			label += " · whole numbers"
			examples = ["0", "1", "10"]
		TYPE_BOOL:
			label += " · true or false"
			examples = ["true", "false"]
		TYPE_STRING, TYPE_STRING_NAME:
			label += " · text in double quotes"
			examples = ['"Hello"', '"Ready"']
		TYPE_VECTOR2, TYPE_VECTOR2I:
			label += " · X, Y"
			examples = [str(CONSTRUCTORS[type][0]) + "(0, 0)", str(CONSTRUCTORS[type][0]) + "(100, 50)"]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			label += " · X, Y, Z"
			examples = [str(CONSTRUCTORS[type][0]) + "(0, 0, 0)", str(CONSTRUCTORS[type][0]) + "(2, 0, 0)"]
		TYPE_VECTOR4, TYPE_VECTOR4I:
			label += " · X, Y, Z, W"
			examples = [str(CONSTRUCTORS[type][0]) + "(0, 0, 0, 1)"]
		TYPE_COLOR:
			label += " · red, green, blue, alpha (usually 0–1)"
			examples = ["Color(1, 1, 1, 1)", "Color(1, 0.2, 0.2, 0.5)"]
		TYPE_RECT2, TYPE_RECT2I:
			label += " · X, Y, width, height"
			examples = [str(CONSTRUCTORS[type][0]) + "(0, 0, 100, 50)"]
		_:
			examples = [var_to_str(current)] if CONSTRUCTORS.has(type) else []
	var parts := property.split(":")
	var field := parts[-1]
	if field in ["x", "y", "z", "w", "r", "g", "b", "a"] and parts.size() > 1:
		field = parts[-2]
	if field in ["rotation", "rotation_degrees"] and type in [TYPE_FLOAT, TYPE_VECTOR3]:
		label += " · degrees" if property.contains("degrees") else " · radians"
		var turn := "90" if property.contains("degrees") else "1.570796"
		examples = ["0.0", turn] if type == TYPE_FLOAT else ["Vector3(0, 0, 0)", "Vector3(0, " + turn + ", 0)"]
	elif field == "scale":
		if type == TYPE_FLOAT:
			examples = ["0.5", "1.0", "1.2"]
		elif type in [TYPE_VECTOR2, TYPE_VECTOR3]:
			examples = ["Vector3(1, 1, 1)", "Vector3(1.2, 1.2, 1.2)"] if type == TYPE_VECTOR3 else ["Vector2(1, 1)", "Vector2(1.2, 1.2)"]
	elif field in ["position", "global_position"]:
		label += " · parent coordinates"
	if int(info.get("hint", -1)) == PROPERTY_HINT_RANGE:
		var limits := str(info.get("hint_string", "")).split(",")
		if limits.size() >= 2:
			label += " · Inspector range %s to %s" % [limits[0], limits[1]]
			if "radians_as_degrees" in limits:
				label += " degrees"
			elif type in [TYPE_FLOAT, TYPE_INT] and limits[0].is_valid_float() and limits[1].is_valid_float():
				examples.clear()
				for number in [limits[0].to_float(), (limits[0].to_float() + limits[1].to_float()) / 2.0, limits[1].to_float()]:
					examples.append(var_to_str(int(number)) if type == TYPE_INT else var_to_str(number))
	elif int(info.get("hint", -1)) == PROPERTY_HINT_ENUM and type == TYPE_INT:
		var choices := PackedStringArray()
		examples.clear()
		var value := 0
		for option in str(info.get("hint_string", "")).split(","):
			var pair := option.split(":")
			if pair.size() == 2:
				value = pair[1].to_int()
			choices.append("%s = %d" % [pair[0], value])
			if examples.size() < 3:
				examples.append(str(value))
			value += 1
		label += " · " + ", ".join(choices)
	return {"accepted": label, "examples": examples}


static func parse(text: String, current: Variant) -> Dictionary:
	var input := text.strip_edges()
	if input.is_empty():
		return {"ok": current != null, "value": current, "error": "Choose a valid property track first." if current == null else ""}
	var expected := typeof(current)
	var value: Variant = null
	if expected == TYPE_FLOAT and input.is_valid_float():
		value = input.to_float()
	elif expected == TYPE_INT and input.is_valid_int():
		value = input.to_int()
	elif expected == TYPE_BOOL and input in ["true", "false"]:
		value = input == "true"
	elif expected in [TYPE_STRING, TYPE_STRING_NAME]:
		var json := JSON.new()
		if json.parse(input.trim_prefix("&")) == OK and json.data is String:
			value = StringName(json.data) if expected == TYPE_STRING_NAME else json.data
	elif CONSTRUCTORS.has(expected):
		var constructor: Array = CONSTRUCTORS[expected]
		if input.begins_with(str(constructor[0]) + "(") and input.ends_with(")"):
			var arguments := input.substr(str(constructor[0]).length() + 1).trim_suffix(")").split(",", true)
			var valid := arguments.size() == int(constructor[1])
			for number in arguments:
				var component := number.strip_edges()
				valid = valid and component.is_valid_float() and is_finite(component.to_float())
				if expected in [TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I, TYPE_RECT2I]:
					valid = valid and component.is_valid_int()
			# Only a whitelisted constructor with checked numeric arguments reaches the literal parser.
			if valid:
				value = str_to_var(input)
	if (value is Vector2 or value is Vector3 or value is Vector4) and not value.is_finite():
		value = null
	if value != null and (not value is float or is_finite(value)):
		return {"ok": true, "value": value, "error": ""}
	return {"ok": false, "value": null, "error": "Expected %s. Use one of the examples below; expressions and method calls are not value literals." % type_string(expected)}
