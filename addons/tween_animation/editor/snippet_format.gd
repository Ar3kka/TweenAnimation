@tool
extends RefCounted
## Shared presentation for copied and displayed tutorial/reference examples.

const ARGUMENTS := {
	"create": "name is the dictionary key; owner binds this Tween's lifetime to a Node (optional if a default owner is set).",
	"store": "name is the dictionary key; tween is the existing handle, not a copy. Optional replace defaults to true and kills the old entry.",
	"get_tween": "name is the stored key; a missing or finished entry returns null.",
	"has_tween": "name is the stored key to check for a live Tween.",
	"pause": "name identifies the stored Tween to pause at its current progress.",
	"resume": "name identifies the paused Tween to continue from its current progress.",
	"stop_named": "name identifies the stored Tween to kill, not pause.",
	"release": "name identifies the Tween to remove from tracking; the returned handle keeps playing.",
	"clear": "kill_tweens: true kills registered Tweens; false removes names while leaving playback running. Defaults to true.",
	"stop": "target is the animated object; optional property limits cancellation to that helper channel.",
	"custom": "target is the object; property is its property path; value is the destination; duration is seconds. Optional transition overrides the curve.",
	"move_to": "target is the node; value is its destination in parent coordinates (Vector2 for 2D/UI, Vector3 for 3D); duration is seconds.",
	"move_by": "target is the node; offset is added to its current position (Vector2 for 2D/UI, Vector3 for 3D); duration is seconds.",
	"move_left": "target is the node; distance moves along parent -X (pixels in 2D/UI, scene units in 3D); duration is seconds.",
	"move_right": "target is the node; distance moves along parent +X (pixels in 2D/UI, scene units in 3D); duration is seconds.",
	"move_up": "target is the node; distance moves along -Y in 2D/UI or +Y in 3D; duration is seconds.",
	"move_down": "target is the node; distance moves along +Y in 2D/UI or -Y in 3D; duration is seconds.",
	"move_forward": "target is a Node3D; distance moves along parent -Z in scene units; duration is seconds.",
	"move_back": "target is a Node3D; distance moves along parent +Z in scene units; duration is seconds.",
	"scale_to": "target is the node; value is the final scale (a uniform number or matching Vector2/Vector3); duration is seconds.",
	"scale_up": "target is the node; amount is a relative increase (0.1 = 10% larger); duration is seconds.",
	"scale_down": "target is the node; amount is a relative decrease (0.1 = 10% smaller); duration is seconds.",
	"rotate_to": "target is the node; radians is an absolute angle (number for 2D/UI, Vector3 for 3D); duration is seconds.",
	"rotate_degrees": "target is the node; degrees is an absolute angle (number for 2D/UI, Vector3 for 3D); duration is seconds.",
	"press": "target is the node. Optional amount = shrink fraction (default 0.05); duration_down = 0.1s and duration_up = 0.2s by default.",
	"wiggle": "target is the node; strength is radians; duration is total seconds; loops is the number of wiggles.",
	"fade_to": "target is a CanvasItem; alpha is the destination opacity (0 = invisible, 1 = opaque); duration is seconds.",
	"fade_in": "target is a CanvasItem; duration is seconds to reach alpha 1 (fully opaque).",
	"fade_out": "target is a CanvasItem; duration is seconds to reach alpha 0 (invisible).",
	"resize_to": "target is a Control; value is its final width/height in a Vector2; duration is seconds. Containers may override size.",
	"set_volume": "target is an audio player; decibels is the destination volume (-12 is quieter than 0); duration is seconds.",
	"shader_transition": "material is the ShaderMaterial; parameter is the uniform name; value is its destination; duration is seconds. Set a default owner first.",
	"method": "callback receives each sampled value; from/to are the start/end values; duration is seconds. Set a default owner first.",
	"tween_property": "target is the object; property is its property path; the next value is the destination; duration is seconds.",
	"tween_interval": "The number is a delay in seconds, appended to this Tween's sequence.",
	"tween_callback": "The callable runs when this step is reached; it is not called while constructing the sequence.",
	"set_parallel": "true makes appended steps run together; chain() starts the following sequential group.",
	"set_trans": "The enum selects the shape of the motion curve for subsequently appended steps.",
	"set_ease": "The enum selects which part of the motion accelerates/decelerates.",
	"set_indexed": "The property path selects the field/subfield; the value sets its starting state immediately.",
}

const NATIVE_NAMES := {
	"TweenProperty": "tween_property", "TweenInterval": "tween_interval",
	"TweenCallback": "tween_callback", "SetParallel": "set_parallel",
	"SetTrans": "set_trans", "SetEase": "set_ease",
}

static var _interval_methods: Dictionary = {}


static func prepare(source: String, csharp: bool = false) -> String:
	if _interval_methods.is_empty():
		var runtime: Script = preload("res://addons/tween_animation/src/tweenimator.gd")
		for method in runtime.get_script_method_list():
			if not str(method.name).begins_with("_"):
				for argument in method.args:
					if argument.name == "interval":
						_interval_methods[str(method.name)] = true
	var marker := "// Arguments: " if csharp else "# Arguments: "
	var continuation := "//   " if csharp else "#   "
	var calls := RegEx.new()
	calls.compile('\\.(?:Call\\("([^"]+)"|([a-zA-Z_]+)\\s*\\()')
	var seen := {}
	var lines := PackedStringArray()
	for line in source.replace("\r\n", "\n").split("\n"):
		var trimmed := line.strip_edges()
		# Regenerate our own annotations so theme refreshes never duplicate them.
		if trimmed.begins_with(marker) or trimmed.begins_with(continuation):
			continue
		if not trimmed.begins_with("#") and not trimmed.begins_with("//"):
			var indent := line.substr(0, line.length() - line.lstrip(" \t").length())
			if ("Tweenimator.new(" in line or ".New(" in line) and not seen.has("constructor"):
				var owner_name := "this" if csharp else "self"
				_append_note(lines, indent, marker, continuation, "new(owner, transition): owner is optional. With no owner, node effects bind to their target; passing " + owner_name + " binds them to this controller's lifetime. Optional transition sets the curve (Sine by default).")
				seen["constructor"] = true
			for call in calls.search_all(line):
				var method_name: String = call.get_string(1) if not call.get_string(1).is_empty() else call.get_string(2)
				method_name = NATIVE_NAMES.get(method_name, method_name)
				if ARGUMENTS.has(method_name) and not seen.has(method_name):
					var description := str(ARGUMENTS[method_name])
					if _interval_methods.has(method_name):
						description += " Optional final interval = seconds to wait after the whole effect (default 0, no wait)."
					_append_note(lines, indent, marker, continuation, method_name + " — " + description)
					seen[method_name] = true
		if trimmed.is_empty() and not lines.is_empty() and lines[-1].strip_edges() == "{":
			continue
		lines.append(line if not trimmed.is_empty() else "")
	while not lines.is_empty() and lines[0].is_empty():
		lines.remove_at(0)
	while not lines.is_empty() and lines[-1].is_empty():
		lines.remove_at(lines.size() - 1)
	return "\n".join(lines)


static func _append_note(lines: PackedStringArray, indent: String, marker: String, continuation: String, text: String) -> void:
	var current := ""
	var prefix := marker
	for word in text.split(" "):
		if current.length() + word.length() + 1 > 90:
			lines.append(indent + prefix + current)
			prefix = continuation
			current = ""
		current += (" " if not current.is_empty() else "") + word
	if not current.is_empty():
		lines.append(indent + prefix + current)
