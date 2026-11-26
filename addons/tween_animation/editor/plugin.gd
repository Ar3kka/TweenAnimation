@tool
extends EditorPlugin

const ADDON_ICON := preload("../icon.svg")
const DEFAULT_LENGTH := 1.0

var page: VBoxContainer
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
var playing := false
var playback_time := 0.0


func _enter_tree() -> void:
	_build_ui()
	get_editor_interface().get_editor_main_screen().add_child(page)
	set_process(true)
	_make_visible(false)


func _exit_tree() -> void:
	if is_instance_valid(page):
		page.queue_free()


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "Tween Animation"


func _get_plugin_icon() -> Texture2D:
	return ADDON_ICON


func _make_visible(visible: bool) -> void:
	if is_instance_valid(page):
		page.visible = visible


func _process(delta: float) -> void:
	if not playing or animation == null:
		return
	playback_time += delta
	if playback_time >= animation.length:
		playback_time = 0.0
	_set_time(playback_time)
	_preview_tracks(playback_time)


func _build_ui() -> void:
	page = VBoxContainer.new()
	page.name = "Tween Animation"
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 8)
	page.add_child(_label("Tween Animation", 24))
	page.add_child(_label("Create reusable property animations with keyframes.", 0))

	var toolbar := HBoxContainer.new()
	page.add_child(toolbar)
	_add_button(toolbar, "New", _new_animation)
	_add_button(toolbar, "Open", _open_animation)
	_add_button(toolbar, "Save", _save_animation)
	_add_button(toolbar, "Save As", _save_animation_as)
	_add_button(toolbar, "Play / Pause", _toggle_play)
	toolbar.add_child(_label("Length", 0))
	duration = _spin_box(0.1, 60.0, 0.1)
	duration.value = DEFAULT_LENGTH
	duration.value_changed.connect(_set_length)
	toolbar.add_child(duration)

	var edit_row := HBoxContainer.new()
	page.add_child(edit_row)
	edit_row.add_child(_label("Track", 0))
	track_picker = OptionButton.new()
	track_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_picker.item_selected.connect(_select_track)
	edit_row.add_child(track_picker)
	property_path = LineEdit.new()
	property_path.placeholder_text = "Property on selected node, e.g. position"
	property_path.custom_minimum_size.x = 240
	edit_row.add_child(property_path)
	_add_button(edit_row, "Add selected property", _add_track)
	value_input = LineEdit.new()
	value_input.placeholder_text = "Key value (e.g. 20, 1.2, or Vector2(100, 50))"
	value_input.custom_minimum_size.x = 260
	edit_row.add_child(value_input)
	_add_button(edit_row, "Key selected value", _capture_key)

	var timeline_row := HBoxContainer.new()
	page.add_child(timeline_row)
	time_label = _label("0.00s", 0)
	timeline_row.add_child(time_label)
	time_slider = HSlider.new()
	time_slider.min_value = 0.0
	time_slider.max_value = DEFAULT_LENGTH
	time_slider.step = 0.01
	time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_slider.value_changed.connect(_on_time_changed)
	timeline_row.add_child(time_slider)

	timeline = Control.new()
	timeline.custom_minimum_size = Vector2(0, 110)
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.draw.connect(_draw_timeline)
	timeline.gui_input.connect(_timeline_input)
	page.add_child(timeline)

	key_list = ItemList.new()
	key_list.custom_minimum_size.y = 90
	key_list.item_selected.connect(_select_key)
	page.add_child(key_list)
	status = _label("Create an animation, select a node, then add a property track.", 0)
	page.add_child(status)
	_new_animation()


func _new_animation() -> void:
	animation = Animation.new()
	animation.length = DEFAULT_LENGTH
	animation.step = 0.1
	animation_path = ""
	duration.value = DEFAULT_LENGTH
	time_slider.max_value = DEFAULT_LENGTH
	track_picker.clear()
	key_list.clear()
	_redraw_timeline()
	_set_status("New animation. Add a track for the selected node's property.")


func _add_track() -> void:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.is_empty():
		_set_status("Select a node in the Scene tree first.")
		return
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or not root.is_ancestor_of(selected[0]):
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
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Godot Resource")
	dialog.file_selected.connect(func(path: String):
		animation_path = path
		_save_animation()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	page.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 500))


func _open_animation() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Godot Resource")
	dialog.file_selected.connect(func(path: String):
		var loaded := ResourceLoader.load(path) as Animation
		if loaded:
			animation = loaded
			animation_path = path
			duration.value = animation.length
			time_slider.max_value = animation.length
			_refresh_tracks()
			_set_status("Opened %s" % path.get_file())
		else:
			_set_status("That resource is not a Godot Animation.")
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
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
	playing = not playing
	playback_time = time_slider.value
	_set_status("Preview playing." if playing else "Preview paused.")


func _draw_timeline() -> void:
	if animation == null:
		return
	var rect := timeline.get_rect()
	var width := timeline.size.x
	var height := timeline.size.y
	timeline.draw_rect(Rect2(Vector2.ZERO, Vector2(width, height)), Color("20242c"), true)
	var length := maxf(animation.length, 0.01)
	for tick in range(11):
		var x := width * tick / 10.0
		timeline.draw_line(Vector2(x, 0), Vector2(x, height), Color("424954"), 1.0)
		timeline.draw_string(ThemeDB.fallback_font, Vector2(x + 3, 14), "%.1f" % (length * tick / 10.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c4cad4"))
	var track := track_picker.selected
	if track >= 0 and track < animation.get_track_count():
		for key in animation.track_get_key_count(track):
			var x := width * animation.track_get_key_time(track, key) / length
			timeline.draw_circle(Vector2(x, height * 0.55), 6.0, Color("f5bb53"))
	var playhead_x := width * time_slider.value / length
	timeline.draw_line(Vector2(playhead_x, 0), Vector2(playhead_x, height), Color("f56c70"), 2.0)


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
	var components := vector_match[2].split(",", false)
	if components.size() != int(vector_match[1]):
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
	button.pressed.connect(action)
	parent.add_child(button)


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
