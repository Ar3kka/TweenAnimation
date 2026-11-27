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


func build() -> void:
	add_theme_constant_override("separation", 8)
	var workspace: VBoxContainer = self
	workspace.add_child(_text("TIMELINE  ·  2D / 3D / UI properties", 12))
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
	var property_row := HBoxContainer.new()
	track_tools.add_child(property_row)
	property_row.add_theme_constant_override("separation", 4)
	property_path = LineEdit.new()
	property_path.placeholder_text = "Property: position"
	property_path.custom_minimum_size.x = 160
	property_path.tooltip_text = "Select a scene node, then enter a property such as position, scale or modulate:a."
	property_row.add_child(property_path)
	add_track_button = _button(property_row, "Add track", add_track_requested.emit)
	var value_row := HBoxContainer.new()
	track_tools.add_child(value_row)
	value_row.add_theme_constant_override("separation", 4)
	value_input = LineEdit.new()
	value_input.placeholder_text = "Value: current"
	value_input.tooltip_text = "Leave empty to capture the node's current value. Override with a number, Vector2(100, 50), or Vector3(0, 1, 0)."
	value_input.custom_minimum_size.x = 160
	value_row.add_child(value_input)
	capture_key_button = _button(value_row, "Capture key", capture_key_requested.emit)
	workspace.add_child(HSeparator.new())

	var timeline_row := HBoxContainer.new()
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

	workspace.add_child(_text("KEYFRAMES  ·  Select a key to jump to its time", 12))
	key_list = ItemList.new()
	key_list.custom_minimum_size.y = 90
	key_list.item_selected.connect(key_selected.emit)
	workspace.add_child(key_list)


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
	var icon_name := "Add" if caption == "Add track" else "Key"
	button.icon = EditorInterface.get_base_control().get_theme_icon(icon_name, "EditorIcons")
	button.tooltip_text = "Add the selected node property as a track." if caption == "Add track" else "Capture a property value at the playhead time."
	parent.add_child(button)
	return button
