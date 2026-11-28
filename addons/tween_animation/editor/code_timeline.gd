@tool
extends VBoxContainer
## Source-backed Tween workspace. The Visual view exposes data and placement only.

const MODEL = preload("res://addons/tween_animation/editor/tween_source.gd")
const SYNTAX = preload("res://addons/tween_animation/editor/source_syntax.gd")
const WRITER = preload("res://addons/tween_animation/editor/tween_source_writer.gd")
const FIELD = preload("res://addons/tween_animation/editor/source_value_field.gd")
const OPTIONS = preload("res://addons/tween_animation/editor/timeline_options.gd")
var plugin: EditorPlugin
var selected_node: Node
var mode := 2
var documents: Array[Dictionary] = []
var operations: Array[Dictionary] = []
var visible_operations: Array[Dictionary] = []
var method_picker: OptionButton
var status: Label
var description: Label
var graph: Control
var empty_state_panel: Control
var empty_state_title: Label
var empty_state_detail: Label
var inspector: VBoxContainer
var source_editor: CodeEdit
var source_panel: VBoxContainer
var inspector_scroll: ScrollContainer
var add_button: Button
var jump_button: Button
var _fields: Dictionary = {}
var _operation: Dictionary = {}
var _source_path := ""
var _source_dirty := false
var _busy := false
var _last_write_ok := false
var _span := 1.0
var _new_placement
var _new_dialog: ConfirmationDialog
var _new_feedback: Label
var _new_backend: OptionButton
var _new_manager: OptionButton
var _new_name: LineEdit
var _new_fields: Dictionary = {}
var _new_method_picker: OptionButton
var _new_place_picker: OptionButton
var _new_property_picker: OptionButton
var _new_sequence_picker: OptionButton
var _new_method: Dictionary = {}
var _new_anchors: Array[Dictionary] = []


func build(editor_plugin: EditorPlugin) -> void:
	plugin = editor_plugin
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)
	method_picker = OptionButton.new()
	method_picker.fit_to_longest_item = false
	method_picker.custom_minimum_size.x = 220
	method_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	method_picker.item_selected.connect(func(_index: int): _filter())
	toolbar.add_child(method_picker)
	var rescan_button := _button(toolbar, "", "Reload", rescan)
	rescan_button.custom_minimum_size.x = 36
	rescan_button.tooltip_text = "Rescan Tween calls in the open scene"
	add_button = _button(toolbar, "Add Tween", "Add", _open_new_key)
	add_button.custom_minimum_size.x = 112
	add_button.tooltip_text = "Insert a Tween call at a chosen method and line."
	jump_button = _button(toolbar, "Source line", "Script", _jump_source)
	jump_button.custom_minimum_size.x = 102
	jump_button.disabled = true
	description = _label("Select a node in the Scene tree to map its Tween calls.", 16)
	description.add_theme_font_size_override("font_size", 18)
	add_child(description)
	status = _label("Each lane maps one method call sequence. Select a bar to inspect its Tween and edit supported values.", 13)
	status.modulate.a = 0.72
	add_child(status)
	var split := HSplitContainer.new()
	split.split_offset = 720
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	var timeline_body := VBoxContainer.new()
	timeline_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(timeline_body)
	var lane_header := HBoxContainer.new()
	lane_header.add_theme_constant_override("separation", 14)
	timeline_body.add_child(lane_header)
	var lane_title := _label("METHOD LANES", 12)
	lane_title.custom_minimum_size.x = 120
	lane_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane_title.modulate.a = 0.72
	lane_header.add_child(lane_title)
	_add_legend(lane_header, "Tween", EditorInterface.get_base_control().get_theme_color("accent_color", "Editor"))
	_add_legend(lane_header, "Wait", Color("d9a84e"))
	_add_legend(lane_header, "Runtime", Color("9b8abd"))
	empty_state_panel = _empty_state()
	timeline_body.add_child(empty_state_panel)
	graph = Control.new()
	graph.custom_minimum_size.y = 250
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	graph.tooltip_text = "Click a Tween bar to inspect its parameters and source line."
	graph.draw.connect(_draw_graph)
	graph.gui_input.connect(_graph_input)
	timeline_body.add_child(graph)
	inspector_scroll = ScrollContainer.new()
	inspector_scroll.custom_minimum_size.x = 330
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(inspector_scroll)
	inspector = VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 10)
	inspector_scroll.add_child(inspector)
	source_panel = VBoxContainer.new()
	add_child(source_panel)
	var source_tools := HBoxContainer.new()
	source_panel.add_child(source_tools)
	_button(source_tools, "Save source draft", "Save", _save_source_draft)
	_button(source_tools, "Discard draft", "Reload", _discard_source_draft)
	_button(source_tools, "Open in Godot script editor", "Script", _open_in_editor)
	source_editor = CodeEdit.new()
	source_editor.custom_minimum_size.y = 330
	source_editor.gutters_draw_line_numbers = true
	source_editor.text_changed.connect(func(): _source_dirty = true)
	source_panel.add_child(source_editor)
	_style_source()
	set_content_mode(mode)


func set_content_mode(value: int) -> void:
	mode = clampi(value, 0, 2)
	if is_instance_valid(source_panel):
		source_panel.visible = mode != 2 and not _operation.is_empty()
		inspector_scroll.visible = true


func set_node(node: Node) -> void:
	if node == selected_node and is_instance_valid(node):
		return
	selected_node = node
	rescan()


func rescan() -> void:
	if _busy:
		return
	documents.clear()
	operations.clear()
	_operation = {}
	_fields.clear()
	_clear(inspector)
	method_picker.clear()
	method_picker.add_item("All methods · separate invocations")
	jump_button.disabled = true
	add_button.disabled = not is_instance_valid(selected_node)
	if not is_instance_valid(selected_node):
		description.text = "Select a scene node. Its type is detected automatically."
		_filter()
		return
	var root := plugin.get_editor_interface().get_edited_scene_root()
	if root == null:
		return
	var owners: Array[Node] = [root]
	for child in root.find_children("*", "Node", true, false):
		owners.append(child)
	var seen := {}
	for owner in owners:
		var script: Script = owner.get_script()
		while script != null:
			var path := script.resource_path
			var identity := path + "@" + str(owner.get_instance_id())
			if seen.has(identity):
				break
			seen[identity] = true
			var source := FileAccess.get_file_as_string(path) if "::" not in path and FileAccess.file_exists(path) else script.get_source_code()
			if not source.is_empty():
				var document := MODEL.analyze(source, path, owner, selected_node)
				document.script = script
				documents.append(document)
				for operation in document.operations:
					if operation.relevant or operation.potential:
						operations.append(operation)
				for method in document.methods:
					if owner == selected_node or document.operations.any(func(op): return op.relevant or op.potential):
						method_picker.add_item(path.get_file() + " · " + str(method.name) + "() · L" + str(method.line))
						method_picker.set_item_metadata(method_picker.item_count - 1, method)
			script = script.get_base_script()
	var type := "UI" if selected_node is Control else ("3D" if selected_node is Node3D else ("2D" if selected_node is Node2D else selected_node.get_class()))
	description.text = "%s · %s · %d Tween calls" % [selected_node.name, type, operations.size()]
	status.text = "Source-backed model of scripts on the open scene. Unresolved targets are possible matches; conditional, repeated or computed timing is runtime-dependent."
	_filter()


func _filter() -> void:
	visible_operations.clear()
	var filter: Variant = method_picker.get_item_metadata(method_picker.selected) if method_picker.selected >= 0 else null
	_span = 1.0
	for operation in operations:
		if filter is Dictionary and (operation.path != filter.path or operation.method.id != filter.id or operation.method.owner != filter.owner):
			continue
		visible_operations.append(operation)
		if operation.end != null:
			_span = maxf(_span, float(operation.end))
	graph.custom_minimum_size.y = maxf(250, mini(16, visible_operations.size()) * 54 + 56)
	graph.queue_redraw()
	if visible_operations.is_empty():
		add_button.show()
		_operation = {}
		jump_button.disabled = true
		_clear(inspector)
		inspector_scroll.hide()
		_refresh_empty_state()
		empty_state_panel.show()
		source_panel.hide()
	else:
		add_button.show()
		empty_state_panel.hide()
		inspector_scroll.show()
		_select_operation(0)


func _draw_graph() -> void:
	var foreground := get_theme_color("font_color", "Label")
	var accent := EditorInterface.get_base_control().get_theme_color("accent_color", "Editor")
	var editor := EditorInterface.get_base_control()
	var background := editor.get_theme_color("dark_color_2", "Editor")
	graph.draw_rect(Rect2(Vector2.ZERO, graph.size), background)
	var axis_start := 168.0 if not visible_operations.is_empty() else 12.0
	var width := maxf(graph.size.x - axis_start - 12.0, 1.0)
	var font := get_theme_font("font", "Label")
	for tick in range(6):
		var x := axis_start + width * tick / 5.0
		graph.draw_line(Vector2(x, 34), Vector2(x, graph.size.y - 12), Color(foreground, 0.13))
		graph.draw_string(font, Vector2(x - 18, 23), "%.2f" % (_span * tick / 5.0), HORIZONTAL_ALIGNMENT_CENTER, 44, 12, Color(foreground, 0.78))
	if visible_operations.is_empty():
		return
	for index in mini(visible_operations.size(), 16):
		var operation := visible_operations[index]
		var y := 43.0 + index * 54
		var selected: bool = not _operation.is_empty() and _operation.id == operation.id
		var lane := Rect2(8, y - 4, graph.size.x - 16, 46)
		graph.draw_rect(lane, Color(accent, 0.10) if selected else Color(foreground, 0.025))
		graph.draw_rect(Rect2(8, y - 4, 3, 46), accent if selected else Color(foreground, 0.18))
		graph.draw_string(font, Vector2(20, y + 12), str(operation.method.name) + "()", HORIZONTAL_ALIGNMENT_LEFT, 132, 14, foreground)
		graph.draw_string(font, Vector2(20, y + 31), "LINE " + str(operation.line), HORIZONTAL_ALIGNMENT_LEFT, 132, 11, Color(foreground, 0.6))
		if operation.start == null or operation.duration == null:
			var unknown := Rect2(168, y + 3, width, 34)
			var runtime_color := Color("9b8abd")
			graph.draw_rect(unknown, Color(runtime_color, 0.18))
			graph.draw_rect(unknown, Color(runtime_color, 0.7), false, 1.0)
			graph.draw_string(font, Vector2(180, y + 25), operation.api + "  ·  runtime timing", HORIZONTAL_ALIGNMENT_LEFT, width - 22, 13, foreground)
		else:
			var x := 168 + width * float(operation.start) / _span
			var extent := maxf(12, width * float(operation.duration) / _span)
			var effect_color := Color("d9a84e") if operation.api == "tween_interval" else accent
			var effect := Rect2(x, y + 3, extent, 34)
			graph.draw_rect(effect, Color(effect_color, 0.9 if selected else 0.62))
			graph.draw_circle(Vector2(x, y + 20), 4.5, effect_color.lightened(0.16))
			graph.draw_circle(Vector2(x + extent, y + 20), 4.5, effect_color.lightened(0.16))
			if operation.interval != null and float(operation.interval) > 0:
				var pause := Rect2(x + extent, y + 3, width * float(operation.interval) / _span, 34)
				graph.draw_rect(pause, Color("d9a84e", 0.35))
				graph.draw_line(pause.position, pause.position + Vector2(pause.size.x, 0), Color("d9a84e", 0.8), 1.0)
			var label_color := Color.BLACK if effect_color.get_luminance() > 0.55 else Color.WHITE
			graph.draw_string(font, Vector2(x + 9, y + 25), operation.api, HORIZONTAL_ALIGNMENT_LEFT, maxf(extent - 18, 34), 12, label_color)


func _graph_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := int(floor((event.position.y - 43) / 54))
		if index >= 0 and index < mini(16, visible_operations.size()):
			_select_operation(index)


func _select_operation(index: int) -> void:
	if index < 0 or index >= visible_operations.size():
		return
	_operation = visible_operations[index]
	_fields.clear()
	_clear(inspector)
	jump_button.disabled = false
	var operation_icon := "Animation"
	if _operation.api == "tween_property":
		operation_icon = "Edit"
	elif _operation.api == "tween_callback":
		operation_icon = "Signal"
	_section(inspector, operation_icon, "TWEEN CALL", str(_operation.api) + "()")
	inspector.add_child(_label(_operation.path.get_file() + " · " + str(_operation.method.name) + "() · line " + str(_operation.line), 13))
	inspector.add_child(_label(("Tracked property: " + str(_operation.property)) if not str(_operation.property).is_empty() else "Callback/control operation · original target preserved", 14))
	if not _operation.relevant and not _operation.get("related_sequence", false):
		inspector.add_child(_label("Runtime target: this call may involve the selected node. Source analysis cannot prove that binding.", 14))
	if _operation.start == null:
		inspector.add_child(_label("Runtime scheduling · source/control flow does not provide an exact start time.", 14))
	if not _operation.verified:
		inspector.add_child(_label("Unverified Tween/helper receiver. This call is shown for inspection; visual edits are disabled.", 14))
	var schema: Dictionary = MODEL.schemas().get(_operation.api, {})
	var defaults: Array = schema.get("default_args", [])
	var names: Array = _operation.names
	for argument_index in names.size():
		var name := str(names[argument_index])
		if name in ["target", "material", "property", "callback", "tween", "signal"]:
			continue
		var expression := str(_operation.args[argument_index].text) if argument_index < _operation.args.size() else ""
		var sample: Variant = null
		if name in ["value", "to", "from"]:
			sample = _operation.sample
		elif name in ["duration", "interval", "amount", "strength", "distance", "duration_down", "duration_up", "alpha", "decibels"]:
			sample = 0.0
		elif name in ["loops", "transition"]:
			sample = 1
		if argument_index >= _operation.args.size():
			var default_index := argument_index - (names.size() - defaults.size())
			if default_index >= 0 and default_index < defaults.size():
				sample = defaults[default_index]
		var field = FIELD.new()
		field.build(name + (" · seconds" if "duration" in name or name == "interval" else ""), expression, sample, _operation.method.parameters, OPTIONS.properties(selected_node), name in ["value", "to"])
		inspector.add_child(field)
		_fields[argument_index] = field
	var apply := _button(inspector, "Apply parameters to source", "Save", _apply_parameters)
	apply.disabled = not _operation.verified or "::" in _operation.path
	_button(inspector, "Move this call…", "MoveUp", _open_move)
	_button(inspector, "Jump to source line", "Script", _jump_source)
	_show_source(_operation.path, _operation.line)
	graph.queue_redraw()


func _empty_state() -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = EditorInterface.get_base_control().get_theme_color("dark_color_1", "Editor")
	style.border_color = EditorInterface.get_base_control().get_theme_color("accent_color", "Editor")
	style.border_width_left = 3
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	card.add_child(body)
	var icon := TextureRect.new()
	icon.texture = _icon("Animation")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(24, 24)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	body.add_child(copy)
	empty_state_title = _label("", 16)
	empty_state_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(empty_state_title)
	empty_state_detail = _label("", 12)
	empty_state_detail.modulate.a = 0.76
	copy.add_child(empty_state_detail)
	_refresh_empty_state()
	return card


func _refresh_empty_state() -> void:
	if not is_instance_valid(empty_state_title) or not is_instance_valid(empty_state_detail):
		return
	var has_target := is_instance_valid(selected_node)
	empty_state_title.text = "No Tween calls found" if has_target else "Select a scene node"
	empty_state_detail.text = "Add Tween inserts a native call at a chosen method and line. The timeline then shows its timing, source and editable parameters." if has_target else "Select a node in Godot's Scene tree to map its calls. Add Tween writes the code and shows it here for visual editing."


func _add_legend(parent: HBoxContainer, title: String, color: Color) -> void:
	var item := HBoxContainer.new()
	item.custom_minimum_size.x = 72
	item.add_theme_constant_override("separation", 5)
	parent.add_child(item)
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(9, 9)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(swatch)
	var label := _label(title, 12)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size.x = 44
	label.modulate.a = 0.78
	item.add_child(label)


func _apply_parameters() -> void:
	if _operation.is_empty():
		return
	var changes := {}
	for index in _fields:
		var field = _fields[index]
		if not field.dirty:
			continue
		var data: Dictionary = field.data()
		var name: String = _operation.names[index]
		if data.mode == "constant" and ("duration" in name or name == "interval") and (not (data.value is float or data.value is int) or float(data.value) < 0 or not is_finite(float(data.value))):
			_message("Duration/interval must be finite and non-negative.")
			return
		var result := WRITER.binding(data, _operation.method.owner, selected_node, _operation.property, _operation.method, _operation.language)
		if not result.ok:
			_message(result.error)
			return
		changes[index] = result.text
	if changes.is_empty():
		_message("No parameter changes. Runtime expressions remain untouched.")
		return
	var original := _document_source(_operation.path)
	var result := WRITER.patch_arguments(original, _operation, changes)
	_commit_result(_operation.path, original, result, "Edit Tween parameters")


func _open_move() -> void:
	if _operation.is_empty():
		return
	var operation := _operation.duplicate()
	var dialog := ConfirmationDialog.new()
	dialog.title = "Move Tween · " + str(operation.method.name)
	dialog.dialog_hide_on_ok = false
	dialog.get_ok_button().text = "Move Tween"
	var body := VBoxContainer.new()
	body.custom_minimum_size.x = 650
	body.add_theme_constant_override("separation", 12)
	dialog.add_child(body)
	_section(body, "MoveUp", "CHOOSE A GAP", "Move the call; keep the surrounding code")
	var picker := OptionButton.new()
	picker.fit_to_longest_item = false
	var anchors := _anchors(operation.method)
	for anchor in anchors:
		picker.add_item(anchor.label)
	body.add_child(picker)
	var placement = preload("res://addons/tween_animation/editor/placement_picker.gd").new()
	placement.build()
	body.add_child(placement)
	placement.configure(_document_source(operation.path), operation.method, anchors, 0)
	placement.placement_selected.connect(func(index: int): picker.select(index))
	picker.item_selected.connect(placement.select_anchor)
	dialog.confirmed.connect(func():
		var original := _document_source(operation.path)
		var result := WRITER.move_statement(original, operation, operation.method, anchors[picker.selected])
		if _commit_result(operation.path, original, result, "Move Tween call"):
			dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(740, 530), 0.9)


func _anchors(method: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"kind": "start", "label": "Start of method"}]
	for statement in method.statements:
		if statement.block:
			continue
		var text := str(statement.text).replace("\n", " ").left(64)
		result.append({"kind": "before", "start": statement.start, "label": "Before L%d · %s" % [statement.line, text]})
		result.append({"kind": "after", "start": statement.start, "label": "After L%d · %s" % [statement.line, text]})
	result.append({"kind": "end", "label": "End of method (before final return)"})
	return result


func _open_new_key() -> void:
	if not is_instance_valid(selected_node):
		_message("Select a scene node first. Add Tween uses the current Scene tree selection.")
		return
	var script: Script = selected_node.get_script()
	var eligible: Array[Dictionary] = []
	var seen_paths := {}
	for document in documents:
		if document.methods.any(func(method): return not method.static) and not seen_paths.has(document.path) and "::" not in document.path:
			eligible.append(document)
			seen_paths[document.path] = true
	if eligible.is_empty():
		if script == null:
			_create_script()
		elif script.resource_path.is_empty() or "::" in script.resource_path:
			_message("This node's script is built in and cannot be edited here. Attach an external GDScript or add a method in the Script editor, then rescan.")
		else:
			_add_ready_method(script)
		return
	_new_dialog = ConfirmationDialog.new()
	_new_dialog.title = "Add Tween · choose method and placement"
	_new_dialog.dialog_hide_on_ok = false
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	_new_dialog.add_child(body)
	var location := VBoxContainer.new()
	location.custom_minimum_size.x = 400
	location.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location.add_theme_constant_override("separation", 10)
	var location_scroll := ScrollContainer.new()
	location_scroll.custom_minimum_size = Vector2(430, 540)
	location_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(location_scroll)
	location_scroll.add_child(location)
	_section(location, "Script", "01 · PLACE IT", "Choose when your game runs this Tween")
	_new_method_picker = OptionButton.new()
	_new_method_picker.fit_to_longest_item = false
	for document in eligible:
		for method in document.methods:
			if not method.static:
				_new_method_picker.add_item(str(method.owner.name) + " / " + str(method.name) + "() · L" + str(method.line))
				_new_method_picker.set_item_metadata(_new_method_picker.item_count - 1, method)
	location.add_child(_new_method_picker)
	_new_place_picker = OptionButton.new()
	_new_place_picker.fit_to_longest_item = false
	location.add_child(_new_place_picker)
	_new_place_picker.hide()
	_new_placement = preload("res://addons/tween_animation/editor/placement_picker.gd").new()
	_new_placement.build()
	_new_placement.editor.custom_minimum_size.y = 220
	location.add_child(_new_placement)
	_new_placement.placement_selected.connect(func(index: int): _new_place_picker.select(index); _refresh_manager_choices(); _refresh_generated_preview())
	_new_place_picker.item_selected.connect(func(index: int): _new_placement.select_anchor(index); _refresh_generated_preview())
	var location_hint := _label("Click a statement to insert above it. Existing code moves down; the highlighted code is a live preview.", 13)
	location.add_child(location_hint)
	var divider := VSeparator.new()
	body.add_child(divider)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 540)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var settings := VBoxContainer.new()
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_theme_constant_override("separation", 10)
	scroll.add_child(settings)
	var target_icon := "Control" if selected_node is Control else "Node3D" if selected_node is Node3D else "Node2D"
	_section(settings, target_icon, "02 · SHAPE IT", "Animate " + str(selected_node.name))
	_new_property_picker = OptionButton.new()
	_new_property_picker.fit_to_longest_item = false
	_new_property_picker.get_popup().max_size = Vector2i(460, 380)
	for property in OPTIONS.properties(selected_node):
		_new_property_picker.add_item(property)
	settings.add_child(_new_property_picker)
	var position_index := 0
	for index in _new_property_picker.item_count:
		if _new_property_picker.get_item_text(index) == ("modulate:a" if selected_node is Control else "position"):
			position_index = index
	_new_property_picker.select(position_index)
	_new_backend = OptionButton.new()
	_new_backend.add_item("Godot Tween")
	_new_backend.add_item("Tweenimator  -  named Tween")
	settings.add_child(_new_backend)
	_new_manager = OptionButton.new()
	_new_manager.fit_to_longest_item = false
	_new_manager.get_popup().max_size = Vector2i(460, 300)
	settings.add_child(_new_manager)
	_new_name = LineEdit.new()
	_new_name.placeholder_text = "Tween name  -  e.g. menu_intro"
	_new_name.text = "intro"
	settings.add_child(_new_name)
	_new_backend.item_selected.connect(func(_index: int): _refresh_generated_preview())
	_new_manager.item_selected.connect(func(_index: int): _refresh_generated_preview())
	_new_name.text_changed.connect(func(_text: String): _refresh_generated_preview())
	_new_sequence_picker = OptionButton.new()
	_new_sequence_picker.add_item("Join earlier top-level Tween if available")
	_new_sequence_picker.add_item("Create an independent Tween")
	_new_sequence_picker.fit_to_longest_item = false
	_new_sequence_picker.get_popup().max_size = Vector2i(460, 220)
	settings.add_child(_new_sequence_picker)
	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 14)
	settings.add_child(fields)
	_new_feedback = _label("", 12)
	_new_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_new_feedback.add_theme_color_override("font_color", Color("ff8d8d"))
	settings.add_child(_new_feedback)
	_new_method_picker.item_selected.connect(func(_index: int): _new_key_fields(fields))
	_new_property_picker.item_selected.connect(func(_index: int): _new_key_fields(fields))
	_new_sequence_picker.item_selected.connect(func(_index: int): _refresh_generated_preview())
	_new_key_fields(fields)
	_new_dialog.get_ok_button().text = "Add Tween"
	_new_dialog.confirmed.connect(_create_key)
	_new_dialog.canceled.connect(_new_dialog.queue_free)
	add_child(_new_dialog)
	_new_dialog.popup_centered_clamped(Vector2i(960, 660), 0.9)


func _new_key_fields(container: VBoxContainer) -> void:
	_clear(container)
	_new_fields.clear()
	var chosen: Dictionary = _new_method_picker.get_item_metadata(_new_method_picker.selected)
	var old_selection := _new_place_picker.selected if chosen.get("id") == _new_method.get("id") and chosen.get("path") == _new_method.get("path") else -1
	_new_method = chosen
	_new_anchors = _anchors(_new_method)
	_new_place_picker.clear()
	for anchor in _new_anchors:
		_new_place_picker.add_item(anchor.label)
	_new_place_picker.select(old_selection if old_selection >= 0 else mini(1, _new_place_picker.item_count - 1))
	_new_placement.configure(_document_source(_new_method.path), _new_method, _new_anchors, _new_place_picker.selected)
	var property := _new_property_picker.get_item_text(_new_property_picker.selected)
	var sample: Variant = selected_node.get_indexed(NodePath(property))
	for name in ["value", "duration", "interval"]:
		var field = FIELD.new()
		if name == "value" and property == "position":
			sample = Vector3(1, 0, 0) if sample is Vector3 else Vector2(100, 0)
		field.build({"value": "Destination / offset", "duration": "Animation duration · seconds", "interval": "Wait after animation · seconds"}[name], "", sample if name == "value" else (0.4 if name == "duration" else 0.0), _new_method.parameters, OPTIONS.properties(selected_node), name == "value")
		container.add_child(field)
		_new_fields[name] = field
		field.changed.connect(_refresh_generated_preview)
		if name == "value" and property == "position":
			field.choose("relative")
	_refresh_manager_choices()
	_refresh_generated_preview()


func _refresh_generated_preview() -> void:
	if not is_instance_valid(_new_backend) or _new_fields.size() != 3 or _new_anchors.is_empty() or not is_instance_valid(selected_node):
		return
	var helper := _new_backend.selected == 1
	_new_manager.visible = helper
	_new_name.visible = helper
	_new_sequence_picker.visible = not helper
	var source := _document_source(_new_method.path)
	var anchor: Dictionary = _new_anchors[_new_place_picker.selected]
	var property := _new_property_picker.get_item_text(_new_property_picker.selected)
	var result := WRITER.insert_property(source, _new_method, anchor, selected_node, property, _new_fields.value.data(), _new_fields.duration.data(), _new_fields.interval.data(), "own" if _new_backend.selected == 1 else ("auto" if _new_sequence_picker.selected == 0 else "own"), _new_manager_config())
	if not result.ok:
		_new_feedback.text = "Preview unavailable · " + str(result.get("error", "Check the selected values."))
		return
	var location := WRITER.location(source, _new_method, anchor)
	if not location.ok:
		_new_feedback.text = "Preview unavailable · " + str(location.get("error", "Choose another insertion point."))
		return
	var prefix_length: int = result.offset
	var suffix_length: int = source.substr(prefix_length).length()
	var inserted_length: int = result.source.length() - prefix_length - suffix_length
	_new_feedback.text = ""
	_new_placement.show_generated(str(result.source), prefix_length, inserted_length)


func _new_manager_config() -> Dictionary:
	if _new_backend.selected == 0:
		return {}
	return {"instance": str(_new_manager.get_item_metadata(_new_manager.selected)), "name": _new_name.text}


func _refresh_manager_choices() -> void:
	var previous := str(_new_manager.get_item_metadata(_new_manager.selected)) if _new_manager.selected >= 0 else ""
	_new_manager.clear()
	_new_manager.add_item("Create a new Tweenimator here")
	_new_manager.set_item_metadata(0, "")
	var source := _document_source(_new_method.path)
	var place := WRITER.location(source, _new_method, _new_anchors[_new_place_picker.selected])
	if not place.ok:
		return
	var candidates := source
	# Only class fields and preceding statements in this method are in scope.
	var methods := SYNTAX.methods(source, MODEL.language(_new_method.path))
	for index in range(methods.size() - 1, -1, -1):
		var entry: Dictionary = methods[index]
		candidates = candidates.left(entry.start) + " ".repeat(entry.end - entry.start) + candidates.substr(entry.end)
	for statement in _new_method.statements:
		if not statement.conditional and not statement.block and statement.end <= place.offset:
			candidates += "\n" + str(statement.text)
	var bindings: Dictionary = MODEL._bindings(candidates)
	for variable in bindings:
		if "Tweenimator" in str(bindings[variable]) or "tweenimator.gd" in str(bindings[variable]):
			_new_manager.add_item(str(variable))
			_new_manager.set_item_metadata(_new_manager.item_count - 1, str(variable))
			if str(variable) == previous:
				_new_manager.select(_new_manager.item_count - 1)


func _create_key() -> void:
	var original := _document_source(_new_method.path)
	var property := _new_property_picker.get_item_text(_new_property_picker.selected)
	for name in ["duration", "interval"]:
		var data: Dictionary = _new_fields[name].data()
		if data.mode == "constant" and (not (data.value is float or data.value is int) or float(data.value) < 0 or not is_finite(float(data.value))):
			_new_feedback.text = "Duration and wait must be finite, non-negative numbers."
			return
	var result := WRITER.insert_property(original, _new_method, _new_anchors[_new_place_picker.selected], selected_node, property, _new_fields.value.data(), _new_fields.duration.data(), _new_fields.interval.data(), "own" if _new_backend.selected == 1 else ("auto" if _new_sequence_picker.selected == 0 else "own"), _new_manager_config())
	if _commit_result(_new_method.path, original, result, "Add Tween call"):
		_new_dialog.queue_free()
	elif _new_feedback.text.is_empty():
		_new_feedback.text = "Could not add this Tween. No source change was applied. Check the timeline status and Godot Output for details."


func _add_ready_method(script: Script) -> void:
	var path := script.resource_path
	if path.is_empty() or "::" in path:
		_message("This script is embedded in the scene and has no editable file path. Attach an external script or create one through Add Tween.")
		return
	var original := _document_source(path)
	var suffix := "\n\nfunc _ready() -> void:\n\tpass\n" if MODEL.language(path) == "gd" else ""
	if suffix.is_empty():
		_message("No editable instance method found. For C#, add a method in the Script editor and rescan; Add Tween can then place a call inside it.")
		return
	if _commit_result(path, original, {"ok": true, "source": original + suffix}, "Create animation entry point"):
		_open_new_key()


func _create_script() -> void:
	if mode == 1:
		_message("Create/attach the C# Node script in Godot .NET first. Visual mode can create a GDScript entry point without code entry.")
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.current_file = str(selected_node.name).to_snake_case() + "_tweens.gd"
	dialog.add_filter("*.gd", "GDScript node script")
	dialog.title = "Create animation script · no code entry required"
	dialog.file_selected.connect(func(path: String):
		if FileAccess.file_exists(path):
			_message("Choose a new filename. Existing scripts are never overwritten by script creation.")
			dialog.queue_free()
			return
		var script := GDScript.new()
		script.source_code = "extends " + selected_node.get_class() + "\n\nfunc _ready() -> void:\n\tpass\n"
		if script.reload() != OK or ResourceSaver.save(script, path) != OK:
			_message("Could not create the scene animation script.")
			dialog.queue_free()
			return
		var history := plugin.get_undo_redo()
		history.create_action("Attach animation script", UndoRedo.MERGE_DISABLE, selected_node)
		history.add_do_method(selected_node, "set_script", script)
		history.add_undo_method(selected_node, "set_script", null)
		history.commit_action()
		plugin.get_editor_interface().mark_scene_as_unsaved()
		rescan()
		dialog.queue_free()
		_open_new_key()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(700, 450))


func _document_source(path: String) -> String:
	for document in documents:
		if document.path == path:
			return document.source
	return FileAccess.get_file_as_string(path)


func _commit_result(path: String, original: String, result: Dictionary, title: String) -> bool:
	if not result.ok:
		_message(str(result.get("error", "Source edit failed.")))
		return false
	if _source_dirty and _source_path == path:
		_message("Save or discard the source draft before applying visual edits. Your draft has been preserved.")
		return false
	if FileAccess.get_file_as_string(path).sha256_text() != original.sha256_text():
		_message("The script changed outside this view. Rescan before applying.")
		return false
	for document in documents:
		if document.path == path and document.script.get_source_code() != original:
			_message("Godot has a different script buffer. Save it there and rescan before applying visual edits.")
			return false
	if path in plugin.get_editor_interface().get_script_editor().get_unsaved_files():
		_message("This script has an unsaved Godot editor buffer. Save it and rescan before applying visual edits.")
		return false
	var checked := WRITER.validate(result.source, MODEL.language(path))
	if not checked.ok:
		_message(checked.error)
		return false
	# Apply the first write synchronously. UndoRedo's do-method is for redo;
	# depending on the editor context it may run after this dialog checks success.
	_busy = true
	var saved := WRITER.write(path, original.sha256_text(), result.source)
	_busy = false
	if not saved.ok:
		_message(saved.error)
		return false
	var history := plugin.get_undo_redo()
	history.create_action(title, UndoRedo.MERGE_DISABLE, selected_node)
	history.add_do_method(self, "_write_revision", path, original.sha256_text(), result.source)
	history.add_undo_method(self, "_write_revision", path, str(result.source).sha256_text(), original)
	history.commit_action(false)
	_refresh_source(path, result.source, saved.get("note", ""))
	return true


func _write_revision(path: String, expected: String, source: String) -> void:
	_last_write_ok = false
	if _source_dirty and _source_path == path:
		_message("Save or discard your source draft before Undo/Redo can replace this script.")
		return
	if path in plugin.get_editor_interface().get_script_editor().get_unsaved_files():
		_message("An unsaved Godot script buffer was preserved. Save it before applying this history action.")
		return
	_busy = true
	var result := WRITER.write(path, expected, source)
	_busy = false
	_last_write_ok = result.ok
	if not result.ok:
		_message(result.error)
		return
	_refresh_source(path, source, result.get("note", ""))


func _refresh_source(path: String, source: String, note: String) -> void:
	_source_dirty = false
	var script: Script = load(path)
	if script != null:
		script.set_source_code(source)
		script.reload(true)
	plugin.get_editor_interface().get_script_editor().reload_open_files()
	plugin.get_editor_interface().get_resource_filesystem().update_file(path)
	rescan()
	_message("Source updated. Timeline entries were refreshed from the code. " + str(note))


func _show_source(path: String, line: int) -> void:
	if _source_dirty and path != _source_path:
		_message("Save or discard this source draft before opening another source file.")
		return
	if not (_source_dirty and path == _source_path):
		source_editor.text = _document_source(path)
		_source_dirty = false
	_source_path = path
	source_panel.visible = mode != 2
	source_editor.set_caret_line(maxi(0, line - 1))
	source_editor.center_viewport_to_caret()
	if mode != 2 and ((mode == 0 and MODEL.language(path) == "cs") or (mode == 1 and MODEL.language(path) == "gd")):
		_message("This source is " + ("C#" if MODEL.language(path) == "cs" else "GDScript") + ". The content preference does not translate project scripts.")


func _style_source() -> void:
	var foreground := EditorInterface.get_base_control().get_theme_color("font_color", "Label")
	source_editor.add_theme_color_override("font_color", foreground)
	var syntax := CodeHighlighter.new()
	syntax.symbol_color = foreground
	syntax.member_variable_color = foreground
	syntax.number_color = Color("a6d395")
	syntax.function_color = Color("88c7ee")
	syntax.add_color_region('"', '"', Color("e8c88d"))
	syntax.add_color_region("#", "", Color("9aa8b8"), true)
	syntax.add_color_region("//", "", Color("9aa8b8"), true)
	for keyword in ["var", "func", "extends", "await", "if", "else", "return", "new", "public", "private", "void", "class", "using", "partial"]:
		syntax.add_keyword_color(keyword, Color("c6a6e6"))
	source_editor.syntax_highlighter = syntax


func _jump_source() -> void:
	if _operation.is_empty():
		return
	plugin.call("_set_content_mode", 1 if _operation.language == "cs" else 0)
	_show_source(_operation.path, _operation.line)
	source_editor.grab_focus()


func _open_in_editor() -> void:
	if _source_path.is_empty():
		return
	var script: Script = load(_source_path)
	if script == null:
		_message("Source navigation for C# requires Godot .NET.")
		return
	plugin.get_editor_interface().edit_script(script, int(_operation.get("line", 1)) - 1, 0, true)
	plugin.get_editor_interface().set_main_screen_editor("Script")


func _save_source_draft() -> void:
	if _source_path.is_empty() or not _source_dirty:
		return
	var original := _document_source(_source_path)
	var draft := source_editor.text
	_source_dirty = false
	if not _commit_result(_source_path, original, {"ok": true, "source": draft}, "Edit Tween source"):
		_source_dirty = true


func _discard_source_draft() -> void:
	_source_dirty = false
	if not _source_path.is_empty():
		source_editor.text = FileAccess.get_file_as_string(_source_path)
		_source_dirty = false
	rescan()


func _message(message: String) -> void:
	status.text = message
	# Keep creation failures in the dialog; rescan() can replace the status line
	# with its normal informational text before the user sees the failure.
	if is_instance_valid(_new_feedback) and is_instance_valid(_new_dialog):
		_new_feedback.text = message


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	return label


func _button(parent: Node, text: String, icon: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = _icon(icon)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _icon(name: String) -> Texture2D:
	var editor := EditorInterface.get_base_control()
	return editor.get_theme_icon(name if editor.has_theme_icon(name, "EditorIcons") else "Node", "EditorIcons")


func _section(parent: Node, icon_name: String, eyebrow: String, title: String) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = EditorInterface.get_base_control().get_theme_color("dark_color_1", "Editor")
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = _icon(icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(28, 28)
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size.x = 220
	row.add_child(text)
	var badge := _label(eyebrow, 12)
	badge.modulate = EditorInterface.get_base_control().get_theme_color("accent_color", "Editor")
	text.add_child(badge)
	var title_label := _label(title, 16)
	title_label.custom_minimum_size.x = 220
	text.add_child(title_label)
	parent.add_child(panel)
