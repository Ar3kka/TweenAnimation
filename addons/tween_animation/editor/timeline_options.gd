@tool
extends RefCounted
## Property discovery and editable keyframe templates. Never changes a scene node.

const SPATIAL := ["move_to", "move_by", "move_left", "move_right", "move_up", "move_down", "scale_to", "scale_up", "scale_down", "rotate_to", "rotate_degrees", "press", "wiggle"]

static func properties(target: Object, prefix: String = "", depth: int = 0) -> PackedStringArray:
	var result := PackedStringArray()
	if not is_instance_valid(target):
		return result
	for info in target.get_property_list():
		if (int(info.usage) & (PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_SCRIPT_VARIABLE)) == 0 or (int(info.usage) & PROPERTY_USAGE_READ_ONLY) != 0:
			continue
		var path := prefix + str(info.name)
		var type := int(info.type)
		if type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2, TYPE_RECT2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_COLOR, TYPE_QUATERNION, TYPE_BASIS, TYPE_TRANSFORM2D, TYPE_TRANSFORM3D]:
			result.append(path)
			var components := "xyzw".left(2 if type == TYPE_VECTOR2 else (3 if type == TYPE_VECTOR3 else 4)) if type in [TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4] else ("rgba" if type == TYPE_COLOR else "")
			for component in components:
				result.append(path + ":" + component)
		elif type == TYPE_OBJECT and depth < 1:
			var resource: Variant = target.get(info.name)
			if resource is Resource:
				result.append_array(properties(resource, path + ":", depth + 1))
	var priority: Array[String] = []
	if target is Control:
		priority = ["position", "size", "scale", "rotation", "rotation_degrees", "modulate", "modulate:a", "self_modulate", "self_modulate:a", "pivot_offset", "visible"]
	elif target is Node3D:
		priority = ["position", "global_position", "rotation", "rotation_degrees", "scale", "quaternion", "basis", "transform", "global_transform", "visible"]
	elif target is Node2D:
		priority = ["position", "global_position", "rotation", "rotation_degrees", "scale", "modulate", "modulate:a", "skew", "visible"]
	result.sort_custom(func(a: String, b: String) -> bool:
		var property_a := a.get_slice(":", 0)
		var property_b := b.get_slice(":", 0)
		var rank_a := priority.find(property_a)
		var rank_b := priority.find(property_b)
		if rank_a < 0 and rank_b < 0:
			return a < b
		if rank_a < 0:
			return false
		if rank_b < 0:
			return true
		if rank_a == rank_b:
			return a < b
		return rank_a < rank_b
	)
	return result


static func actions(target: Node) -> PackedStringArray:
	var result := PackedStringArray()
	if target is Node2D or target is Node3D or target is Control:
		result.append_array(SPATIAL)
	if target is Node3D:
		result.append_array(["move_forward", "move_back"])
	if target is CanvasItem:
		result.append_array(["fade_to", "fade_in", "fade_out"])
	if target is Control:
		result.append("resize_to")
	if target is AudioStreamPlayer or target is AudioStreamPlayer2D or target is AudioStreamPlayer3D:
		result.append("set_volume")
	return result


static func describe(target: Node, action: String) -> Dictionary:
	var property := "position"
	var label := "Destination"
	var value: Variant = null
	if action.begins_with("scale") or action == "press":
		property = "scale"
	elif action.begins_with("rotate") or action == "wiggle":
		property = "rotation_degrees" if action == "rotate_degrees" else "rotation"
	elif action.begins_with("fade"):
		property = "modulate:a"
	elif action == "resize_to":
		property = "size"
	elif action == "set_volume":
		property = "volume_db"
	var start: Variant = target.get_indexed(NodePath(property))
	value = start
	if action in ["move_left", "move_right", "move_up", "move_down", "move_forward", "move_back"]:
		label = "Distance · scene units" if target is Node3D else "Distance · pixels"
		value = 1.0 if target is Node3D else 100.0
	elif action == "move_by":
		label = "Offset · Vector3" if target is Node3D else "Offset · Vector2"
		value = Vector3(1, 0, 0) if target is Node3D else Vector2(100, 0)
	elif action == "move_to":
		value = start + (Vector3(1, 0, 0) if target is Node3D else Vector2(100, 0))
	elif action == "scale_to":
		value = start * 1.2
	elif action in ["scale_up", "scale_down", "press"]:
		label = "Scale fraction · 0.1 = 10%"
		value = 0.05 if action == "press" else 0.1
	elif action == "wiggle":
		label = "Strength · radians (one wiggle)"
		value = 0.15
	elif action.begins_with("rotate"):
		label = "Destination · degrees" if action == "rotate_degrees" else "Destination · radians"
		var turn := 90.0 if action == "rotate_degrees" else PI / 2.0
		value = start + (Vector3(0, turn, 0) if target is Node3D else turn)
	elif action.begins_with("fade"):
		label = "Destination alpha · 0 to 1"
		value = 0.0 if action == "fade_out" else 1.0
	elif action == "set_volume":
		label = "Destination · decibels"
		value = -12.0
	elif action == "resize_to":
		value = Vector2(240, 100)
	return {"property": property, "label": label, "value": value, "start": start}


static func keys(target: Node, action: String, value: Variant) -> Array:
	if value == null or ((value is float or value is int) and not is_finite(float(value))):
		return []
	if (value is Vector2 or value is Vector3) and not value.is_finite():
		return []
	var spec := describe(target, action)
	var start: Variant = spec.start
	var end: Variant = value
	if action in ["move_left", "move_right", "move_up", "move_down", "move_forward", "move_back"]:
		if not (value is float or value is int) or value < 0:
			return []
		var direction: Vector3 = {"move_left": Vector3.LEFT, "move_right": Vector3.RIGHT, "move_up": Vector3.UP, "move_down": Vector3.DOWN, "move_forward": Vector3.FORWARD, "move_back": Vector3.BACK}[action]
		end = start + direction * value if target is Node3D else start + Vector2(direction.x, -direction.y) * value
	elif action == "move_by":
		if typeof(start) != typeof(value):
			return []
		end = start + value
	elif action in ["scale_up", "scale_down", "press", "wiggle"]:
		if not (value is float or value is int) or value < 0:
			return []
		if action == "wiggle":
			var offset: Variant = Vector3(0, value, 0) if target is Node3D else value
			return [[0.0, start], [0.25, start - offset], [0.5, start], [0.75, start + offset], [1.0, start]]
		end = start * (1.0 + value if action == "scale_up" else 1.0 - clampf(value, 0.0, 1.0))
		if action == "press":
			return [[0.0, start], [0.333333, end], [1.0, start]]
	elif action == "scale_to" and (value is float or value is int):
		end = Vector3.ONE * value if target is Node3D else Vector2.ONE * value
	elif action.begins_with("fade"):
		if not (value is float or value is int):
			return []
		end = clampf(value, 0.0, 1.0)
	if typeof(start) != typeof(end) and not (typeof(start) in [TYPE_INT, TYPE_FLOAT] and typeof(end) in [TYPE_INT, TYPE_FLOAT]):
		return []
	return [[0.0, start], [1.0, end]]
