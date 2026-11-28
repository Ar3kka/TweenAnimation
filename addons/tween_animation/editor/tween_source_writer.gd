@tool
extends RefCounted
## Optimistic source edits: preserve untouched text and reject stale snapshots.
## The UI supplies data/bindings/locations, never requires code in Visual mode.

const SYNTAX = preload("res://addons/tween_animation/editor/source_syntax.gd")
const MODEL = preload("res://addons/tween_animation/editor/tween_source.gd")

static func encode(value: Variant, language: String) -> String:
	if language == "gd":
		return var_to_str(value)
	if value is String:
		return JSON.stringify(value)
	if value is StringName:
		return "new Godot.StringName(" + JSON.stringify(str(value)) + ")"
	if value is bool:
		return "true" if value else "false"
	if value is int:
		return str(value)
	if value is float:
		return str(value) + "f" if is_finite(value) else ""
	var type := typeof(value)
	var constructors := preload("res://addons/tween_animation/editor/key_values.gd").CONSTRUCTORS
	if constructors.has(type):
		var gd := var_to_str(value)
		var name: String = constructors[type][0]
		var args := gd.substr(name.length() + 1).trim_suffix(")").split(",")
		for index in args.size():
			args[index] = args[index].strip_edges() + ("" if type in [TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I, TYPE_RECT2I] else "f")
		return "new Godot." + name + "(" + ", ".join(args) + ")"
	return ""


static func node_expression(owner: Node, target: Node, language: String) -> String:
	if owner == target:
		return "self" if language == "gd" else "this"
	var path := str(owner.get_path_to(target))
	return "get_node(" + JSON.stringify(path) + ")" if language == "gd" else "GetNode(" + JSON.stringify(path) + ")"


static func binding(data: Dictionary, owner: Node, target: Node, property: String, method: Dictionary, language: String) -> Dictionary:
	var mode := str(data.get("mode", "constant"))
	if mode == "keep":
		return {"ok": true, "text": str(data.text)}
	if mode == "parameter":
		var name := str(data.get("name", ""))
		for parameter in method.parameters:
			if parameter.name != name:
				continue
			var declared := str(parameter.type).to_lower().trim_prefix("godot.")
			var expected := type_string(typeof(data.get("value"))).to_lower()
			var numbers := ["float", "double", "single", "int", "int32", "int64", "long"]
			if declared not in ["variant", "var", "object"] and declared != expected and not (declared in numbers and expected in numbers):
				return {"ok": false, "error": "Choose a method parameter matching " + expected + "; " + name + " is " + declared + "."}
			return {"ok": true, "text": name}
		return {"ok": false, "error": "Choose a parameter declared by this method."}
	var value: Variant = data.get("value")
	var encoded := encode(value, language)
	if encoded.is_empty():
		return {"ok": false, "error": "This value cannot be generated as a safe literal."}
	if mode == "constant":
		return {"ok": true, "text": encoded}
	var expression := node_expression(owner, target, language)
	var field := str(data.get("property", property)) if mode == "property" else property
	if language == "gd":
		expression += ".get_indexed(^" + JSON.stringify(field) + ")"
	else:
		expression += ".GetIndexed(new Godot.NodePath(" + JSON.stringify(field) + "))"
	if mode == "property":
		var actual: Variant = target.get_indexed(NodePath(field))
		if typeof(actual) != typeof(value) and not ((actual is float or actual is int) and (value is float or value is int)):
			return {"ok": false, "error": "Choose a node property with the same value type as the animated property."}
		return {"ok": true, "text": expression}
	if mode == "relative":
		if language == "cs":
			var conversions := {TYPE_VECTOR2: "AsVector2", TYPE_VECTOR3: "AsVector3", TYPE_VECTOR4: "AsVector4", TYPE_COLOR: "AsColor", TYPE_INT: "AsInt64", TYPE_FLOAT: "AsDouble"}
			if not conversions.has(typeof(value)):
				return {"ok": false, "error": "Relative binding needs a numeric, vector or color offset."}
			expression += "." + str(conversions[typeof(value)]) + "()"
		return {"ok": true, "text": expression + " + " + encoded}
	return {"ok": false, "error": "Unknown binding choice."}


static func patch_arguments(source: String, operation: Dictionary, changes: Dictionary) -> Dictionary:
	if source.sha256_text() != operation.hash:
		return {"ok": false, "error": "The script changed. Rescan before applying this edit."}
	if not operation.verified:
		return {"ok": false, "error": "The receiver is not verified as Tween/Tweenimator. This call is source-only."}
	var edits: Array[Dictionary] = []
	var args: Array = operation.args
	var appended := {}
	for key in changes:
		var index: int = key if key is int else operation.names.find(str(key))
		if index < 0 or index >= operation.names.size():
			return {"ok": false, "error": "Unknown parameter."}
		if index < args.size():
			edits.append({"start": args[index].start, "end": args[index].end, "text": str(changes[key])})
		else:
			appended[index] = changes[key]
	if not appended.is_empty():
		var schema: Dictionary = MODEL.schemas().get(operation.api, {})
		var defaults: Array = schema.get("default_args", [])
		var names: Array = operation.names
		var tail := ""
		var last: int = appended.keys().max()
		for index in range(args.size(), last + 1):
			var expression := str(appended.get(index, ""))
			if expression.is_empty():
				var default_index := index - (names.size() - defaults.size())
				if default_index < 0 or default_index >= defaults.size():
					return {"ok": false, "error": "A required earlier argument is missing."}
				expression = encode(defaults[default_index], operation.language)
			tail += (", " if not args.is_empty() or index > args.size() else "") + expression
		var closing: int = operation.call.end - 1
		edits.append({"start": closing, "end": closing, "text": tail})
	return _edits(source, edits)


static func _edits(source: String, edits: Array[Dictionary]) -> Dictionary:
	edits.sort_custom(func(a, b): return a.start > b.start)
	var right := source.length() + 1
	for edit in edits:
		if edit.end > right or edit.start < 0 or edit.end < edit.start:
			return {"ok": false, "error": "Source ranges overlap; rescan before editing."}
		source = source.left(edit.start) + str(edit.text) + source.substr(edit.end)
		right = edit.start
	return {"ok": true, "source": source}


static func location(source: String, method: Dictionary, anchor: Dictionary) -> Dictionary:
	var kind := str(anchor.get("kind", "end"))
	var indent := str(method.indent) + ("\t" if method.language == "gd" else "    ")
	if not method.statements.is_empty():
		indent = str(method.statements[0].indent)
	if kind in ["before", "after"]:
		for statement in method.statements:
			if statement.start == int(anchor.get("start", -1)):
				if statement.block:
					return {"ok": false, "error": "Choose a complete statement, not a block header."}
				return {"ok": true, "offset": statement.start if kind == "before" else statement.end, "indent": statement.indent}
		return {"ok": false, "error": "That placement no longer exists. Rescan the script."}
	if kind == "start":
		return {"ok": true, "offset": method.body, "indent": indent}
	# End of a method must stay outside nested branches; insert before a final return.
	for index in range(method.statements.size() - 1, -1, -1):
		var statement: Dictionary = method.statements[index]
		if not statement.conditional and not statement.block and str(statement.text).strip_edges().begins_with("return"):
			return {"ok": true, "offset": statement.start, "indent": statement.indent}
	var offset := int(method.end)
	if method.language == "gd":
		while offset > int(method.body) and source[offset - 1] in [" ", "\t", "\n", "\r"]:
			offset -= 1
	return {"ok": true, "offset": offset, "indent": indent}


static func insert_property(source: String, method: Dictionary, anchor: Dictionary, target: Node, property: String, destination: Dictionary, duration: Dictionary, interval: Dictionary, sequence: String = "auto", manager: Dictionary = {}) -> Dictionary:
	if source.sha256_text() != method.hash:
		return {"ok": false, "error": "The script changed. Rescan before adding a key."}
	if method.static:
		return {"ok": false, "error": "Choose an instance method so the animation has a node owner."}
	var place := location(source, method, anchor)
	if not place.ok:
		return place
	var resolved_value := binding(destination, method.owner, target, property, method, method.language)
	var resolved_duration := binding(duration, method.owner, target, property, method, method.language)
	var resolved_interval := binding(interval, method.owner, target, property, method, method.language)
	for result in [resolved_value, resolved_duration, resolved_interval]:
		if not result.ok:
			return result
	var receiver := ""
	if sequence == "auto":
		var pattern := RegEx.new()
		pattern.compile("(?:var|Tween)[ \\t]+([A-Za-z_]\\w*)[^=]*=[^;\\n]*(?:create_tween|CreateTween)\\(")
		for statement in method.statements:
			if statement.end <= place.offset and not statement.conditional:
				var assigned := pattern.search(statement.text)
				if assigned:
					receiver = assigned.get_string(1)
	var declarations := ""
	if receiver.is_empty():
		receiver = "tweenimation_step"
		var suffix := 1
		while receiver in source:
			receiver = "tweenimation_step_" + str(suffix)
			suffix += 1
		declarations = ("var " + receiver + " := create_tween()" if method.language == "gd" else "var " + receiver + " = CreateTween();") + "\n" + str(place.indent)
	var global_declaration := ""
	var global_offset := -1
	var helper_instance := ""
	var helper_name := ""
	if not manager.is_empty():
		var instance := str(manager.get("instance", ""))
		var tween_name := str(manager.get("name", "")).strip_edges()
		if tween_name.is_empty():
			return {"ok": false, "error": "Give this Tween a name for its Tweenimator registry."}
		var manager_declaration := ""
		if instance.is_empty():
			instance = "tweenimator"
			while instance in source:
				instance += "_new"
			manager_declaration = ("var " + instance + " := Tweenimator.new(self)" if method.language == "gd" else "var " + instance + ' = GD.Load<Script>("res://addons/tween_animation/src/tweenimator.gd").New(this);') + "\n" + str(place.indent)
			if manager.get("scope", "local") == "global":
				# Node-target helper methods infer their owner when the effect starts.
				global_declaration = (str(method.indent) + "var " + instance + " := Tweenimator.new()" if method.language == "gd" else str(method.indent) + "private Godot.GodotObject " + instance + ' = GD.Load<Script>("res://addons/tween_animation/src/tweenimator.gd").New();') + "\n\n"
				global_offset = source.rfind("\n", maxi(0, int(method.start) - 1)) + 1
				manager_declaration = ""
		helper_instance = instance
		helper_name = tween_name
		declarations = manager_declaration
	var node := node_expression(method.owner, target, method.language)
	var call: String = receiver + (".tween_property(" if method.language == "gd" else ".TweenProperty(") + node + ", " + JSON.stringify(property) + ", " + resolved_value.text + ", " + resolved_duration.text + ")" + ("" if method.language == "gd" else ";")
	var wait: String = resolved_interval.text
	if not (interval.get("mode", "constant") == "constant" and float(interval.get("value", 0.0)) == 0.0):
		call += "\n" + str(place.indent) + receiver + (".tween_interval(" if method.language == "gd" else ".TweenInterval(") + wait + ")" + ("" if method.language == "gd" else ";")
	if not manager.is_empty():
		var api := "custom"
		var value_text: String = resolved_value.text
		if property == "position" and (target is Node2D or target is Node3D or target is Control):
			api = "move_to"
			if destination.get("mode", "constant") == "relative":
				api = "move_by"
				value_text = encode(destination.value, method.language)
		elif property == "scale" and (target is Node2D or target is Node3D or target is Control):
			api = "scale_to"
		elif property == "rotation" and (target is Node2D or target is Node3D or target is Control):
			api = "rotate_to"
		elif property == "rotation_degrees" and (target is Node2D or target is Node3D):
			api = "rotate_degrees"
		elif property == "size" and target is Control:
			api = "resize_to"
		elif property == "modulate:a" and target is CanvasItem:
			api = "fade_to"
		var args := node + ", "
		if api == "custom":
			args += ("^" + JSON.stringify(property) if method.language == "gd" else "new Godot.NodePath(" + JSON.stringify(property) + ")") + ", "
		args += value_text + ", " + resolved_duration.text
		if not (interval.get("mode", "constant") == "constant" and float(interval.get("value", 0.0)) == 0.0):
			args += (", -1" if api == "custom" else "") + ", " + resolved_interval.text
		if method.language == "gd":
			call = "var " + receiver + " := " + helper_instance + "." + api + "(" + args + ")"
			call += "\n" + str(place.indent) + helper_instance + ".store(&" + JSON.stringify(helper_name) + ", " + receiver + ")"
		else:
			call = "var " + receiver + " = (Tween)" + helper_instance + '.Call("' + api + '", ' + args + ').AsGodotObject();'
			call += "\n" + str(place.indent) + helper_instance + '.Call("store", new StringName(' + JSON.stringify(helper_name) + '), ' + receiver + ');'
	var insertion: String = "\n" + str(place.indent) + declarations + call + "\n\n" + str(place.indent)
	var offset := int(place.offset)
	if str(anchor.get("kind", "")) == "before":
		var line_start := source.rfind("\n", maxi(0, offset - 1)) + 1
		if source.substr(line_start, offset - line_start).strip_edges().is_empty():
			offset = line_start
			insertion = str(place.indent) + declarations + call + "\n\n"
	var updated := source.left(offset) + insertion + source.substr(offset)
	var preview_offset := offset
	if global_offset >= 0:
		updated = updated.left(global_offset) + global_declaration + updated.substr(global_offset)
		preview_offset += global_declaration.length()
	return {"ok": true, "source": updated, "line": SYNTAX.line_at(updated, preview_offset), "offset": preview_offset, "inserted_length": insertion.length(), "global_offset": global_offset, "global_lines": global_declaration.count("\n"), "global_length": global_declaration.length(), "sequence": receiver}



static func move_statement(source: String, operation: Dictionary, method: Dictionary, anchor: Dictionary) -> Dictionary:
	if source.sha256_text() != operation.hash or source.sha256_text() != method.hash:
		return {"ok": false, "error": "The script changed. Rescan before moving a key."}
	if operation.method.id != method.id or operation.path != method.path:
		return {"ok": false, "error": "Moving an existing statement across methods can change local variable scope. Create a new key in the destination method instead; the original stays intact."}
	var place := location(source, method, anchor)
	if not place.ok:
		return place
	var statement: Dictionary = operation.statement
	if place.offset >= statement.start and place.offset <= statement.end:
		return {"ok": false, "error": "Choose a different statement or method boundary."}
	if str(statement.text).count("tween_property(") + str(statement.text).count("TweenProperty(") > 1:
		return {"ok": false, "error": "Multiple calls share this statement; move it in the source editor to preserve its structure."}
	# Never move a use above its local receiver's declaration.
	var receiver := str(operation.receiver).get_slice(".", 0)
	for item in method.statements:
		if item.start < statement.start and item.end > place.offset and receiver in str(item.text) and "=" in str(item.text):
			return {"ok": false, "error": "That placement precedes the Tween/manager declaration. Choose a later location."}
	var text := str(statement.text)
	var edits: Array[Dictionary] = [{"start": statement.start, "end": statement.end, "text": ""}, {"start": place.offset, "end": place.offset, "text": "\n" + str(place.indent) + text + "\n" + str(place.indent)}]
	return _edits(source, edits)


static func ensure_ready_method(source: String, language: String) -> Dictionary:
	if language != "gd":
		return {"ok": false, "error": "No editable instance method found. Add a method in Godot .NET and rescan."}
	for method in SYNTAX.methods(source, language):
		if not method.static:
			return {"ok": true, "existing": true, "source": source}
	# Also guard declarations the source index cannot fully parse yet.
	var declaration := RegEx.new()
	declaration.compile("(?m)^[ \t]*(?:static[ \t]+)?func[ \t]+_ready[ \t]*\\(")
	if declaration.search(SYNTAX.mask(source)):
		return {"ok": false, "error": "_ready() already exists but could not be indexed. Check its syntax in Godot; no duplicate was added."}
	return {"ok": true, "source": source + "\n\nfunc _ready() -> void:\n\tpass\n"}


static func validate(source: String, language: String) -> Dictionary:
	if language == "cs":
		# Do not pretend the standard Godot build can compile C#.
		return {"ok": true, "note": "C# syntax is preserved by argument/statement edits; compile with Godot .NET to validate project types."}
	var script := GDScript.new()
	var class_name_line := RegEx.new()
	class_name_line.compile("(?m)^class_name[^\\n]*")
	script.source_code = class_name_line.sub(source, "", true)
	if script.reload() != OK:
		return {"ok": false, "error": "Godot rejected the generated GDScript. The original file was not changed; see Output for the parser error."}
	return {"ok": true}


static func write(path: String, expected_hash: String, source: String) -> Dictionary:
	if not path.begins_with("res://") or "::" in path or path.get_extension() not in ["gd", "cs"]:
		return {"ok": false, "error": "Only external project .gd/.cs source files can be edited here."}
	var original := FileAccess.get_file_as_string(path)
	if original.sha256_text() != expected_hash:
		return {"ok": false, "error": "Source conflict: the file changed. Rescan before applying or undoing."}
	var checked := validate(source, MODEL.language(path))
	if not checked.ok:
		return checked
	var temporary := path + ".tweenimation.tmp"
	var backup := path + ".tweenimation.backup"
	if FileAccess.file_exists(temporary) or FileAccess.file_exists(backup):
		return {"ok": false, "error": "A prior source edit has pending temporary files. Resolve those before another write."}
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not create the source-edit temporary file."}
	file.store_string(source)
	file.flush()
	file.close()
	# FileAccess accepts res:// paths, while DirAccess.rename_absolute requires
	# absolute filesystem paths. Convert all three before the atomic replacement.
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary)
	var absolute_backup := ProjectSettings.globalize_path(backup)
	var moved := DirAccess.rename_absolute(absolute_path, absolute_backup)
	if moved != OK:
		DirAccess.remove_absolute(absolute_temporary)
		return {"ok": false, "error": "Could not preserve the original source file."}
	var replaced := DirAccess.rename_absolute(absolute_temporary, absolute_path)
	if replaced != OK:
		DirAccess.rename_absolute(absolute_backup, absolute_path)
		DirAccess.remove_absolute(absolute_temporary)
		return {"ok": false, "error": "Write failed; the original source was restored."}
	DirAccess.remove_absolute(absolute_backup)
	return {"ok": true, "note": checked.get("note", "")}
