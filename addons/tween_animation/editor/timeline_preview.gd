@tool
extends VBoxContainer
## Uses the real timeline controls with a private Animation and sample values.
## No scene-tree selection, project resource saving or scene properties are changed.

signal target_selection_changed(is_selected: bool)

var controls
var clip: Animation
var scene_tree: Tree
var scene_item: TreeItem
var property_values: Array[SpinBox] = []
var feedback: Label
var callout: Label
var play_button: Button
var save_button: Button
var sample_stage: Control
var toolbar: HFlowContainer
var inspector_title: Label
var sidebar: VBoxContainer
var mode := 0
var phase := 0
var selected := false
var playing := false
var _highlights: Array[Control] = []


func build() -> void:
	add_theme_constant_override("separation", 10)
	add_child(_text("PRACTICE · Try it here before using your own scene", 14))
	callout = _text("", 17)
	add_child(callout)
	toolbar = HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 8)
	add_child(toolbar)
	var reset := Button.new()
	reset.text = "Reset practice"
	reset.pressed.connect(func(): configure(mode, phase))
	toolbar.add_child(reset)
	play_button = Button.new()
	play_button.text = "Play preview"
	play_button.pressed.connect(_toggle_play)
	toolbar.add_child(play_button)
	var rewind := Button.new()
	rewind.text = "Rewind"
	rewind.pressed.connect(func():
		playing = false
		play_button.text = "Play preview"
		_seek(0.0)
	)
	toolbar.add_child(rewind)
	save_button = Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(func(): feedback.text = "Practice clip ready. In the real Timeline, Save opens a file dialog for your .tres resource. This preview writes no files.")
	toolbar.add_child(save_button)
	sample_stage = Control.new()
	sample_stage.custom_minimum_size.y = 110
	sample_stage.draw.connect(_draw_sample)
	add_child(sample_stage)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	sidebar = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 150
	body.add_child(sidebar)
	sidebar.add_child(_text("TUTORIAL SCENE · choose an animation target", 12))
	scene_tree = Tree.new()
	scene_tree.custom_minimum_size.y = 92
	scene_tree.item_selected.connect(_select_target)
	sidebar.add_child(scene_tree)
	inspector_title = _text("SAMPLE INSPECTOR", 12)
	sidebar.add_child(inspector_title)
	for index in range(3):
		var spinner := SpinBox.new()
		spinner.min_value = -10000
		spinner.max_value = 10000
		spinner.step = 0.1
		spinner.prefix = ["X", "Y", "Z"][index]
		spinner.value_changed.connect(func(_value: float): sample_stage.queue_redraw())
		property_values.append(spinner)
		sidebar.add_child(spinner)
	controls = preload("res://addons/tween_animation/editor/timeline_controls.gd").new()
	controls.build()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(controls)
	controls.add_track_requested.connect(_add_track)
	controls.capture_key_requested.connect(_capture)
	controls.time_changed.connect(_seek)
	controls.draw_requested.connect(func(): controls.paint(clip))
	controls.timeline_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_seek(clampf(event.position.x / maxf(controls.timeline.size.x, 1.0), 0.0, 1.0))
	)
	controls.track_selected.connect(func(_index: int): _refresh_keys())
	controls.key_selected.connect(func(index: int): _seek(clip.track_get_key_time(controls.track_picker.selected, index)))
	feedback = _text("Use the highlighted controls here, then try the same steps in the Timeline tab.", 14)
	add_child(feedback)


func configure(target_mode: int, step: int) -> void:
	mode = target_mode
	phase = clampi(step, 0, 5)
	toolbar.visible = phase > 0
	sample_stage.visible = phase > 0
	controls.visible = phase > 0
	inspector_title.visible = phase > 0
	sidebar.custom_minimum_size.x = 280 if phase == 0 else 180
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phase == 0 else Control.SIZE_FILL
	playing = false
	play_button.text = "Play preview"
	for control in _highlights:
		control.remove_theme_stylebox_override("normal")
	_highlights.clear()
	clip = Animation.new()
	clip.length = 1.0
	scene_tree.clear()
	var root := scene_tree.create_item()
	root.set_text(0, "PreviewScene")
	root.set_selectable(0, false)
	scene_item = scene_tree.create_item(root)
	scene_item.set_text(0, ["Sprite2D", "MeshInstance3D", "Panel"][mode])
	scene_item.set_tooltip_text(0, "Click this row to choose the object we will animate.")
	scene_item.set_icon(0, EditorInterface.get_base_control().get_theme_icon(["Node2D", "Node3D", "Control"][mode], "EditorIcons"))
	selected = phase > 0
	if selected:
		scene_item.select(0)
	controls.track_picker.clear()
	controls.track_picker.add_item("No tracks yet")
	controls.track_picker.set_item_disabled(0, true)
	controls.track_picker.select(-1)
	controls.property_path.text = "modulate:a" if mode == 2 else "position"
	controls.value_input.clear()
	controls.key_list.clear()
	for index in range(3):
		property_values[index].visible = phase > 0 and (index == 0 or (mode != 2 and (index == 1 or mode == 1)))
		property_values[index].prefix = "Alpha" if mode == 2 else ["X", "Y", "Z"][index]
		property_values[index].set_value_no_signal(0.0)
	if phase >= 2:
		_add_track()
	if phase >= 3:
		clip.track_insert_key(0, 0.0, _pose())
		property_values[0].set_value_no_signal(1.0 if mode == 2 else (2.0 if mode == 1 else 100.0))
	if phase >= 4:
		clip.track_insert_key(0, 1.0, _pose())
	_seek(1.0 if phase == 3 else 0.0)
	_refresh_keys()
	var messages := ["1 · Click the target under PreviewScene.", "2 · Property goes here → then Add track.", "3 · Start at 0 seconds → Capture key.", "4 · Playhead at 1 second → change the sample Inspector → Capture key.", "5 · Press Play preview. Rewind returns to the beginning.", "6 · Save in the real Timeline creates an Animation resource."]
	callout.text = messages[phase]
	if phase == 0:
		callout.text = "↓ Select %s as the target for a new track." % scene_item.get_text(0)
	match phase:
		0: _highlight(scene_tree)
		1:
			_highlight(controls.property_path)
			_highlight(controls.add_track_button)
		2: _highlight(controls.capture_key_button)
		3:
			_highlight(property_values[0].get_line_edit())
			_highlight(controls.capture_key_button)
		4: _highlight(play_button)
		5: _highlight(save_button)
	feedback.text = "Practice only: controls edit this sample clip, not your scene. Use Timeline in the top bar for your project."
	if phase == 0:
		feedback.text = "No animation target selected. Add track needs a node so it knows which object's property to animate."
		target_selection_changed.emit(false)


func _select_target() -> void:
	selected = scene_tree.get_selected() == scene_item
	if selected:
		if phase == 0:
			callout.text = "Animation target: %s" % scene_item.get_text(0)
			feedback.text = "New tracks will target this tutorial node. In your project, choose the target in Godot's Scene tree before using Add track."
		else:
			feedback.text = "Target selected. Enter the property and choose Add track."
	target_selection_changed.emit(selected)


func _add_track() -> void:
	if not selected:
		feedback.text = "Select the target in the practice Scene tree first."
		return
	if controls.property_path.text != ("modulate:a" if mode == 2 else "position"):
		feedback.text = "This exercise uses " + ("modulate:a" if mode == 2 else "position") + ". The real timeline supports other properties too."
		return
	if clip.get_track_count() == 0:
		clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(0, NodePath(scene_item.get_text(0) + ":" + controls.property_path.text))
	controls.track_picker.clear()
	controls.track_picker.add_item(str(clip.track_get_path(0)))
	controls.track_picker.select(0)
	feedback.text = "Track added. Choose a time, set the sample Inspector value, then Capture key."
	controls.timeline.queue_redraw()


func _pose() -> Variant:
	if mode == 2:
		return clampf(property_values[0].value, 0.0, 1.0)
	return Vector3(property_values[0].value, property_values[1].value, property_values[2].value) if mode == 1 else Vector2(property_values[0].value, property_values[1].value)


func _capture() -> void:
	if clip.get_track_count() == 0:
		feedback.text = "Add a track first."
		return
	var value: Variant = _pose()
	var entered: String = controls.value_input.text.strip_edges()
	if not entered.is_empty():
		value = entered.to_float() if entered.is_valid_float() else str_to_var(entered)
		if not ((mode == 2 and (value is float or value is int)) or (mode == 1 and value is Vector3) or (mode == 0 and value is Vector2)):
			feedback.text = "Use a number for UI alpha, Vector2 for 2D, or Vector3 for 3D; leave empty to capture the sample Inspector."
			return
	clip.track_insert_key(0, controls.time_slider.value, value)
	_refresh_keys()
	feedback.text = "Captured key at %.2f s. Scrub or play to sample it." % controls.time_slider.value


func _refresh_keys() -> void:
	controls.key_list.clear()
	sample_stage.queue_redraw()
	if clip.get_track_count() > 0:
		for index in clip.track_get_key_count(0):
			controls.key_list.add_item("%.2f s · %s" % [clip.track_get_key_time(0, index), clip.track_get_key_value(0, index)])
	controls.timeline.queue_redraw()


func _seek(value: float) -> void:
	controls.time_slider.set_value_no_signal(value)
	controls.time_label.text = "%.2f s" % value
	controls.timeline.queue_redraw()
	sample_stage.queue_redraw()
	if clip.get_track_count() > 0 and clip.track_get_key_count(0) > 0:
		feedback.text = "Sample at %.2f s: %s" % [value, clip.value_track_interpolate(0, value)]


func _toggle_play() -> void:
	if clip.get_track_count() == 0 or clip.track_get_key_count(0) < 2:
		feedback.text = "Capture two keys at different times before previewing."
		return
	playing = not playing
	play_button.text = "Pause preview" if playing else "Play preview"


func _process(delta: float) -> void:
	if playing and is_visible_in_tree():
		var next_time: float = fmod(controls.time_slider.value + delta, 1.0)
		_seek(next_time)


func _draw_sample() -> void:
	if clip == null:
		return
	var value: Variant = _pose()
	if clip.get_track_count() > 0 and clip.track_get_key_count(0) > 0:
		value = clip.value_track_interpolate(0, controls.time_slider.value)
	var center := Vector2(sample_stage.size.x * 0.4, 48)
	var accent := EditorInterface.get_base_control().get_theme_color("accent_color", "Editor")
	var foreground := get_theme_color("font_color", "Label")
	if mode == 2:
		accent.a = clampf(float(value), 0.0, 1.0)
		sample_stage.draw_rect(Rect2(center - Vector2(50, 22), Vector2(100, 44)), accent)
	else:
		var offset: Vector2 = Vector2(value.x, -value.y) * 35.0 if mode == 1 else value
		if mode == 1:
			offset += Vector2(-value.z, value.z) * 18.0
		center += offset.limit_length(minf(180, sample_stage.size.x * 0.3))
		if mode == 1:
			sample_stage.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -22), center + Vector2(22, -10), center + Vector2(0, 2), center + Vector2(-22, -10)]), accent.lightened(0.2))
			sample_stage.draw_colored_polygon(PackedVector2Array([center + Vector2(-22, -10), center + Vector2(0, 2), center + Vector2(0, 25), center + Vector2(-22, 13)]), accent.darkened(0.25))
			sample_stage.draw_colored_polygon(PackedVector2Array([center + Vector2(0, 2), center + Vector2(22, -10), center + Vector2(22, 13), center + Vector2(0, 25)]), accent)
		else:
			sample_stage.draw_rect(Rect2(center - Vector2(16, 16), Vector2(32, 32)), accent)
	sample_stage.draw_string(get_theme_font("font", "Label"), Vector2(12, 103), "SAMPLE · %s = %s" % [controls.property_path.text, value], HORIZONTAL_ALIGNMENT_LEFT, sample_stage.size.x - 24, 13, foreground)


func _highlight(control: Control) -> void:
	var style := control.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = EditorInterface.get_base_control().get_theme_color("dark_color_1", "Editor")
	style.border_color = EditorInterface.get_base_control().get_theme_color("accent_color", "Editor")
	style.set_border_width_all(2)
	control.add_theme_stylebox_override("normal", style)
	_highlights.append(control)


func _text(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label
