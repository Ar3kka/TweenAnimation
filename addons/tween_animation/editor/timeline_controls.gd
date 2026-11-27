@tool
extends VBoxContainer
## Shared real controls for the editor and isolated tutorial practice previews.

signal add_track_requested
signal capture_key_requested
signal track_selected(index: int)
signal time_changed(value: float)
signal key_selected(index: int)
signal draw_requested
signal action_requested(action: String)
signal override_changed

const DEFAULT_LENGTH := 1.0
var track_picker: OptionButton
var property_path: LineEdit
var value_input: LineEdit
var time_label: Label
var time_slider: HSlider
var timeline: Control
var key_list: ItemList
var add_track_button: Button
var capture_key_button: Button
var property_browser: Button
var action_menu: MenuButton
var target_label: Label
var property_row: HBoxContainer
var value_row: HBoxContainer
var timeline_row: HBoxContainer
var key_heading: Label
var separator: HSeparator
var property_dialog: AcceptDialog
var property_search: LineEdit
var property_list: ItemList
var available_properties := PackedStringArray()
var available_actions := PackedStringArray()
var key_value_card: PanelContainer
var accepted_values_label: Label
var capture_hint: Label
var example_row: HFlowContainer
var use_current_button: Button
var mode_switch: HBoxContainer
var override_mode_button: Button
var examples_button: Button
var format_popup: PopupPanel
var value_readout: HBoxContainer
var saved_state: Label
var saved_icon: TextureRect
var _readout_type := -1
var component_inputs: Array[SpinBox] = []
var boolean_input: CheckButton
var text_input: LineEdit
var new_track_button: Button
var property_error: Label
var _override_value: Variant = null
var _scrubbing := false
var _editing_enabled := true
var _override_requested := false
var _show_values := true
var _current_value: Variant = null
var _property_name := ""
var _example_signature := ""


func build() -> void:
	add_theme_constant_override("separation", 8)
	var workspace: VBoxContainer = self
	target_label = _text("", 0)
	workspace.add_child(target_label)
	target_label.hide()
	track_picker = OptionButton.new()
	track_picker.custom_minimum_size.x = 180
	track_picker.fit_to_longest_item = false
	track_picker.item_selected.connect(track_selected.emit)
	track_picker.tooltip_text = "Active track: its node and property."
	new_track_button = Button.new()
	new_track_button.text = "Track"
	new_track_button.icon = EditorInterface.get_base_control().get_theme_icon("Add", "EditorIcons")
	new_track_button.pressed.connect(_open_properties)
	property_browser = new_track_button
	action_menu = MenuButton.new()
	action_menu.text = "Actions"
	action_menu.icon = EditorInterface.get_base_control().get_theme_icon("Animation", "EditorIcons")
	action_menu.get_popup().id_pressed.connect(func(index: int): action_requested.emit(available_actions[index]))
	_build_key_editor(workspace)
	separator = HSeparator.new()
	workspace.add_child(separator)

	timeline_row = HBoxContainer.new()
	workspace.add_child(timeline_row)
	time_label = _text("0.00s", 0)
	time_label.custom_minimum_size.x = 70
	timeline_row.add_child(time_label)
	time_slider = HSlider.new()
	time_slider.min_value = 0.0
	time_slider.max_value = DEFAULT_LENGTH
	time_slider.step = 0.0
	time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_slider.value_changed.connect(time_changed.emit)
	timeline_row.add_child(time_slider)

	timeline = Control.new()
	timeline.custom_minimum_size = Vector2(0, 200)
	timeline.tooltip_text = "Drag anywhere on the timeline to move the playhead continuously. Key markers show recorded values."
	timeline.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	timeline.focus_mode = Control.FOCUS_ALL
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.draw.connect(draw_requested.emit)
	timeline.gui_input.connect(_scrub_timeline)
	workspace.add_child(timeline)

	key_heading = _text("KEYFRAMES  ·  Select a key to jump to its time", 12)
	workspace.add_child(key_heading)
	key_list = ItemList.new()
	key_list.custom_minimum_size.y = 90
	key_list.item_selected.connect(key_selected.emit)
	workspace.add_child(key_list)
	_build_property_browser()
	set_target(null)
	set_value_context("", null)
	timeline_row.hide()


func _build_key_editor(workspace: VBoxContainer) -> void:
	key_value_card = PanelContainer.new()
	var editor := EditorInterface.get_base_control()
	var style := StyleBoxFlat.new()
	style.bg_color = editor.get_theme_color("dark_color_2", "Editor")
	style.set_content_margin_all(10)
	style.set_corner_radius_all(6)
	key_value_card.add_theme_stylebox_override("panel", style)
	workspace.add_child(key_value_card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	key_value_card.add_child(body)
	value_row = HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 8)
	body.add_child(value_row)
	var header := HFlowContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("h_separation", 8)
	header.add_theme_constant_override("v_separation", 6)
	value_row.add_child(header)
	header.add_child(track_picker)
	header.add_child(new_track_button)
	header.add_child(action_menu)
	mode_switch = HBoxContainer.new()
	mode_switch.add_theme_constant_override("separation", 0)
	header.add_child(mode_switch)
	var modes := ButtonGroup.new()
	use_current_button = Button.new()
	use_current_button.text = "Current"
	use_current_button.toggle_mode = true
	use_current_button.button_group = modes
	use_current_button.tooltip_text = "Read the tracked node’s live property value. Discards the override."
	use_current_button.pressed.connect(func():
		_override_requested = false
		_override_value = null
		value_input.clear()
		_update_readout(_current_value)
		_validate_value()
		override_changed.emit()
	)
	mode_switch.add_child(use_current_button)
	override_mode_button = Button.new()
	override_mode_button.text = "Override"
	override_mode_button.toggle_mode = true
	override_mode_button.button_group = modes
	override_mode_button.tooltip_text = "Edit these same value fields for the key without changing the scene node."
	override_mode_button.pressed.connect(func():
		_override_requested = true
		_override_value = _current_value
		value_input.text = var_to_str(_override_value)
		_update_readout(_override_value)
		_validate_value()
		override_changed.emit()
	)
	mode_switch.add_child(override_mode_button)
	for button in [use_current_button, override_mode_button]:
		var pressed := StyleBoxFlat.new()
		pressed.bg_color = editor.get_theme_color("accent_color", "Editor") * Color(1, 1, 1, 0.2)
		pressed.border_color = editor.get_theme_color("accent_color", "Editor")
		pressed.border_width_bottom = 2
		pressed.content_margin_left = 10
		pressed.content_margin_right = 10
		pressed.content_margin_top = 6
		pressed.content_margin_bottom = 6
		button.add_theme_stylebox_override("pressed", pressed)
	value_readout = HBoxContainer.new()
	value_readout.add_theme_constant_override("separation", 6)
	header.add_child(value_readout)
	value_input = LineEdit.new()
	value_input.custom_minimum_size.x = 200
	value_input.text_changed.connect(func(_text: String): _validate_value(); override_changed.emit())
	header.add_child(value_input)
	examples_button = Button.new()
	examples_button.flat = true
	examples_button.icon = editor.get_theme_icon("Help", "EditorIcons")
	examples_button.tooltip_text = "Value help and presets"
	examples_button.pressed.connect(_open_value_help)
	var saved := HBoxContainer.new()
	saved.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(saved)
	saved_icon = TextureRect.new()
	saved_icon.texture = editor.get_theme_icon("Key", "EditorIcons")
	saved_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	saved_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	saved_icon.custom_minimum_size = Vector2(16, 20)
	saved.add_child(saved_icon)
	saved_state = _text("", 13)
	saved.add_child(saved_state)
	header.add_child(examples_button)
	capture_key_button = _button(header, "Capture", capture_key_requested.emit)
	var capture_style := StyleBoxFlat.new()
	capture_style.bg_color = editor.get_theme_color("accent_color", "Editor") * Color(1, 1, 1, 0.18)
	capture_style.border_color = editor.get_theme_color("accent_color", "Editor")
	capture_style.set_border_width_all(1)
	capture_style.set_corner_radius_all(4)
	capture_style.set_content_margin_all(8)
	capture_key_button.add_theme_stylebox_override("normal", capture_style)
	capture_hint = _text("", 13)
	capture_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(capture_hint)
	format_popup = PopupPanel.new()
	add_child(format_popup)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	format_popup.add_child(margin)
	var help := VBoxContainer.new()
	help.custom_minimum_size.x = 400
	help.add_theme_constant_override("separation", 10)
	margin.add_child(help)
	help.add_child(_text("VALUE FORMAT", 12))
	accepted_values_label = _text("", 14)
	accepted_values_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	accepted_values_label.custom_minimum_size.x = 400
	accepted_values_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.add_child(accepted_values_label)
	example_row = HFlowContainer.new()
	example_row.add_theme_constant_override("h_separation", 6)
	help.add_child(example_row)


func _open_value_help() -> void:
	var position := examples_button.get_global_rect().end
	position.x = clampf(position.x - 420, 0, maxf(0, get_viewport_rect().size.x - 440))
	position.y = minf(position.y + 4, maxf(0, get_viewport_rect().size.y - 180))
	format_popup.popup(Rect2i(Vector2i(position), Vector2i(430, 160)))


func set_value_context(property: String, current: Variant, info: Dictionary = {}, saved: Variant = null, has_key: bool = false, at_time: float = 0.0, source: String = "Node value") -> void:
	if _property_name != property or typeof(_current_value) != typeof(current):
		_override_requested = false
		_override_value = null
		value_input.clear()
	_current_value = current
	_property_name = property
	value_readout.tooltip_text = source + ": " + var_to_str(current)
	use_current_button.tooltip_text = source + ": " + var_to_str(current) + "\nCapture this live value; clears the override."
	saved_state.text = "%.3f s · %s" % [at_time, "Key" if has_key else "Empty"]
	saved_state.tooltip_text = "Saved key: " + var_to_str(saved) if has_key else "No key at this exact time. Capture key to record a value here."
	saved_icon.tooltip_text = saved_state.tooltip_text
	saved_icon.modulate.a = 1.0 if has_key else 0.35
	var details := preload("res://addons/tween_animation/editor/key_values.gd").describe(current, property, info)
	accepted_values_label.text = "Accepts " + str(details.accepted) if current != null else "Choose a property track whose target exists in the current scene."
	value_input.tooltip_text = accepted_values_label.text
	_update_readout(_override_value if _override_requested else current)
	var signature := str(details)
	if signature != _example_signature:
		_example_signature = signature
		for child in example_row.get_children():
			example_row.remove_child(child)
			child.queue_free()
		for example in details.examples:
			var button := Button.new()
			var parsed: Dictionary = preload("res://addons/tween_animation/editor/key_values.gd").parse(example, current)
			button.text = _value_caption(parsed.value) if parsed.ok else example
			button.tooltip_text = "Use this as the key override."
			button.pressed.connect(func():
				_override_requested = true
				_override_value = parsed.value
				value_input.text = var_to_str(_override_value)
				_update_readout(_override_value)
				_validate_value()
				format_popup.hide()
				override_changed.emit()
			)
			example_row.add_child(button)
	_validate_value()


func _value_caption(value: Variant) -> String:
	var axes := _axes(typeof(value))
	if axes.is_empty():
		return str(value)
	var parts := PackedStringArray()
	for index in axes.size():
		parts.append("%s %s" % [axes[index], value[index]])
	return " · ".join(parts)


func _axes(type: int) -> PackedStringArray:
	match type:
		TYPE_VECTOR2, TYPE_VECTOR2I: return ["X", "Y"]
		TYPE_VECTOR3, TYPE_VECTOR3I: return ["X", "Y", "Z"]
		TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_QUATERNION: return ["X", "Y", "Z", "W"]
		TYPE_COLOR: return ["R", "G", "B", "A"]
	return []


func _update_readout(value: Variant) -> void:
	var type := typeof(value)
	if type != _readout_type:
		_readout_type = type
		component_inputs.clear()
		boolean_input = null
		text_input = null
		for child in value_readout.get_children():
			value_readout.remove_child(child)
			child.queue_free()
		var axes := _axes(type)
		var colors := [Color("ef7979"), Color("8dca85"), Color("7aa8ef"), Color("b9a3de")]
		if not axes.is_empty() or type in [TYPE_INT, TYPE_FLOAT]:
			for index in maxi(axes.size(), 1):
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 3)
				value_readout.add_child(row)
				if not axes.is_empty():
					var axis := _text(axes[index], 13)
					axis.modulate = colors[index]
					axis.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					row.add_child(axis)
				var input := SpinBox.new()
				input.custom_minimum_size.x = 78
				input.allow_greater = true
				input.allow_lesser = true
				input.step = 1.0 if type in [TYPE_INT, TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I] else 0.001
				input.value_changed.connect(_component_changed.bind(index))
				row.add_child(input)
				component_inputs.append(input)
		elif type == TYPE_BOOL:
			boolean_input = CheckButton.new()
			boolean_input.text = "Enabled"
			boolean_input.toggled.connect(func(enabled: bool): _set_override(enabled))
			value_readout.add_child(boolean_input)
		elif type in [TYPE_STRING, TYPE_STRING_NAME]:
			text_input = LineEdit.new()
			text_input.custom_minimum_size.x = 150
			text_input.text_changed.connect(func(text: String): _set_override(StringName(text) if type == TYPE_STRING_NAME else text))
			value_readout.add_child(text_input)
		else:
			value_readout.add_child(_text("Select a track" if value == null else _value_caption(value).left(48), 13))
	for index in component_inputs.size():
		component_inputs[index].set_value_no_signal(value[index] if not _axes(type).is_empty() else value)
	if is_instance_valid(boolean_input):
		boolean_input.set_pressed_no_signal(value)
	if is_instance_valid(text_input):
		text_input.text = str(value)


func _component_changed(number: float, index: int) -> void:
	if not _override_requested or not _editing_enabled:
		return
	var value: Variant = _override_value
	if _axes(typeof(value)).is_empty():
		value = int(number) if typeof(_current_value) == TYPE_INT else number
	else:
		value[index] = int(number) if typeof(value) in [TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I] else number
	_set_override(value)


func _set_override(value: Variant) -> void:
	if not _override_requested or not _editing_enabled:
		return
	_override_value = value
	value_input.text = var_to_str(value)
	_validate_value()
	override_changed.emit()


func capture_value() -> Dictionary:
	return preload("res://addons/tween_animation/editor/key_values.gd").parse(value_input.text, _current_value)


func _validate_value() -> void:
	if not is_instance_valid(capture_hint):
		return
	var result := capture_value()
	var override := not value_input.text.strip_edges().is_empty()
	var editing_override := override or _override_requested
	capture_key_button.disabled = not result.ok
	capture_key_button.visible = _editing_enabled
	capture_key_button.tooltip_text = "Capture " + ("override: " if override else "current value: ") + var_to_str(result.value) if result.ok else str(result.error)
	use_current_button.disabled = _current_value == null
	override_mode_button.disabled = _current_value == null
	use_current_button.set_pressed_no_signal(not editing_override)
	override_mode_button.set_pressed_no_signal(editing_override)
	var structured := not component_inputs.is_empty() or is_instance_valid(boolean_input) or is_instance_valid(text_input)
	value_input.visible = editing_override and _editing_enabled and not structured
	value_readout.visible = _show_values and not value_input.visible
	for input in component_inputs:
		input.editable = _override_requested and _editing_enabled
	if is_instance_valid(boolean_input):
		boolean_input.disabled = not (_override_requested and _editing_enabled)
	if is_instance_valid(text_input):
		text_input.editable = _override_requested and _editing_enabled
	capture_hint.visible = not result.ok and _current_value != null and _editing_enabled
	capture_hint.text = str(result.error)
	capture_hint.modulate = EditorInterface.get_base_control().get_theme_color("error_color", "Editor")


func _build_property_browser() -> void:
	property_dialog = AcceptDialog.new()
	property_dialog.title = "New property track"
	property_dialog.min_size = Vector2i(500, 400)
	property_dialog.dialog_hide_on_ok = false
	add_track_button = property_dialog.get_ok_button()
	add_track_button.text = "Add track"
	add_child(property_dialog)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	property_dialog.add_child(body)
	property_row = HBoxContainer.new()
	body.add_child(property_row)
	property_row.add_child(_text("Property", 0))
	property_path = LineEdit.new()
	property_path.placeholder_text = "Search or type a property path"
	property_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_row.add_child(property_path)
	property_search = property_path
	property_search.text_changed.connect(func(_text: String): _filter_properties())
	property_list = ItemList.new()
	property_list.custom_minimum_size = Vector2(460, 260)
	property_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	property_list.item_selected.connect(func(_index: int): _use_property())
	property_list.item_activated.connect(func(_index: int): _use_property(); _try_add_track())
	body.add_child(property_list)
	property_error = _text("", 13)
	property_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	property_error.custom_minimum_size.x = 460
	property_error.hide()
	body.add_child(property_error)
	property_dialog.confirmed.connect(_try_add_track)


func _try_add_track() -> void:
	var count := track_picker.item_count
	var selected := track_picker.selected
	add_track_requested.emit()
	if track_picker.item_count > count or (selected < 0 and track_picker.selected >= 0):
		property_dialog.hide()
	else:
		property_error.text = "Track not added. Choose a valid property on the selected node."
		property_error.show()


func set_target(target: Node) -> void:
	var options := preload("res://addons/tween_animation/editor/timeline_options.gd")
	available_properties = options.properties(target)
	available_actions = options.actions(target)
	property_browser.disabled = not is_instance_valid(target)
	property_browser.tooltip_text = "Add a track for " + str(target.name) if is_instance_valid(target) else "Select a scene node before adding a track."
	property_dialog.title = "New track · " + str(target.name) if is_instance_valid(target) else "New property track"
	action_menu.disabled = available_actions.is_empty()
	property_dialog.hide()
	action_menu.get_popup().clear()
	for index in available_actions.size():
		action_menu.get_popup().add_item(available_actions[index] + "()…", index)
	target_label.text = str(target.name) + (" · " + target.get_class() if str(target.name) != target.get_class() else "") if is_instance_valid(target) else "Select a scene node"
	target_label.tooltip_text = "The selected scene node is the target for new tracks. Existing tracks keep their targets."


func _open_properties() -> void:
	property_error.hide()
	_filter_properties()
	property_dialog.popup_centered()
	property_search.grab_focus()


func _filter_properties() -> void:
	property_list.clear()
	for path in available_properties:
		if property_search.text.is_empty() or path.to_lower().contains(property_search.text.to_lower()):
			property_list.add_item(path)
	if property_list.item_count > 0:
		property_list.select(0)


func _use_property() -> void:
	var indices := property_list.get_selected_items()
	if not indices.is_empty():
		property_path.text = property_list.get_item_text(indices[0])
		property_path.grab_focus()


func focus_lesson(phase: int) -> void:
	target_label.hide()
	track_picker.visible = phase >= 2
	new_track_button.visible = phase == 1
	property_row.show()
	property_dialog.hide()
	action_menu.hide()
	_editing_enabled = phase in [2, 3]
	_show_values = phase >= 2
	format_popup.hide()
	example_row.visible = _editing_enabled
	value_row.visible = phase in [1, 2, 3, 4]
	key_value_card.visible = phase in [1, 2, 3, 4]
	mode_switch.visible = _editing_enabled
	value_readout.visible = phase >= 2
	examples_button.visible = _editing_enabled
	saved_state.get_parent().visible = phase >= 2
	_validate_value()
	separator.visible = phase in [2, 3, 4]
	timeline_row.hide()
	timeline.visible = phase in [2, 3, 4]
	key_heading.visible = phase in [3, 4]
	key_list.visible = phase in [3, 4]


func _scrub_timeline(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_scrubbing = event.pressed
		_scrub_to(event.position.x)
		timeline.grab_focus()
		timeline.accept_event()
	elif event is InputEventMouseMotion and _scrubbing:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_scrub_to(event.position.x)
			timeline.accept_event()
		else:
			_scrubbing = false


func _scrub_to(x: float) -> void:
	time_slider.value = time_slider.max_value * clampf(x / maxf(timeline.size.x, 1.0), 0.0, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_scrubbing = false


func paint(animation: Animation) -> void:
	if animation == null:
		return
	var width := timeline.size.x
	var height := timeline.size.y
	var editor := EditorInterface.get_base_control()
	var foreground := editor.get_theme_color("font_color", "Editor")
	var accent := editor.get_theme_color("accent_color", "Editor")
	var grid := foreground
	grid.a = 0.15
	timeline.draw_rect(Rect2(Vector2.ZERO, Vector2(width, height)), editor.get_theme_color("dark_color_2", "Editor"), true)
	var length := maxf(animation.length, 0.01)
	for tick in range(11):
		var x := width * tick / 10.0
		timeline.draw_line(Vector2(x, 24), Vector2(x, height), grid, 1.0)
		timeline.draw_string(get_theme_font("font", "Label"), Vector2(minf(x + 6, width - 30), 17), "%.1f" % (length * tick / 10.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, foreground)
	var track := track_picker.selected
	if track < 0:
		timeline.draw_string(get_theme_font("font", "Label"), Vector2(20, 85), "Select a node, add a property track, then capture keyframes.", HORIZONTAL_ALIGNMENT_LEFT, width - 40, 14, foreground)
	if track >= 0 and track < animation.get_track_count():
		for key in animation.track_get_key_count(track):
			var x := width * animation.track_get_key_time(track, key) / length
			timeline.draw_circle(Vector2(x, height * 0.55), 5.0, foreground)
	var playhead_x := width * time_slider.value / length
	timeline.draw_line(Vector2(playhead_x, 24), Vector2(playhead_x, height), accent, 2.0)


func _text(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(parent: Control, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(80, 34)
	button.pressed.connect(action)
	var icon_name: String = {"Add track": "Add", "Capture key": "Key", "Capture": "Key", "Properties…": "Search"}.get(caption, "Add")
	button.icon = EditorInterface.get_base_control().get_theme_icon(icon_name, "EditorIcons")
	button.tooltip_text = "Add the selected node property as a track." if caption == "Add track" else "Capture a property value at the playhead time."
	parent.add_child(button)
	return button
