@tool
extends EditorPlugin

const ADDON_ICON := preload("res://addons/tween_animation/icon.svg")
const HEADER_LOGO := preload("res://addons/tween_animation/header_logo.svg")
const SETUP_SCREEN := preload("res://addons/tween_animation/editor/setup.gd")
const DOCUMENTATION_SCREEN := preload("res://addons/tween_animation/editor/documentation.gd")
const DEFAULT_LENGTH := 1.0

var code_timeline
var workspace_picker: TabBar
var page: VBoxContainer
var frame: MarginContainer
var tabs: TabContainer
var setup_mode := ""
var content_mode := 0
var content_mode_buttons: Array[Button] = []
var navigation_buttons: Array[Button] = []
var navigation_row: HBoxContainer
var animation: Animation
var animation_path := ""
var duration: SpinBox
var time_slider: HSlider
var time_label: Label
var property_path: LineEdit
var value_input: LineEdit
var track_picker: OptionButton
var timeline: Control
var timeline_controls
var key_list: ItemList
var status: Label
var play_button: Button
var playing := false
var playback_time := 0.0
var value_refresh_elapsed := 0.0


func _enter_tree() -> void:
	_build_ui()
	get_editor_interface().get_editor_main_screen().add_child(frame)
	set_process(true)
	_make_visible(false)
	get_editor_interface().get_selection().selection_changed.connect(_selection_changed)
	_selection_changed()


func _exit_tree() -> void:
	var selection := get_editor_interface().get_selection()
	if selection.selection_changed.is_connected(_selection_changed):
		selection.selection_changed.disconnect(_selection_changed)
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
		if visible and is_instance_valid(timeline_controls):
			_selection_changed()


func _process(delta: float) -> void:
	value_refresh_elapsed += delta
	if is_instance_valid(frame) and frame.visible and value_refresh_elapsed >= 0.15:
		value_refresh_elapsed = 0.0
		_refresh_value_context()
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
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 0)
	frame.add_child(layout)
	_build_navigation_bar(layout)
	tabs = TabContainer.new()
	tabs.tabs_visible = false
	tabs.tab_changed.connect(_sync_navigation_buttons)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	var setup := SETUP_SCREEN.new()
	setup.build(HEADER_LOGO)
	setup.start_requested.connect(_start_setup)
	setup.code_start_requested.connect(func(): tabs.current_tab = 1; _set_workspace(0))
	setup.open_requested.connect(func():
		tabs.current_tab = 1
		_set_workspace(1)
		_open_animation()
	)
	tabs.add_child(setup)
	var timeline_scroll := ScrollContainer.new()
	timeline_scroll.name = "Timeline"
	timeline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(timeline_scroll)
	var documentation := DOCUMENTATION_SCREEN.new()
	documentation.build()
	tabs.add_child(documentation)
	tabs.set_tab_icon(0, _editor_icon("Node"))
	tabs.set_tab_icon(1, ADDON_ICON)
	tabs.set_tab_icon(2, _editor_icon("Help"))
	var workspace := VBoxContainer.new()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_scroll.add_child(workspace)
	workspace_picker = TabBar.new()
	workspace_picker.add_tab("Code Tweens", _editor_icon("Script"))
	workspace_picker.add_tab("Animation clips", _editor_icon("Animation"))
	workspace.add_child(workspace_picker)
	code_timeline = preload("res://addons/tween_animation/editor/code_timeline.gd").new()
	code_timeline.build(self)
	workspace.add_child(code_timeline)
	workspace_picker.tab_changed.connect(_set_workspace)
	page = VBoxContainer.new()
	page.name = "Timeline"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_child(page)
	page.hide()
	page.add_theme_constant_override("separation", 12)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	_add_card(header)
	var logo := TextureRect.new()
	logo.texture = HEADER_LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(96, 32)
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

	timeline_controls = preload("res://addons/tween_animation/editor/timeline_controls.gd").new()
	timeline_controls.build()
	_add_card(timeline_controls)
	track_picker = timeline_controls.track_picker
	property_path = timeline_controls.property_path
	value_input = timeline_controls.value_input
	time_label = timeline_controls.time_label
	time_slider = timeline_controls.time_slider
	timeline = timeline_controls.timeline
	key_list = timeline_controls.key_list
	timeline_controls.add_track_requested.connect(_add_track)
	timeline_controls.capture_key_requested.connect(_capture_key)
	timeline_controls.track_selected.connect(_select_track)
	timeline_controls.time_changed.connect(_on_time_changed)
	timeline_controls.key_selected.connect(_select_key)
	timeline_controls.draw_requested.connect(_draw_timeline)
	timeline_controls.action_requested.connect(_action_template)
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
	tabs.current_tab = 0
	_set_content_mode(content_mode)
	_sync_navigation_buttons(tabs.current_tab)


func _start_setup(mode: String) -> void:
	_set_workspace(1)
	setup_mode = mode
	property_path.text = "modulate:a" if mode == "UI" else "position"
	value_input.clear()
	tabs.current_tab = 1
	_set_status("%s setup: select a %s node, then Add track. Existing tracks are preserved." % [mode, "Control" if mode == "UI" else "Node" + mode])


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
	var target := _track_target()
	var root := get_editor_interface().get_edited_scene_root()
	if target == null or root == null:
		_set_status("Select a scene node or an existing track first.")
		return
	var property_name := property_path.text.strip_edges()
	if property_name.is_empty() or not _has_property(target, property_name):
		_set_status("Enter a valid property name for the selected node.")
		return
	var track := animation.add_track(Animation.TYPE_VALUE)
	var node_path := root.get_path_to(target)
	animation.track_set_path(track, NodePath(str(node_path) + ":" + property_name))
	if typeof(target.get_indexed(NodePath(property_name))) in [TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME]:
		animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	_refresh_tracks(track)
	_set_status("Track added: %s:%s" % [node_path, property_name])


func _track_target() -> Node:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return null
	for target in get_editor_interface().get_selection().get_selected_nodes():
		if target == root or root.is_ancestor_of(target):
			return target
	var index := track_picker.selected
	if animation != null and index >= 0 and index < animation.get_track_count():
		return root.get_node_or_null(NodePath(animation.track_get_path(index).get_concatenated_names()))
	return null


func _selection_changed() -> void:
	timeline_controls.set_target(_track_target())
	if is_instance_valid(code_timeline):
		var nodes := get_editor_interface().get_selection().get_selected_nodes()
		code_timeline.set_node(nodes[0] if not nodes.is_empty() else null)


func _action_template(action: String) -> void:
	var target := _track_target()
	if target == null:
		_set_status("Select a scene node or an existing track first.")
		return
	var options := preload("res://addons/tween_animation/editor/timeline_options.gd")
	if not action in options.actions(target):
		_set_status("That template is not available for the selected node.")
		return
	var spec := options.describe(target, action)
	var dialog := ConfirmationDialog.new()
	dialog.title = "%s() · %s" % [action, target.name]
	dialog.min_size = Vector2i(520, 260)
	dialog.dialog_hide_on_ok = false
	dialog.get_ok_button().text = "Create track and keys"
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	dialog.add_child(body)
	var description := _label("Create editable %s keys from this node's current value. Start at the playhead; existing tracks are preserved." % spec.property, 0)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Wrapped labels need a width before the dialog measures its minimum height.
	description.custom_minimum_size.x = 480
	body.add_child(description)
	body.add_child(_label(str(spec.label), 0))
	var parameter := LineEdit.new()
	parameter.text = var_to_str(spec.value)
	body.add_child(parameter)
	body.add_child(_label("Duration · seconds", 0))
	var seconds := SpinBox.new()
	seconds.min_value = 0.01
	seconds.max_value = 3600
	seconds.step = 0.01
	seconds.value = maxf(animation.length - time_slider.value, 0.3)
	body.add_child(seconds)
	body.add_child(_label("After-effect interval · seconds (optional)", 0))
	var interval := SpinBox.new()
	interval.min_value = 0.0
	interval.max_value = 3600
	interval.step = 0.01
	body.add_child(interval)
	var hint := _label("Interval adds a hold at the final value after the effect. Templates use linear interpolation; runtime easing and automatic Control pivot changes are not applied.", 0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 480
	body.add_child(hint)
	dialog.confirmed.connect(func():
		if _commit_template(target, action, _parse_value(parameter.text.strip_edges()), seconds.value, interval.value):
			dialog.queue_free()
		else:
			hint.text = "Check the value type and selected scene. Use a number, Vector2(x, y), or Vector3(x, y, z) as appropriate."
	)
	dialog.canceled.connect(dialog.queue_free)
	page.add_child(dialog)
	dialog.popup_centered()


func _commit_template(target: Node, action: String, value: Variant, seconds: float, interval: float = 0.0) -> bool:
	var root := get_editor_interface().get_edited_scene_root()
	if not is_instance_valid(target) or root == null or (root != target and not root.is_ancestor_of(target)):
		return false
	var options := preload("res://addons/tween_animation/editor/timeline_options.gd")
	if not action in options.actions(target) or seconds <= 0 or not is_finite(seconds) or interval < 0 or not is_finite(interval):
		return false
	var keys: Array = options.keys(target, action, value)
	if keys.is_empty():
		return false
	if interval > 0.0:
		keys.append([1.0 + interval / seconds, keys[-1][1]])
	var property: String = options.describe(target, action).property
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(str(root.get_path_to(target)) + ":" + property))
	var start_time := time_slider.value
	for key in keys:
		animation.track_insert_key(track, start_time + float(key[0]) * seconds, key[1])
	animation.length = maxf(animation.length, start_time + seconds + interval)
	duration.set_value_no_signal(animation.length)
	time_slider.max_value = animation.length
	property_path.text = property
	_refresh_tracks(track)
	_set_status("%s(): created %d editable keys for %s. No scene properties were changed." % [action, keys.size(), target.name])
	return true


func _capture_key() -> void:
	var track := track_picker.selected
	if track < 0 or track >= animation.get_track_count():
		_set_status("Add or select a track first.")
		return
	if animation.track_get_type(track) != Animation.TYPE_VALUE:
		_set_status("This imported track is not a property value track. Select or add a value track to capture keys.")
		return
	var root := get_editor_interface().get_edited_scene_root()
	var track_path := animation.track_get_path(track)
	var target := root.get_node_or_null(NodePath(track_path.get_concatenated_names())) if root else null
	if target == null:
		_set_status("The node for this track is not in the edited scene.")
		return
	_refresh_value_context()
	var result: Dictionary = timeline_controls.capture_value()
	if not result.ok:
		_set_status(str(result.error))
		return
	animation.track_insert_key(track, time_slider.value, result.value)
	_refresh_keys(track)
	_redraw_timeline()
	_set_status("Keyframe added at %.2fs." % time_slider.value)


func _refresh_value_context() -> void:
	var track := track_picker.selected
	var root := get_editor_interface().get_edited_scene_root()
	if animation == null or track < 0 or track >= animation.get_track_count() or root == null or animation.track_get_type(track) != Animation.TYPE_VALUE:
		timeline_controls.set_value_context("", null)
		return
	var path := animation.track_get_path(track)
	var target := root.get_node_or_null(NodePath(path.get_concatenated_names()))
	var property := str(path.get_concatenated_subnames())
	if target == null or not _has_property(target, property):
		timeline_controls.set_value_context(str(path), null)
		return
	var saved: Variant = null
	var has_key := false
	for key in animation.track_get_key_count(track):
		if is_equal_approx(animation.track_get_key_time(track, key), time_slider.value):
			saved = animation.track_get_key_value(track, key)
			has_key = true
			break
	var info := preload("res://addons/tween_animation/editor/key_values.gd").property_info(target, property)
	timeline_controls.set_value_context(str(path), target.get_indexed(NodePath(property)), info, saved, has_key, time_slider.value, "Current node value")


func _preview_tracks(at_time: float) -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return
	for index in animation.get_track_count():
		if animation.track_get_type(index) != Animation.TYPE_VALUE or animation.track_get_key_count(index) == 0:
			continue
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
			setup_mode = ""
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
		var path := animation.track_get_path(index)
		var text := str(path)
		var root := get_editor_interface().get_edited_scene_root()
		var target := root.get_node_or_null(NodePath(path.get_concatenated_names())) if root else null
		if path.get_concatenated_names() == "." and target:
			text = str(target.name) + ":" + str(path.get_concatenated_subnames())
		track_picker.add_icon_item(_editor_icon(target.get_class()) if target else null, text)
		track_picker.set_item_metadata(index, str(path))
		track_picker.set_item_tooltip(index, str(path))
	if animation.get_track_count() > 0:
		track_picker.select(clampi(select, 0, animation.get_track_count() - 1))
		_refresh_keys(track_picker.selected)
	else:
		track_picker.add_item("No tracks yet")
		track_picker.set_item_disabled(0, true)
		track_picker.select(-1)
		key_list.clear()
	_redraw_timeline()
	_refresh_value_context()

	_selection_changed()


func _refresh_keys(track: int) -> void:
	key_list.clear()
	if track < 0 or track >= animation.get_track_count():
		return
	for key in animation.track_get_key_count(track):
		var time := animation.track_get_key_time(track, key)
		var value := animation.track_get_key_value(track, key)
		key_list.add_item("%.3fs   %s" % [time, var_to_str(value)])
	_refresh_value_context()


func _select_track(index: int) -> void:
	_refresh_keys(index)
	_redraw_timeline()
	_selection_changed()


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
	_refresh_value_context()


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
	timeline_controls.paint(animation)


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
	var base_property := name.get_slice(":", 0)
	for item in target.get_property_list():
		if str(item.name) == base_property:
			return target.get_indexed(NodePath(name)) != null
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


func _set_workspace(index: int) -> void:
	workspace_picker.set_current_tab(index)
	page.visible = index == 1
	code_timeline.visible = index == 0
	if index == 0:
		playing = false
		play_button.text = "Play preview"


func _set_content_mode(index: int) -> void:
	content_mode = clampi(index, 0, 2)
	if is_instance_valid(code_timeline):
		code_timeline.set_content_mode(content_mode)
	for item in content_mode_buttons.size():
		content_mode_buttons[item].set_pressed_no_signal(item == content_mode)
	if tabs.get_tab_count() == 3:
		tabs.get_child(0).call("set_content_mode", content_mode)
		tabs.get_child(2).call("set_content_mode", content_mode)


func _build_navigation_bar(layout: VBoxContainer) -> void:
	var editor := get_editor_interface().get_base_control()
	var bar := PanelContainer.new()
	var background := StyleBoxFlat.new()
	background.bg_color = editor.get_theme_color("dark_color_1", "Editor")
	background.content_margin_left = 6
	background.content_margin_right = 6
	background.content_margin_top = 6
	background.content_margin_bottom = 6
	background.corner_radius_top_left = 6
	background.corner_radius_top_right = 6
	bar.add_theme_stylebox_override("panel", background)
	layout.add_child(bar)
	navigation_row = HBoxContainer.new()
	navigation_row.add_theme_constant_override("separation", 12)
	bar.add_child(navigation_row)
	var pages := HBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.alignment = BoxContainer.ALIGNMENT_CENTER
	pages.add_theme_constant_override("separation", 2)
	navigation_row.add_child(pages)
	var page_group := ButtonGroup.new()
	navigation_buttons.clear()
	for index in range(3):
		var button := Button.new()
		button.text = ["Setup", "Timeline", "Documentation"][index]
		button.icon = [_editor_icon("Node"), ADDON_ICON, _editor_icon("Help")][index]
		button.toggle_mode = true
		button.button_group = page_group
		button.pressed.connect(_select_page.bind(index))
		_style_bar_button(button, index, false)
		navigation_buttons.append(button)
		pages.add_child(button)
	navigation_row.add_child(VSeparator.new())
	var segments := HBoxContainer.new()
	segments.add_theme_constant_override("separation", 0)
	navigation_row.add_child(segments)
	var mode_group := ButtonGroup.new()
	content_mode_buttons.clear()
	for index in range(3):
		var button := Button.new()
		button.text = ["GDScript", "C#", "Visual Timeline"][index]
		button.toggle_mode = true
		button.button_group = mode_group
		button.tooltip_text = "Show " + button.text + " content in Tutorials and Documentation"
		button.pressed.connect(_set_content_mode.bind(index))
		_style_bar_button(button, index, true)
		content_mode_buttons.append(button)
		segments.add_child(button)


func _style_bar_button(button: Button, index: int, segmented: bool) -> void:
	var editor := get_editor_interface().get_base_control()
	var accent := editor.get_theme_color("accent_color", "Editor")
	var base := editor.get_theme_color("dark_color_2", "Editor")
	var normal := StyleBoxFlat.new()
	normal.bg_color = base if segmented else Color.TRANSPARENT
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	if segmented:
		normal.border_color = editor.get_theme_color("font_color", "Editor") * Color(1, 1, 1, 0.2)
		normal.set_border_width_all(1)
		normal.corner_radius_top_left = 5 if index == 0 else 0
		normal.corner_radius_bottom_left = 5 if index == 0 else 0
		normal.corner_radius_top_right = 5 if index == 2 else 0
		normal.corner_radius_bottom_right = 5 if index == 2 else 0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = base.lerp(accent, 0.2)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent if segmented else base
	pressed.border_color = accent
	pressed.border_width_bottom = 3
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = editor.get_theme_color("font_color", "Editor")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	var active_text := (Color.BLACK if accent.get_luminance() > 0.179 else Color.WHITE) if segmented else accent
	button.add_theme_color_override("font_pressed_color", active_text)
	button.add_theme_color_override("font_hover_pressed_color", active_text)
	button.add_theme_color_override("icon_pressed_color", active_text)
	button.add_theme_color_override("icon_hover_pressed_color", active_text)


func _select_page(index: int) -> void:
	tabs.current_tab = index
	_sync_navigation_buttons(index)


func _sync_navigation_buttons(index: int) -> void:
	for item in navigation_buttons.size():
		navigation_buttons[item].set_pressed_no_signal(item == index)
