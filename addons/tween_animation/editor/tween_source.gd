@tool
extends RefCounted
## Read-only discovery of native Tween and Tweenimator call sites.
## Does not evaluate project expressions or claim runtime-dependent times are exact.

const SYNTAX = preload("res://addons/tween_animation/editor/source_syntax.gd")
const VALUES = preload("res://addons/tween_animation/editor/key_values.gd")
const NATIVE := {"tween_property": ["target", "property", "value", "duration"], "tween_interval": ["duration"], "tween_method": ["callback", "from", "to", "duration"], "tween_callback": ["callback"], "tween_subtween": ["tween"], "tween_await": ["signal"]}
static var helper_methods: Dictionary = {}


static func schemas() -> Dictionary:
	if helper_methods.is_empty():
		var runtime: Script = preload("res://addons/tween_animation/src/tweenimator.gd")
		for method in runtime.get_script_method_list():
			if str(method.name).begins_with("_"):
				continue
			if method.args.any(func(arg): return arg.name == "interval"):
				helper_methods[str(method.name)] = method
	return helper_methods


static func language(path: String) -> String:
	return "cs" if path.get_extension().to_lower() == "cs" else "gd"


static func text_literal(text: String) -> Variant:
	var value := text.strip_edges().trim_prefix("^").trim_prefix("&")
	if value.begins_with("@\""):
		return value.substr(2, value.length() - 3).replace("\"\"", "\"")
	if value.begins_with("'") and value.ends_with("'"):
		return value.substr(1, value.length() - 2)
	var json := JSON.new()
	if json.parse(value) == OK and json.data is String:
		return json.data
	return null


static func literal(text: String, sample: Variant = null) -> Dictionary:
	var value := text.strip_edges().trim_prefix("new ").replace("Godot.", "")
	var suffix := RegEx.new()
	suffix.compile("(?<=[0-9])[fFdDmM]\\b")
	value = suffix.sub(value, "", true)
	var constants := {"Vector2.ZERO": Vector2.ZERO, "Vector2.Zero": Vector2.ZERO, "Vector2.ONE": Vector2.ONE, "Vector2.One": Vector2.ONE, "Vector3.ZERO": Vector3.ZERO, "Vector3.Zero": Vector3.ZERO, "Vector3.ONE": Vector3.ONE, "Vector3.One": Vector3.ONE, "PI": PI, "Mathf.Pi": PI, "true": true, "false": false}
	if constants.has(value):
		return {"ok": true, "value": constants[value]}
	if sample == null:
		if value.is_valid_float():
			sample = 0.0
		elif text_literal(value) != null:
			return {"ok": true, "value": text_literal(value)}
		else:
			for type in VALUES.CONSTRUCTORS:
				if value.begins_with(str(VALUES.CONSTRUCTORS[type][0]) + "("):
					sample = type_convert(null, type)
					break
	if sample == null:
		return {"ok": false, "value": null}
	return VALUES.parse(value, sample)


static func target(expression: String, owner: Node, bindings: Dictionary, depth: int = 0) -> Dictionary:
	var result := {"node": null, "object": null, "prefix": ""}
	if depth > 8 or not is_instance_valid(owner):
		return result
	var text := expression.strip_edges()
	var cast := RegEx.new()
	cast.compile("\\s+as\\s+\\w+$|^\\(\\w+\\)\\s*")
	text = cast.sub(text, "", true)
	if text in ["self", "this"]:
		return {"node": owner, "object": owner, "prefix": ""}
	if bindings.has(text):
		return target(str(bindings[text]), owner, bindings, depth + 1)
	var path: Variant = null
	if text.begins_with("$"):
		path = text_literal(text.substr(1)) if text.substr(1).begins_with("\"") else text.substr(1)
	elif text.begins_with("%"):
		path = text
	else:
		var get_node := RegEx.new()
		get_node.compile("^(?:(?:self|this)\\.)?(?:get_node|get_node_or_null|GetNode|GetNodeOrNull)(?:<[^>]+>)?\\((.*)\\)$")
		var found := get_node.search(text)
		if found:
			path = text_literal(found.get_string(1))
	if path is String:
		var node := owner.get_node_or_null(NodePath(path))
		return {"node": node, "object": node, "prefix": ""}
	var dot := text.rfind(".")
	if dot > 0:
		var base := target(text.left(dot), owner, bindings, depth + 1)
		var property := text.substr(dot + 1).to_snake_case()
		if base.object is Object:
			for info in base.object.get_property_list():
				if str(info.name) == property:
					return {"node": base.node, "object": base.object.get(property), "prefix": str(base.prefix) + property + ":"}
	return result


static func _bindings(source: String) -> Dictionary:
	var result := {}
	var pattern := RegEx.new()
	pattern.compile("(?m)^[ \\t]*(?:(?:@onready|@export|private|public|protected|readonly|static)[ \\t]+)*(?:var|[A-Za-z_][\\w<>.?]*)[ \\t]+([A-Za-z_]\\w*)[^=\\n]*=(?!=)[ \\t]*(.+)$")
	for found in pattern.search_all(source):
		result[found.get_string(1)] = found.get_string(2).strip_edges().trim_suffix(";")
	var arrows := RegEx.new()
	arrows.compile("(?m)^[ \\t]*(?:private|public|protected)[ \\t]+[^\\n=]+[ \\t]+([A-Za-z_]\\w*)[ \\t]*=>[ \\t]*(.+);")
	for found in arrows.search_all(source):
		result[found.get_string(1)] = found.get_string(2)
	return result


static func _number(args: Array, index: int, fallback: float) -> Variant:
	if index >= args.size():
		return fallback
	var parsed := literal(str(args[index].text), 0.0)
	return parsed.value if parsed.ok and is_finite(float(parsed.value)) and float(parsed.value) >= 0 else null


static func _root_receiver(receiver: String) -> String:
	return receiver.get_slice(".", 0).get_slice("(", 0)


static func _handle_kind(expression: String, bindings: Dictionary) -> String:
	if "create_tween" in expression.to_snake_case():
		return "created"
	var pattern := RegEx.new()
	pattern.compile("^([A-Za-z_]\\w*)\\.([A-Za-z_]\\w*)\\(")
	var found := pattern.search(expression.strip_edges())
	if found:
		var manager: String = str(bindings.get(found.get_string(1), ""))
		if "Tweenimator" in manager or "TweenAnimation" in manager or "tweenimator.gd" in manager:
			var api := found.get_string(2).to_snake_case()
			if api == "call":
				var first := expression.substr(expression.find("(") + 1).get_slice(",", 0).trim_suffix(")")
				api = str(text_literal(first))
			if api == "get_tween":
				return "external"
			if api == "create" or schemas().has(api):
				return "created"
	return "unknown"


static func _blank(text: String) -> String:
	var result := ""
	for character in text:
		result += "\n" if character == "\n" else " "
	return result


static func analyze(source: String, path: String, owner: Node, selected: Node) -> Dictionary:
	var lang := language(path)
	var methods := SYNTAX.methods(source, lang)
	var operations: Array[Dictionary] = []
	var class_source := source
	for index in range(methods.size() - 1, -1, -1):
		class_source = class_source.left(methods[index].start) + _blank(source.substr(methods[index].start, methods[index].end - methods[index].start)) + class_source.substr(methods[index].end)
	var global_bindings := _bindings(class_source)
	var helper_schema := schemas()
	for method in methods:
		method.path = path
		method.owner = owner
		method.hash = source.sha256_text()
		method.statements = SYNTAX.statements(source, method)
		var bindings := global_bindings.duplicate()
		var groups := {}
		var clock: Variant = 0.0
		for statement in method.statements:
			# Local definitions shadow class fields; source expressions remain unevaluated.
			bindings.merge(_bindings(str(statement.text)), true)
			var calls := SYNTAX.calls(source, statement)
			var assignment := RegEx.new()
			assignment.compile("(?:var|Tween)[ \\t]+([A-Za-z_]\\w*)[^=]*=")
			var assigned := assignment.search(str(statement.text))
			for call in calls:
				var api: String = call.api
				var args: Array = call.args.duplicate(true)
				var bridge := api == "call" and not args.is_empty()
				if bridge:
					var bridge_name: Variant = text_literal(str(args[0].text))
					if not bridge_name is String or not helper_schema.has(bridge_name):
						continue
					api = bridge_name
					args.remove_at(0)
				var receiver := _root_receiver(str(call.receiver))
				if "create_tween" in str(call.receiver).to_snake_case():
					receiver = assigned.get_string(1) if assigned else "inline@" + str(statement.start)
				var helper := helper_schema.has(api)
				if api in ["set_parallel", "parallel", "chain", "set_speed_scale", "set_loops"]:
					if not groups.has(receiver):
						groups[receiver] = {"end": clock, "base": clock, "parallel": false, "speed": 1.0, "loops": 1.0, "next_parallel": false, "next_chain": false}
					var group: Dictionary = groups[receiver]
					if api == "set_parallel":
						group.parallel = args.is_empty() or str(args[0].text).to_lower() == "true"
					elif api == "parallel":
						group.next_parallel = true
					elif api == "chain":
						group.next_chain = true
					elif api == "set_speed_scale":
						group.speed = _number(args, 0, 1.0)
					elif api == "set_loops":
						group.loops = _number(args, 0, 0.0)
					continue
				if not helper and not NATIVE.has(api):
					continue
				var names: Array = []
				if helper:
					for argument in helper_schema[api].args:
						names.append(str(argument.name))
				else:
					names = NATIVE[api].duplicate()
				var values := {}
				for index in mini(args.size(), names.size()):
					values[names[index]] = args[index]
				var target_expression: String = str(values.get("target", values.get("material", {"text": ""})).text)
				var resolved := target(target_expression, owner, bindings)
				var property: Variant = text_literal(str(values.get("property", {"text": ""}).text))
				if helper:
					property = _helper_property(api, property)
					if api == "shader_transition":
						var parameter: Variant = text_literal(str(values.get("parameter", {"text": ""}).text))
						property = "shader_parameter/" + parameter if parameter is String else null
				var sample: Variant = null
				if resolved.object is Object and property is String:
					for info in resolved.object.get_property_list():
						if str(info.name) == str(property).get_slice(":", 0):
							sample = resolved.object.get_indexed(NodePath(property))
							break
				var duration_index := names.find("duration")
				var fallback := 0.0
				if helper and duration_index >= 0:
					var default_index: int = duration_index - (names.size() - helper_schema[api].default_args.size())
					fallback = float(helper_schema[api].default_args[default_index]) if default_index >= 0 else 0.0
				var duration: Variant = _number(args, duration_index, fallback) if duration_index >= 0 else 0.0
				if api == "press":
					var down: Variant = _number(args, 2, 0.1)
					var up: Variant = _number(args, 3, 0.2)
					duration = down + up if down != null and up != null else null
				if api in ["tween_subtween", "tween_await"]:
					duration = null
				var interval: Variant = _number(args, names.find("interval"), 0.0) if helper else 0.0
				var sequence := receiver if not helper and not receiver.is_empty() else "call@" + str(call.start)
				if not groups.has(sequence):
					var external: bool = not helper and _handle_kind(str(bindings.get(receiver, "")), bindings) != "created" and "create_tween" not in str(call.receiver).to_snake_case()
					groups[sequence] = {"end": null if external else clock, "base": null if external else clock, "parallel": false, "speed": 1.0, "loops": 1.0, "next_parallel": false, "next_chain": false}
				var state: Dictionary = groups[sequence]
				var parallel: bool = state.parallel or state.next_parallel or ".parallel()" in str(call.receiver).to_lower()
				var chained: bool = state.next_chain or ".chain()" in str(call.receiver).to_lower()
				state.next_parallel = false
				state.next_chain = false
				var start: Variant = state.base if parallel and not chained else state.end
				if not parallel or chained:
					state.base = state.end
				var delay: Variant = 0.0
				for modifier in calls:
					if modifier.start >= call.end and modifier.api == "set_delay":
						delay = _number(modifier.args, 0, 0.0)
				if statement.conditional or call.deferred:
					start = null
				if start != null and delay != null:
					start += delay
				var finish: Variant = start + duration + interval if start != null and duration != null and interval != null else null
				state.end = maxf(float(state.end), float(finish)) if state.end != null and finish != null else null
				var receiver_expression: String = str(bindings.get(receiver, ""))
				var native_receiver: bool = _handle_kind(receiver_expression, bindings) != "unknown" or "create_tween" in str(call.receiver).to_snake_case() or method.parameters.any(func(parameter): return parameter.name == receiver and "Tween" in parameter.type)
				var verified: bool = (native_receiver if not helper else bridge or "Tweenimator" in receiver_expression or "TweenAnimation" in receiver_expression or "tweenimator.gd" in receiver_expression)
				var entry := {"id": path + ":" + str(owner.get_instance_id()) + ":" + str(call.start), "path": path, "hash": method.hash, "language": lang, "method": method, "statement": statement, "call": call, "api": api, "args": args, "names": names, "helper": helper, "bridge": bridge, "receiver": str(call.receiver), "sequence": sequence, "target_expression": target_expression, "target": resolved.node, "object": resolved.object, "property": str(resolved.prefix) + str(property) if property is String else "", "local_property": property, "sample": sample, "start": start, "duration": duration, "interval": interval, "end": finish, "delay": delay, "parallel": parallel, "conditional": statement.conditional or call.deferred, "verified": verified, "line": call.line, "bindings": bindings.duplicate(), "relevant": resolved.node == selected, "potential": resolved.node == null and (owner == selected or owner.is_ancestor_of(selected))}
				operations.append(entry)
				if helper:
					if assigned:
						groups[assigned.get_string(1)] = state
				if "await " in str(statement.text):
					clock = finish
			var await_pattern := RegEx.new()
			await_pattern.compile("await[ \\t]+([A-Za-z_]\\w*)\\.finished|await[ \\t]+ToSignal\\([ \\t]*([A-Za-z_]\\w*)")
			var awaited := await_pattern.search(str(statement.text))
			if awaited:
				var handle := awaited.get_string(1) if not awaited.get_string(1).is_empty() else awaited.get_string(2)
				clock = groups[handle].end if groups.has(handle) else null
			elif "await " in str(statement.text) and not calls.any(func(call): return helper_schema.has(call.api) or call.api == "call"):
				clock = null
		# Speed and loops configure the Tween itself, including preceding operations.
		var complex_timing := groups.values().any(func(group): return group.speed == null or group.speed != 1.0 or group.loops == null or group.loops != 1.0)
		for operation in operations:
			if operation.method.id != method.id or operation.path != path:
				continue
			var state: Dictionary = groups[operation.sequence]
			operation.loops = state.loops
			if complex_timing:
				operation.start = null
				operation.end = null
				operation.timing_note = "Loop/speed configuration: runtime schedule"
	for operation in operations:
		if operation.target == null and operation.api in ["tween_interval", "tween_callback", "tween_method", "tween_subtween", "tween_await"]:
			operation.related_sequence = operations.any(func(other): return other.method.id == operation.method.id and other.sequence == operation.sequence and other.relevant)
			operation.potential = operation.potential or operation.related_sequence
	return {"path": path, "hash": source.sha256_text(), "source": source, "language": lang, "methods": methods, "operations": operations}


static func _helper_property(api: String, fallback: Variant) -> Variant:
	if api.begins_with("move_"):
		return "position"
	if api.begins_with("scale_") or api == "press":
		return "scale"
	if api in ["rotate_to", "wiggle"]:
		return "rotation"
	if api == "rotate_degrees":
		return "rotation_degrees"
	if api.begins_with("fade_"):
		return "modulate:a"
	if api == "resize_to":
		return "size"
	if api == "set_volume":
		return "volume_db"
	return fallback
