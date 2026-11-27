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
var current_value_label: Label
var saved_value_label: Label
var accepted_values_label: Label
var capture_hint: Label
var example_row: HFlowContainer
var use_current_button: Button
var _current_value: Variant = null
var _property_name := ""
var _example_signature := ""


func build() -> void:
	add_theme_constant_override("separation", 8)
	var workspace: VBoxContainer = self
	workspace.add_child(_text("TIMELINE  ·  2D / 3D / UI properties", 12))
	target_label = _text("Select a node in Godot's Scene tree to browse its properties and actions.", 0)
	target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workspace.add_child(target_label)
	var track_tools := HFlowContainer.new()
	track_tools.add_theme_constant_override("h_separation", 8)
	track_tools.add_theme_constant_override("v_separation", 6)
	workspace.add_child(track_tools)
	track_picker = OptionButton.new()
	track_picker.custom_minimum_size.x = 200
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
	property_browser.tooltip_text = "Search writable value-track properties on the selected node. You can also type a property path."
	action_menu = MenuButton.new()
	action_menu.text = "Action templates"
	action_menu.tooltip_text = "Create editable keys inspired by Tweenimator effects. These are value-track templates, not runtime Tween calls."
	action_menu.get_popup().id_pressed.connect(func(index: int): action_requested.emit(available_actions[index]))
	property_row.add_child(action_menu)
	add_track_button = _button(property_row, "Add track", add_track_requested.emit)
	key_value_card = PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = EditorInterface.get_base_control().get_theme_color("dark_color_2", "Editor")
	card_style.set_content_margin_all(12)
	card_style.set_corner_radius_all(5)
	key_value_card.add_theme_stylebox_override("panel", card_style)
	workspace.add_child(key_value_card)
	var key_body := VBoxContainer.new()
	key_body.add_theme_constant_override("separation", 8)
	key_value_card.add_child(key_body)
	key_context = _text("KEY VALUE · Select a property track", 13)
	key_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	key_body.add_child(key_context)
	current_value_label = _text("Current value: unavailable", 15)
	current_value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current_value_label.add_theme_font_override("font", EditorInterface.get_base_control().get_theme_font("source", "EditorFonts"))
	key_body.add_child(current_value_label)
	value_row = HBoxContainer.new()
	key_body.add_child(value_row)
	value_row.add_theme_constant_override("separation", 4)
	value_input = LineEdit.new()
	value_input.placeholder_text = "Override (optional) · empty uses current value"
	value_input.tooltip_text = "Type a value using the examples below, or leave empty to capture the displayed current value."
	value_input.custom_minimum_size.x = 240
	value_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_input.text_changed.connect(func(_text: String): _validate_value(); override_changed.emit())
	value_row.add_child(value_input)
	capture_key_button = _button(value_row, "Capture key", capture_key_requested.emit)
	use_current_button = _button(value_row, "Use current", func(): value_input.clear(); _validate_value(); override_changed.emit())
	use_current_button.tooltip_text = "Clear the override. Capture key will read the current value shown above."
	accepted_values_label = _text("", 14)
	accepted_values_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	key_body.add_child(accepted_values_label)
	example_row = HFlowContainer.new()
	example_row.add_theme_constant_override("h_separation", 6)
	key_body.add_child(example_row)
	capture_hint = _text("", 14)
	capture_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	key_body.add_child(capture_hint)
	saved_value_label = _text("", 13)
	saved_value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	key_body.add_child(saved_value_label)
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


func set_value_context(property: String, current: Variant, info: Dictionary = {}, saved: Variant = null, has_key: bool = false, at_time: float = 0.0, source: String = "Node value") -> void:
	if _property_name != property:
		value_input.clear()
	_current_value = current
	_property_name = property
	key_context.text = "KEY VALUE · " + (property if not property.is_empty() else "Select a property track")
	current_value_label.text = "%s: %s" % [source, var_to_str(current) if current != null else "unavailable"]
	current_value_label.tooltip_text = "This is the tracked property's current value. Selecting another node does not retarget an existing track."
	saved_value_label.text = "At %.2f s · %s" % [at_time, "saved key: " + var_to_str(saved) if has_key else "no key at this exact time"]
	var details := preload("res://addons/tween_animation/editor/key_values.gd").describe(current, property, info)
	accepted_values_label.text = "Accepts " + str(details.accepted) if current != null else "Choose a value track whose target exists in the current scene."
	var signature := str(details)
	if signature != _example_signature:
		_example_signature = signature
		for child in example_row.get_children():
			example_row.remove_child(child)
			child.queue_free()
		if not details.examples.is_empty():
			example_row.add_child(_text("Try a value:", 0))
		for example in details.examples:
			var button := Button.new()
			button.text = example
			button.tooltip_text = "Use " + example + " as the key value override."
			button.pressed.connect(func():
				value_input.text = example
				_validate_value()
				override_changed.emit()
			)
			example_row.add_child(button)
	_validate_value()


func capture_value() -> Dictionary:
	return preload("res://addons/tween_animation/editor/key_values.gd").parse(value_input.text, _current_value)


func _validate_value() -> void:
	if not is_instance_valid(capture_hint):
		return
	var result := capture_value()
	capture_key_button.disabled = not result.ok
	use_current_button.disabled = _current_value == null or value_input.text.is_empty()
	var editor := EditorInterface.get_base_control()
	capture_hint.modulate = editor.get_theme_color("font_color", "Editor") if result.ok else editor.get_theme_color("error_color", "Editor")
	if not result.ok:
		capture_hint.text = str(result.error)
	elif value_input.text.strip_edges().is_empty():
		capture_hint.text = "Capture key will record the current value shown above."
	else:
		capture_hint.text = "Capture key will record your override: " + var_to_str(result.value)


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
	target_label.text = "Target for new tracks: %s (%s) · type a path or choose a property/action." % [target.name, target.get_class()] if is_instance_valid(target) else "Select a node in Godot's Scene tree to browse its properties and actions."


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
	value_row.visible = phase in [2, 3]
	key_value_card.visible = phase in [2, 3, 4]
	example_row.visible = phase in [2, 3]
	capture_hint.visible = phase in [2, 3]
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
	var icon_name: String = {"Add track": "Add", "Capture key": "Key", "Properties…": "Search", "Use current": "Reload"}.get(caption, "Add")
	button.icon = EditorInterface.get_base_control().get_theme_icon(icon_name, "EditorIcons")
	button.tooltip_text = "Add the selected node property as a track." if caption == "Add track" else "Capture a property value at the playhead time."
	parent.add_child(button)
	return button
