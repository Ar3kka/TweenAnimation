@tool
extends VBoxContainer
## Data-only parameter/binding editor. Visual mode never needs an expression textbox.

signal changed

const MODEL = preload("res://addons/tween_animation/editor/tween_source.gd")
const WRITER = preload("res://addons/tween_animation/editor/tween_source_writer.gd")
var picker: OptionButton
var fields: GridContainer
var runtime_label: Label
var parameter_picker: OptionButton
var property_picker: OptionButton
var type_picker: OptionButton
var dirty := false
var _expression := ""
var _components := PackedFloat64Array()
var _value: Variant
var _modes: Array[String] = []
var _types := [TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR, TYPE_BOOL, TYPE_STRING, TYPE_INT]


func build(title: String, expression: String, sample: Variant, parameters: Array, properties: PackedStringArray, allow_relative: bool = false) -> void:
	_expression = expression
	_value = sample if sample != null else 0.0
	var parsed := MODEL.literal(expression, sample)
	if parsed.ok:
		_value = parsed.value
	add_theme_constant_override("separation", 5)
	var heading := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	type_picker = OptionButton.new()
	for type in _types:
		type_picker.add_item(type_string(type))
	type_picker.select(maxi(_types.find(typeof(_value)), 0))
	type_picker.visible = sample == null
	type_picker.item_selected.connect(func(index: int):
		_value = {TYPE_FLOAT: 0.0, TYPE_INT: 0, TYPE_VECTOR2: Vector2.ZERO, TYPE_VECTOR3: Vector3.ZERO, TYPE_COLOR: Color.WHITE, TYPE_BOOL: false, TYPE_STRING: ""}[_types[index]]
		_rebuild_fields()
		_mark_dirty()
	)
	heading.add_child(type_picker)
	add_child(heading)
	picker = OptionButton.new()
	picker.fit_to_longest_item = false
	picker.custom_minimum_size.x = 220
	if not expression.is_empty():
		_add_mode("Original value" if parsed.ok else "Runtime expression · keep", "keep")
	_add_mode("Value", "constant")
	if allow_relative and typeof(_value) in [TYPE_FLOAT, TYPE_INT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR]:
		_add_mode("Offset from current · evaluated when called", "relative")
	if not parameters.is_empty():
		_add_mode("Method parameter", "parameter")
	if allow_relative and not properties.is_empty():
		_add_mode("Selected node property · evaluated when called", "property")
	picker.item_selected.connect(func(_index: int): _sync_mode(); _mark_dirty())
	add_child(picker)
	runtime_label = Label.new()
	runtime_label.text = expression
	runtime_label.clip_text = true
	runtime_label.tooltip_text = expression
	runtime_label.custom_minimum_size.x = 220
	runtime_label.add_theme_font_override("font", EditorInterface.get_base_control().get_theme_font("source", "EditorFonts"))
	add_child(runtime_label)
	parameter_picker = OptionButton.new()
	for parameter in parameters:
		parameter_picker.add_item(str(parameter.name) + " : " + str(parameter.type))
		parameter_picker.set_item_metadata(parameter_picker.item_count - 1, parameter.name)
	parameter_picker.item_selected.connect(func(_index: int): _mark_dirty())
	add_child(parameter_picker)
	property_picker = OptionButton.new()
	property_picker.fit_to_longest_item = false
	for property in properties:
		property_picker.add_item(property)
	property_picker.item_selected.connect(func(_index: int): _mark_dirty())
	add_child(property_picker)
	fields = GridContainer.new()
	fields.columns = 3
	fields.add_theme_constant_override("h_separation", 4)
	fields.add_theme_constant_override("v_separation", 4)
	add_child(fields)
	_rebuild_fields()
	_sync_mode()


func _add_mode(label: String, mode: String) -> void:
	picker.add_item(label)
	_modes.append(mode)


func _sync_mode() -> void:
	var mode := _modes[picker.selected]
	runtime_label.visible = mode == "keep"
	fields.visible = mode in ["constant", "relative"]
	parameter_picker.visible = mode == "parameter"
	property_picker.visible = mode == "property"
	type_picker.disabled = mode == "keep"


func _mark_dirty() -> void:
	dirty = true
	changed.emit()


func _rebuild_fields() -> void:
	for child in fields.get_children():
		fields.remove_child(child)
		child.queue_free()
	var constructors: Dictionary = preload("res://addons/tween_animation/editor/key_values.gd").CONSTRUCTORS
	if _value is float or _value is int or constructors.has(typeof(_value)):
		var count: int = constructors[typeof(_value)][1] if constructors.has(typeof(_value)) else 1
		fields.columns = mini(4, count)
		_components.clear()
		if count > 1:
			var serialized := var_to_str(_value)
			for number in serialized.substr(serialized.find("(") + 1).trim_suffix(")").split(","):
				_components.append(float(number))
		else:
			_components.append(float(_value))
		for index in count:
			var input := SpinBox.new()
			input.step = 1.0 if typeof(_value) in [TYPE_INT, TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I, TYPE_RECT2I] else 0.001
			input.allow_greater = true
			input.allow_lesser = true
			input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			input.custom_minimum_size.x = 55
			input.prefix = ("RGBA"[index] if _value is Color else "XYZW"[index]) if count in [2, 3, 4] else ""
			input.set_value_no_signal(_components[index])
			input.value_changed.connect(func(value: float):
				_components[index] = value
				if count > 1:
					var parts := PackedStringArray()
					for component in _components:
						parts.append(str(component))
					var parsed := MODEL.literal(str(constructors[typeof(_value)][0]) + "(" + ", ".join(parts) + ")", _value)
					if parsed.ok:
						_value = parsed.value
				else:
					_value = int(value) if _value is int else value
				_mark_dirty()
			)
			fields.add_child(input)
	elif _value is bool:
		var input := CheckButton.new()
		input.text = "Enabled"
		input.set_pressed_no_signal(_value)
		input.toggled.connect(func(value: bool): _value = value; _mark_dirty())
		fields.add_child(input)
	elif _value is String or _value is StringName:
		var input := LineEdit.new()
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input.text = str(_value)
		input.text_changed.connect(func(value: String): _value = value; _mark_dirty())
		fields.add_child(input)
	else:
		var note := Label.new()
		note.text = "Complex value preserved. Use a matching method parameter or node property."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fields.add_child(note)


func data() -> Dictionary:
	var mode := _modes[picker.selected]
	return {"mode": mode, "text": _expression, "value": _value, "name": parameter_picker.get_item_metadata(parameter_picker.selected) if parameter_picker.selected >= 0 else "", "property": property_picker.get_item_text(property_picker.selected) if property_picker.selected >= 0 else ""}


func choose(mode: String) -> void:
	var index := _modes.find(mode)
	if index >= 0:
		picker.select(index)
		_sync_mode()
		_mark_dirty()
