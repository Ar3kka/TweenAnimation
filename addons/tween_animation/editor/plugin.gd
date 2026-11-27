@tool
extends EditorPlugin

const ADDON_ICON := preload("res://addons/tween_animation/icon.svg")
const DEFAULT_LENGTH := 1.0

var page: VBoxContainer
var frame: MarginContainer
var animation: Animation
var animation_path := ""
var duration: SpinBox
var time_slider: HSlider
var time_label: Label
var property_path: LineEdit
var value_input: LineEdit
var track_picker: OptionButton
var timeline: Control
var key_list: ItemList
var status: Label
var play_button: Button
var playing := false
var playback_time := 0.0


func _enter_tree() -> void:
	_build_ui()
	get_editor_interface().get_editor_main_screen().add_child(frame)
	set_process(true)
	_make_visible(false)


func _exit_tree() -> void:
	if is_instance_valid(frame):
		frame.queue_free()


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "Tweenimation"


func _get_plugin_icon() -> Texture2D:
	return ADDON_ICON


func _make_visible(visible: bool) -> void:
	if is_instance_valid(frame):
		frame.visible = visible


func _process(delta: float) -> void:
	if not playing or animation == null:
		return
	playback_time += delta
	if playback_time >= animation.length:
		playback_time = 0.0
	_set_time(playback_time)
	_preview_tracks(playback_time)


func _build_ui() -> void:
	frame = MarginContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.theme = get_editor_interface().get_base_control().theme
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 16)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	page = VBoxContainer.new()
	page.name = "Tweenimation"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	page.add_theme_constant_override("separation", 12)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	_add_card(header)
	var logo := TextureRect.new()
	logo.texture = ADDON_ICON
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(28, 28)
	header.add_child(logo)
	header.add_child(_label("Tweenimation", 22))
	var subtitle := _label("Animation editor", 0)
	subtitle.modulate.a = 0.65
	header.add_child(subtitle)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	page.add_child(toolbar)
	_add_button(toolbar, "New", _new_animation)
	_add_button(toolbar, "Open", _open_animation)
	_add_button(toolbar, "Save", _save_animation)
	_add_button(toolbar, "Save As", _save_animation_as)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	play_button = Button.new()
	play_button.text = "Play preview"
	play_button.icon = _editor_icon("Play")
	play_button.tooltip_text = "Preview the animation on the currently edited scene."
	play_button.pressed.connect(_toggle_play)
	toolbar.add_child(play_button)
	_add_button(toolbar, "Rewind", func():
		playing = false
		play_button.text = "Play preview"
		_set_time(0.0)
		_set_status("Rewound to the beginning.")
	)
	toolbar.add_child(_label("Length", 0))
	duration = _spin_box(0.1, 60.0, 0.1)
	duration.value = DEFAULT_LENGTH
	duration.suffix = "s"
	duration.value_changed.connect(_set_length)
	toolbar.add_child(duration)

	page.add_child(HSeparator.new())
	page.add_child(_label("PROPERTY TRACKS", 12))
	var edit_row := VBoxContainer.new()
	edit_row.add_theme_constant_override("separation", 8)
	_add_card(edit_row)
	var track_row := HBoxContainer.new()
	edit_row.add_child(track_row)
	track_row.add_theme_constant_override("separation", 10)
	track_row.add_child(_field_label("Active track"))
	track_picker = OptionButton.new()
	track_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_picker.item_selected.connect(_select_track)
	track_picker.tooltip_text = "Select a track to view and capture its keyframes."
	track_row.add_child(track_picker)
	var property_row := HBoxContainer.new()
	edit_row.add_child(property_row)
	property_row.add_theme_constant_override("separation", 10)
	property_row.add_child(_field_label("Node property"))
	property_path = LineEdit.new()
	property_path.placeholder_text = "Property on selected node, e.g. position"
	property_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_path.tooltip_text = "Select a scene node, then enter a property such as position, scale or modulate:a."
	property_row.add_child(property_path)
	_add_button(property_row, "Add track", _add_track)
	var value_row := HBoxContainer.new()
	edit_row.add_child(value_row)
	value_row.add_theme_constant_override("separation", 10)
	value_row.add_child(_field_label("Keyframe value"))
	value_input = LineEdit.new()
	value_input.placeholder_text = "Leave empty to capture the node's current value"
	value_input.tooltip_text = "Optional override: a number, Vector2(100, 50), or Vector3(0, 1, 0)."
	value_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_row.add_child(value_input)
	_add_button(value_row, "Capture key", _capture_key)
	page.add_child(HSeparator.new())
	page.add_child(_label("TIMELINE", 12))

	var timeline_row := HBoxContainer.new()
	page.add_child(timeline_row)
	time_label = _label("0.00s", 0)
	time_label.custom_minimum_size.x = 70
	timeline_row.add_child(time_label)
	time_slider = HSlider.new()
	time_slider.min_value = 0.0
	time_slider.max_value = DEFAULT_LENGTH
	time_slider.step = 0.01
	time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_slider.value_changed.connect(_on_time_changed)
	timeline_row.add_child(time_slider)

	timeline = Control.new()
	timeline.custom_minimum_size = Vector2(0, 200)
	timeline.tooltip_text = "Click to scrub. Gold markers show keyframes on the active track."
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.draw.connect(_draw_timeline)
	timeline.gui_input.connect(_timeline_input)
	page.add_child(timeline)

	page.add_child(_label("KEYFRAMES  ·  Select a key to jump to its time", 12))
	key_list = ItemList.new()
	key_list.custom_minimum_size.y = 90
	key_list.item_selected.connect(_select_key)
	page.add_child(key_list)
	status = _label("Create an animation, select a node, then add a property track.", 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 40
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var status_style := StyleBoxFlat.new()
	var editor := get_editor_interface().get_base_control()
	status_style.bg_color = editor.get_theme_color("dark_color_1", "Editor")
	status_style.border_color = editor.get_theme_color("accent_color", "Editor")
	status_style.border_width_left = 3
	status_style.content_margin_left = 12
	status_style.content_margin_right = 12
	status_style.content_margin_top = 8
	status_style.content_margin_bottom = 8
	status.add_theme_stylebox_override("normal", status_style)
	page.add_child(status)
	page.move_child(status, 2)
	_new_animation()


func _new_animation() -> void:
	playing = false
	playback_time = 0.0
	play_button.text = "Play preview"
	animation = Animation.new()
	animation.length = DEFAULT_LENGTH
	animation.step = 0.1
	animation_path = ""
	duration.value = DEFAULT_LENGTH
	time_slider.max_value = DEFAULT_LENGTH
	_refresh_tracks()
	key_list.clear()
	_set_time(0.0)
	_redraw_timeline()
	_set_status("New animation. Add a track for the selected node's property.")


func _add_track() -> void:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.is_empty():
		_set_status("Select a node in the Scene tree first.")
		return
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or (root != selected[0] and not root.is_ancestor_of(selected[0])):
		_set_status("Select a node inside the currently edited scene.")
		return
	var property_name := property_path.text.strip_edges()
	if property_name.is_empty() or not _has_property(selected[0], property_name):
		_set_status("Enter a valid property name for the selected node.")
		return
	var track := animation.add_track(Animation.TYPE_VALUE)
	var node_path := root.get_path_to(selected[0])
	animation.track_set_path(track, NodePath(str(node_path) + ":" + property_name))
	_refresh_tracks(track)
	_set_status("Track added: %s:%s" % [node_path, property_name])


func _capture_key() -> void:
	var track := track_picker.selected
	if track < 0 or track >= animation.get_track_count():
		_set_status("Add or select a track first.")
		return
	var root := get_editor_interface().get_edited_scene_root()
	var track_path := animation.track_get_path(track)
	var target := root.get_node_or_null(NodePath(track_path.get_concatenated_names())) if root else null
	if target == null:
		_set_status("The node for this track is not in the edited scene.")
		return
	var property_name := str(track_path.get_concatenated_subnames())
	var value: Variant
	if value_input.text.strip_edges().is_empty():
		value = target.get_indexed(NodePath(property_name))
	else:
		value = _parse_value(value_input.text.strip_edges())
	if value == null:
		_set_status("Could not read that property value. Enter a valid value or select its node.")
		return
	animation.track_insert_key(track, time_slider.value, value)
	_refresh_keys(track)
	_redraw_timeline()
	_set_status("Keyframe added at %.2fs." % time_slider.value)


func _preview_tracks(at_time: float) -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return
	for index in animation.get_track_count():
		var path := animation.track_get_path(index)
		var target := root.get_node_or_null(NodePath(path.get_concatenated_names()))
		if target == null:
			continue
		var value := animation.value_track_interpolate(index, at_time)
		if value != null:
			target.set_indexed(NodePath(path.get_concatenated_subnames()), value)


func _save_animation() -> void:
	if animation_path.is_empty():
		_save_animation_as()
		return
	var error := ResourceSaver.save(animation, animation_path)
	_set_status("Saved animation." if error == OK else "Save failed (error %d)." % error)


func _save_animation_as() -> void:
	_set_status("Choose a location and filename to save the animation.")
	var dialog := FileDialog.new()
	dialog.title = "Save Tweenimation animation"
	dialog.current_file = "animation.tres"
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Godot Resource")
	dialog.file_selected.connect(func(path: String):
		animation_path = path
		_save_animation()
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		_set_status("Save canceled.")
		dialog.queue_free()
	)
	page.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 500))


func _open_animation() -> void:
	_set_status("Choose a Godot Animation resource (.tres) to open.")
	var dialog := FileDialog.new()
	dialog.title = "Open Tweenimation animation"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Godot Resource")
	dialog.file_selected.connect(func(path: String):
		var loaded := ResourceLoader.load(path) as Animation
		if loaded:
			playing = false
			play_button.text = "Play preview"
			animation = loaded
			animation_path = path
			duration.value = animation.length
			time_slider.max_value = animation.length
			_refresh_tracks()
			_set_time(0.0)
			_set_status("Opened %s" % path.get_file())
		else:
			_set_status("That resource is not a Godot Animation.")
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		_set_status("Open canceled.")
		dialog.queue_free()
	)
	page.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 500))


func _refresh_tracks(select: int = -1) -> void:
	track_picker.clear()
	for index in animation.get_track_count():
		track_picker.add_item(str(animation.track_get_path(index)))
	if animation.get_track_count() > 0:
		track_picker.select(clampi(select, 0, animation.get_track_count() - 1))
		_refresh_keys(track_picker.selected)
	else:
		track_picker.add_item("No tracks — select a scene node, then add a property")
		track_picker.set_item_disabled(0, true)
		track_picker.select(-1)
		key_list.clear()
	_redraw_timeline()


func _refresh_keys(track: int) -> void:
	key_list.clear()
	if track < 0 or track >= animation.get_track_count():
		return
	for key in animation.track_get_key_count(track):
		var time := animation.track_get_key_time(track, key)
		var value := animation.track_get_key_value(track, key)
		key_list.add_item("%.2fs   %s" % [time, value])


func _select_track(index: int) -> void:
	_refresh_keys(index)
	_redraw_timeline()


func _select_key(index: int) -> void:
	var track := track_picker.selected
	if track >= 0 and index >= 0:
		_set_time(animation.track_get_key_time(track, index))


func _set_length(value: float) -> void:
	if animation == null:
		return
	animation.length = value
	time_slider.max_value = value
	_set_time(minf(time_slider.value, value))
	_redraw_timeline()


func _on_time_changed(value: float) -> void:
	time_label.text = "%.2fs" % value
	playback_time = value
	_redraw_timeline()
	if not playing:
		_preview_tracks(value)


func _set_time(value: float) -> void:
	time_slider.set_value_no_signal(value)
	_on_time_changed(value)


func _toggle_play() -> void:
	if get_editor_interface().get_edited_scene_root() == null:
		_set_status("Open a scene before previewing its animation.")
		return
	if animation.get_track_count() == 0:
		_set_status("Add a property track and capture keyframes before playing.")
		return
	var key_count := 0
	for track in animation.get_track_count():
		key_count += animation.track_get_key_count(track)
	if key_count == 0:
		_set_status("Capture at least one keyframe before playing.")
		return
	playing = not playing
	play_button.text = "Pause preview" if playing else "Play preview"
	play_button.icon = _editor_icon("Pause" if playing else "Play")
	playback_time = time_slider.value
	_set_status("Preview playing." if playing else "Preview paused.")


func _draw_timeline() -> void:
	if animation == null:
		return
	var width := timeline.size.x
	var height := timeline.size.y
	var editor := get_editor_interface().get_base_control()
	var foreground := editor.get_theme_color("font_color", "Editor")
	var accent := editor.get_theme_color("accent_color", "Editor")
	var grid := foreground
	grid.a = 0.15
	timeline.draw_rect(Rect2(Vector2.ZERO, Vector2(width, height)), editor.get_theme_color("dark_color_2", "Editor"), true)
	var length := maxf(animation.length, 0.01)
	for tick in range(11):
		var x := width * tick / 10.0
		timeline.draw_line(Vector2(x, 24), Vector2(x, height), grid, 1.0)
		timeline.draw_string(page.get_theme_font("font", "Label"), Vector2(minf(x + 6, width - 30), 17), "%.1f" % (length * tick / 10.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, foreground)
	var track := track_picker.selected
	if track < 0:
		timeline.draw_string(page.get_theme_font("font", "Label"), Vector2(20, 85), "Select a node, add a property track, then capture keyframes.", HORIZONTAL_ALIGNMENT_LEFT, width - 40, 14, foreground)
	if track >= 0 and track < animation.get_track_count():
		for key in animation.track_get_key_count(track):
			var x := width * animation.track_get_key_time(track, key) / length
			timeline.draw_circle(Vector2(x, height * 0.55), 5.0, foreground)
	var playhead_x := width * time_slider.value / length
	timeline.draw_line(Vector2(playhead_x, 24), Vector2(playhead_x, height), accent, 2.0)


func _timeline_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_time(animation.length * clampf(event.position.x / timeline.size.x, 0.0, 1.0))


func _redraw_timeline() -> void:
	if is_instance_valid(timeline):
		timeline.queue_redraw()


func _parse_value(text: String) -> Variant:
	if text.is_valid_float():
		return text.to_float()
	var vector_regex := RegEx.new()
	vector_regex.compile("^Vector([23])\\(([^()]*)\\)$")
	var vector_match := vector_regex.search(text)
	if vector_match == null:
		return null
	var components := vector_match.get_string(2).split(",", false)
	if components.size() != int(vector_match.get_string(1)):
		return null
	var numbers: Array[float] = []
	for component in components:
		var cleaned := component.strip_edges()
		if not cleaned.is_valid_float():
			return null
		numbers.append(cleaned.to_float())
	if numbers.size() == 2:
		return Vector2(numbers[0], numbers[1])
	return Vector3(numbers[0], numbers[1], numbers[2])


func _has_property(target: Object, name: String) -> bool:
	for item in target.get_property_list():
		if str(item.name) == name:
			return true
	return false


func _add_button(parent: Control, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	var icons := {"New": "New", "Open": "Load", "Save": "Save", "Save As": "Save", "Rewind": "Stop", "Add track": "Add", "Capture key": "Key"}
	button.icon = _editor_icon(icons.get(title, ""))
	button.custom_minimum_size = Vector2(80, 34)
	var hints := {
		"New": "Start a new, empty animation. Unsaved animation data will be discarded.",
		"Open": "Open an existing Godot Animation resource (.tres).",
		"Save": "Save the animation, or choose a file for a new animation.",
		"Save As": "Save the animation to a new resource file.",
		"Rewind": "Stop playback and preview the animation at 0 seconds.",
		"Add track": "Add the named property from the selected scene node.",
		"Capture key": "Store the current or typed property value at the playhead time."
	}
	button.tooltip_text = hints.get(title, title)
	button.pressed.connect(action)
	parent.add_child(button)


func _editor_icon(name: String) -> Texture2D:
	var editor := get_editor_interface().get_base_control()
	if editor.has_theme_icon(name, "EditorIcons"):
		return editor.get_theme_icon(name, "EditorIcons")
	return null


func _add_card(content: Control) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", get_editor_interface().get_base_control().get_theme_stylebox("panel", "PanelContainer"))
	page.add_child(panel)
	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(padding)
	padding.add_child(content)


func _field_label(text: String) -> Label:
	var label := _label(text, 0)
	label.custom_minimum_size.x = 120
	return label


func _spin_box(minimum: float, maximum: float, step: float) -> SpinBox:
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	return field


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	return label


func _set_status(message: String) -> void:
	if is_instance_valid(status):
		status.text = message
