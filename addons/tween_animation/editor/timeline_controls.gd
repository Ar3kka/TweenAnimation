@tool
extends VBoxContainer
## Shared real controls for the editor and isolated tutorial practice previews.

signal add_track_requested
signal capture_key_requested
signal track_selected(index: int)
signal time_changed(value: float)
signal key_selected(index: int)
signal draw_requested
signal timeline_input(event: InputEvent)
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
var key_context: Label
var accepted_values_label: Label
var capture_hint: Label
var example_row: HFlowContainer
var use_current_button: Button
var type_badge: Button
var mode_switch: HBoxContainer
var override_mode_button: Button
var examples_button: Button
var format_popup: PopupPanel
var value_readout: HFlowContainer
var saved_state: Label
var saved_icon: TextureRect
var _readout_type := -1
var _component_labels: Array[Label] = []
var _editing_enabled := true
var _override_requested := false
var _current_value: Variant = null
var _property_name := ""
var _example_signature := ""


func build() -> void:
	add_theme_constant_override("separation", 8)
	var workspace: VBoxContainer = self
	workspace.add_child(_text("TRACKS", 12))
	target_label = _text("Select a node in Godot's Scene tree to browse its properties and actions.", 0)
	target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workspace.add_child(target_label)
	var track_tools := HFlowContainer.new()
	track_tools.add_theme_constant_override("h_separation", 8)
	track_tools.add_theme_constant_override("v_separation", 6)
	workspace.add_child(track_tools)
	track_picker = OptionButton.new()
	track_picker.custom_minimum_size.x = 180
	track_picker.fit_to_longest_item = false
	track_picker.item_selected.connect(track_selected.emit)
	track_picker.tooltip_text = "Select a track to view and capture its keyframes."
	track_tools.add_child(track_picker)
	property_row = HBoxContainer.new()
	track_tools.add_child(property_row)
	property_row.add_theme_constant_override("separation", 4)
	property_path = LineEdit.new()
	property_path.placeholder_text = "Property: position"
	property_path.custom_minimum_size.x = 160
	property_path.tooltip_text = "Select a scene node, then enter a property such as position, scale or modulate:a."
	property_row.add_child(property_path)
	property_browser = _button(property_row, "Properties…", _open_properties)
	property_browser.text = ""
	property_browser.custom_minimum_size = Vector2(34, 34)
	property_browser.tooltip_text = "Search writable value-track properties on the selected node. You can also type a property path."
	action_menu = MenuButton.new()
	action_menu.text = "Actions"
	action_menu.tooltip_text = "Create editable keys inspired by Tweenimator effects. These are value-track templates, not runtime Tween calls."
	action_menu.get_popup().id_pressed.connect(func(index: int): action_requested.emit(available_actions[index]))
	property_row.add_child(action_menu)
	add_track_button = _button(property_row, "Add track", add_track_requested.emit)
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
	time_slider.step = 0.01
	time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_slider.value_changed.connect(time_changed.emit)
	timeline_row.add_child(time_slider)

	timeline = Control.new()
	timeline.custom_minimum_size = Vector2(0, 200)
	timeline.tooltip_text = "Click to scrub. Gold markers show keyframes on the active track."
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.draw.connect(draw_requested.emit)
	timeline.gui_input.connect(timeline_input.emit)
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
	var header := HFlowContainer.new()
	header.add_theme_constant_override("h_separation", 8)
	header.add_theme_constant_override("v_separation", 6)
	body.add_child(header)
	var key_icon := TextureRect.new()
	key_icon.texture = editor.get_theme_icon("Key", "EditorIcons")
	key_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	key_icon.custom_minimum_size = Vector2(18, 30)
	header.add_child(key_icon)
	key_context = _text("Select a track", 14)
	key_context.clip_text = true
	key_context.custom_minimum_size.x = 140
	key_context.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(key_context)
	type_badge = Button.new()
	type_badge.flat = true
	type_badge.pressed.connect(_open_value_help)
	header.add_child(type_badge)
	mode_switch = HBoxContainer.new()
	mode_switch.add_theme_constant_override("separation", 0)
	header.add_child(mode_switch)
	var modes := ButtonGroup.new()
	use_current_button = Button.new()
	use_current_button.text = "Current"
	use_current_button.toggle_mode = true
	use_current_button.button_group = modes
	use_current_button.tooltip_text = "Capture the live property value. Clears any typed override."
	use_current_button.pressed.connect(func():
		_override_requested = false
		value_input.clear()
		_validate_value()
		override_changed.emit()
	)
	mode_switch.add_child(use_current_button)
	override_mode_button = Button.new()
	override_mode_button.text = "Override"
	override_mode_button.toggle_mode = true
	override_mode_button.button_group = modes
	override_mode_button.tooltip_text = "Type a different value to capture without changing the scene first."
	override_mode_button.pressed.connect(func():
		_override_requested = true
		value_input.text = var_to_str(_current_value)
		_validate_value()
		value_input.grab_focus()
		value_input.select_all()
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
	examples_button = Button.new()
	examples_button.text = "Examples"
	examples_button.flat = true
	examples_button.icon = editor.get_theme_icon("Help", "EditorIcons")
	examples_button.pressed.connect(_open_value_help)
	header.add_child(examples_button)
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
	value_row = HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 10)
	body.add_child(value_row)
	value_readout = HFlowContainer.new()
	value_readout.add_theme_constant_override("h_separation", 6)
	value_readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_row.add_child(value_readout)
	value_input = LineEdit.new()
	value_input.placeholder_text = "Empty = current value"
	value_input.custom_minimum_size.x = 220
	value_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_input.text_changed.connect(func(_text: String): _validate_value(); override_changed.emit())
	value_row.add_child(value_input)
	capture_key_button = _button(value_row, "Capture key", capture_key_requested.emit)
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
	if _property_name != property:
		_override_requested = false
		value_input.clear()
	_current_value = current
	_property_name = property
	key_context.text = property.substr(property.find(":") + 1) if ":" in property else (property if not property.is_empty() else "Select a track")
	key_context.tooltip_text = property
	value_readout.tooltip_text = source + ": " + var_to_str(current)
	use_current_button.tooltip_text = source + ": " + var_to_str(current) + "\nCapture this live value; clears the override."
	saved_state.text = "%.2f s · %s" % [at_time, "Key" if has_key else "Empty"]
	saved_state.tooltip_text = "Saved key: " + var_to_str(saved) if has_key else "No key at this exact time. Capture key to record a value here."
	saved_icon.tooltip_text = saved_state.tooltip_text
	saved_icon.modulate.a = 1.0 if has_key else 0.35
	var details := preload("res://addons/tween_animation/editor/key_values.gd").describe(current, property, info)
	accepted_values_label.text = "Accepts " + str(details.accepted) if current != null else "Choose a property track whose target exists in the current scene."
	type_badge.text = type_string(typeof(current)) if current != null else "—"
	type_badge.tooltip_text = accepted_values_label.text
	value_input.tooltip_text = accepted_values_label.text
	_update_readout(current)
	var signature := str(details)
	if signature != _example_signature:
		_example_signature = signature
		for child in example_row.get_children():
			example_row.remove_child(child)
			child.queue_free()
		for example in details.examples:
			var button := Button.new()
			button.text = example
			button.tooltip_text = "Use this as the key override."
			button.pressed.connect(func():
				_override_requested = true
				value_input.text = example
				_validate_value()
				format_popup.hide()
				override_changed.emit()
			)
			example_row.add_child(button)
	_validate_value()


func _update_readout(value: Variant) -> void:
	var type := typeof(value)
	if type != _readout_type:
		_readout_type = type
		_component_labels.clear()
		for child in value_readout.get_children():
			value_readout.remove_child(child)
			child.queue_free()
		var axes := "XYZW".left(2 if type in [TYPE_VECTOR2, TYPE_VECTOR2I] else (3 if type in [TYPE_VECTOR3, TYPE_VECTOR3I] else 4)) if type in [TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I] else ("RGBA" if type == TYPE_COLOR else "")
		var colors := [Color("ef7979"), Color("8dca85"), Color("7aa8ef"), Color("b9a3de")]
		for index in maxi(axes.length(), 1):
			var chip := PanelContainer.new()
			var style := StyleBoxFlat.new()
			style.bg_color = EditorInterface.get_base_control().get_theme_color("dark_color_1", "Editor")
			style.set_content_margin_all(6)
			style.set_corner_radius_all(3)
			chip.add_theme_stylebox_override("panel", style)
			value_readout.add_child(chip)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 9)
			chip.add_child(row)
			if not axes.is_empty():
				var axis := _text(axes[index], 13)
				axis.modulate = colors[index]
				row.add_child(axis)
			var number := _text("", 14)
			number.add_theme_font_override("font", EditorInterface.get_base_control().get_theme_font("source", "EditorFonts"))
			row.add_child(number)
			_component_labels.append(number)
	for index in _component_labels.size():
		var text := var_to_str(value[index]) if _component_labels.size() > 1 else (var_to_str(value) if value != null else "No value")
		_component_labels[index].text = text.left(49) + "…" if text.length() > 52 else text
		_component_labels[index].tooltip_text = text


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
	value_input.visible = editing_override and _editing_enabled
	value_readout.visible = not editing_override or not _editing_enabled
	capture_hint.visible = not result.ok and _current_value != null and _editing_enabled
	capture_hint.text = str(result.error)
	capture_hint.modulate = EditorInterface.get_base_control().get_theme_color("error_color", "Editor")


func _build_property_browser() -> void:
	property_dialog = AcceptDialog.new()
	property_dialog.title = "Selected node · animatable value properties"
	property_dialog.min_size = Vector2i(500, 400)
	property_dialog.get_ok_button().text = "Use property"
	add_child(property_dialog)
	var body := VBoxContainer.new()
	property_dialog.add_child(body)
	property_search = LineEdit.new()
	property_search.placeholder_text = "Search properties, e.g. position, alpha, shader…"
	property_search.text_changed.connect(func(_text: String): _filter_properties())
	body.add_child(property_search)
	property_list = ItemList.new()
	property_list.custom_minimum_size = Vector2(460, 280)
	property_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	property_list.item_activated.connect(func(_index: int): _use_property(); property_dialog.hide())
	body.add_child(property_list)
	property_dialog.confirmed.connect(_use_property)


func set_target(target: Node) -> void:
	var options := preload("res://addons/tween_animation/editor/timeline_options.gd")
	available_properties = options.properties(target)
	available_actions = options.actions(target)
	property_browser.disabled = available_properties.is_empty()
	action_menu.disabled = available_actions.is_empty()
	property_dialog.hide()
	action_menu.get_popup().clear()
	for index in available_actions.size():
		action_menu.get_popup().add_item(available_actions[index] + "()…", index)
	target_label.text = str(target.name) + (" · " + target.get_class() if str(target.name) != target.get_class() else "") if is_instance_valid(target) else "Select a scene node"
	target_label.tooltip_text = "The selected scene node is the target for new tracks. Existing tracks keep their targets."


func _open_properties() -> void:
	property_search.clear()
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
	# The real editor shows everything; practice progressively reveals relevant controls.
	target_label.visible = phase > 0
	track_picker.visible = phase >= 2
	property_row.visible = phase == 1
	action_menu.hide()
	_editing_enabled = phase in [2, 3]
	format_popup.hide()
	example_row.visible = _editing_enabled
	value_row.visible = phase in [2, 3, 4]
	key_value_card.visible = phase in [2, 3, 4]
	mode_switch.visible = _editing_enabled
	examples_button.visible = _editing_enabled
	_validate_value()
	separator.visible = phase in [2, 3, 4]
	timeline_row.visible = phase in [2, 3, 4]
	timeline.visible = phase in [2, 3, 4]
	key_heading.visible = phase in [3, 4]
	key_list.visible = phase in [3, 4]


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
	var icon_name: String = {"Add track": "Add", "Capture key": "Key", "Properties…": "Search"}.get(caption, "Add")
	button.icon = EditorInterface.get_base_control().get_theme_icon(icon_name, "EditorIcons")
	button.tooltip_text = "Add the selected node property as a track." if caption == "Add track" else "Capture a property value at the playhead time."
	parent.add_child(button)
	return button
