@tool
extends VBoxContainer
## Uses the real timeline controls with a private Animation and sample values.
## No scene-tree selection, project resource saving or scene properties are changed.

signal target_selection_changed(is_selected: bool)

var controls
var clip: Animation
var scene_tree: Tree
var scene_item: TreeItem
var feedback: Label
var callout: Label
var play_button: Button
var save_button: Button
var sample_stage: Control
var toolbar: HFlowContainer
var sidebar: VBoxContainer
var scene_title: Label
var reset_button: Button
var rewind_button: Button
var sample_host: Node
var sample_target: Node
var interval_row: HBoxContainer
var interval_input: SpinBox
var mode := 0
var phase := 0
var selected := false
var playing := false
var _highlights: Array[Dictionary] = []


func build() -> void:
	sample_host = Node.new()
	add_child(sample_host)
	add_theme_constant_override("separation", 10)
	add_child(_text("PRACTICE · Try it here before using your own scene", 14))
	callout = _text("", 17)
	add_child(callout)
	toolbar = HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 8)
	add_child(toolbar)
	var reset := Button.new()
	reset_button = reset
	reset.text = "Reset practice"
	reset.pressed.connect(func(): configure(mode, phase))
	toolbar.add_child(reset)
	play_button = Button.new()
	play_button.text = "Play preview"
	play_button.pressed.connect(_toggle_play)
	toolbar.add_child(play_button)
	var rewind := Button.new()
	rewind_button = rewind
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
	interval_row = HBoxContainer.new()
	interval_row.add_theme_constant_override("separation", 8)
	var interval_label := _text("After-effect interval", 0)
	interval_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	interval_row.add_child(interval_label)
	interval_input = SpinBox.new()
	interval_input.custom_minimum_size.x = 90
	interval_input.min_value = 0.0
	interval_input.max_value = 10.0
	interval_input.step = 0.1
	interval_input.suffix = "s"
	interval_input.tooltip_text = "Optional wait after the 1-second sample effect. Zero adds no wait; a positive value holds the final pose."
	interval_input.value_changed.connect(_set_interval)
	interval_row.add_child(interval_input)
	toolbar.add_child(interval_row)
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
	scene_title = _text("TUTORIAL SCENE · choose an animation target", 12)
	sidebar.add_child(scene_title)
	scene_tree = Tree.new()
	scene_tree.custom_minimum_size.y = 92
	scene_tree.item_selected.connect(_select_target)
	sidebar.add_child(scene_tree)
	controls = preload("res://addons/tween_animation/editor/timeline_controls.gd").new()
	controls.build()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(controls)
	controls.add_track_requested.connect(_add_track)
	controls.capture_key_requested.connect(_capture)
	controls.override_changed.connect(_override_changed)
	controls.time_changed.connect(_seek)
	controls.draw_requested.connect(func(): controls.paint(clip))
	controls.track_selected.connect(func(_index: int): _refresh_keys())
	controls.key_selected.connect(func(index: int): _seek(clip.track_get_key_time(controls.track_picker.selected, index)))
	feedback = _text("Use the highlighted controls here, then try the same steps in the Timeline tab.", 14)
	add_child(feedback)


func configure(target_mode: int, step: int) -> void:
	mode = target_mode
	phase = clampi(step, 0, 5)
	toolbar.visible = phase in [4, 5]
	reset_button.visible = phase == 4
	play_button.visible = phase == 4
	rewind_button.visible = phase == 4
	save_button.visible = phase == 5
	interval_row.visible = phase == 4
	interval_input.set_value_no_signal(0.0)
	sample_stage.visible = phase == 4
	controls.visible = phase in [1, 2, 3, 4]
	controls.focus_lesson(phase)
	sidebar.visible = phase == 0
	scene_title.visible = phase == 0
	scene_tree.visible = phase == 0
	sidebar.custom_minimum_size.x = 280 if phase == 0 else 180
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL if phase == 0 else Control.SIZE_FILL
	playing = false
	play_button.text = "Play preview"
	_clear_attention()
	if is_instance_valid(sample_target):
		sample_target.free()
	sample_target = Node3D.new() if mode == 1 else (Control.new() if mode == 2 else Node2D.new())
	sample_target.name = ["Sprite2D", "MeshInstance3D", "Panel"][mode]
	sample_host.add_child(sample_target)
	if mode == 2:
		sample_target.set_indexed(^"modulate:a", 0.0)
	controls.set_target(sample_target)
	controls.target_label.text = "Tutorial track target: %s · %s" % [sample_target.name, "modulate:a" if mode == 2 else "position"]
	clip = Animation.new()
	clip.length = 1.0
	controls.time_slider.max_value = 1.0
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
	if phase >= 2:
		_add_track()
	if phase >= 3:
		clip.track_insert_key(0, 0.0, _pose())
	if phase >= 4:
		clip.track_insert_key(0, 1.0, 1.0 if mode == 2 else (Vector3(2, 0, 0) if mode == 1 else Vector2(100, 0)))
	_seek(0.0)
	_refresh_keys()
	var messages := ["Choose an animation target.", "Press + Track, choose a property in the picker, then Add track.", "The playhead is at 0 seconds. Press the outlined Capture key button to record the starting value.", "1 · Drag the outlined timeline playhead to the right edge at 1 second.", "Press the outlined Play preview button to watch the sample.", "Press the outlined Save button to learn what is saved."]
	callout.text = messages[phase]
	if phase == 0:
		callout.text = "↓ Select %s as the target for a new track." % scene_item.get_text(0)
	_clear_attention()
	match phase:
		0: _highlight(scene_tree)
		1:
			_highlight(controls.new_track_button)
		2: _highlight(controls.capture_key_button)
		3:
			_highlight(controls.timeline)
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
	feedback.text = "Track added. Choose a time, edit the Override fields, then Capture."
	if phase == 1:
		_clear_attention()
		callout.text = "Track created for %s. Next, record its starting value." % scene_item.get_text(0)
		feedback.text = "The track binds this node to this property. Continue to Save the opening pose to capture its first key."
	controls.timeline.queue_redraw()
	_update_key_value()


func _pose() -> Variant:
	return sample_target.get_indexed(^"modulate:a" if mode == 2 else ^"position")


func _capture() -> void:
	if clip.get_track_count() == 0:
		feedback.text = "Add a track first."
		return
	if phase == 3 and not is_equal_approx(controls.time_slider.value, 1.0):
		feedback.text = "Drag the playhead to 1.00 s first. The opening key is already at 0.00 s."
		return
	_update_key_value()
	var result: Dictionary = controls.capture_value()
	if not result.ok:
		feedback.text = str(result.error)
		return
	clip.track_insert_key(0, controls.time_slider.value, result.value)
	_refresh_keys()
	feedback.text = "Captured key at %.2f s. Scrub or play to sample it." % controls.time_slider.value
	if phase in [2, 3]:
		_clear_attention()
		callout.text = "Starting pose recorded. Continue to choose the destination." if phase == 2 else "Destination recorded. Continue to watch the animation."


func _refresh_keys() -> void:
	controls.key_list.clear()
	sample_stage.queue_redraw()
	if clip.get_track_count() > 0:
		for index in clip.track_get_key_count(0):
			controls.key_list.add_item("%.3f s · %s" % [clip.track_get_key_time(0, index), var_to_str(clip.track_get_key_value(0, index))])
	controls.timeline.queue_redraw()
	_update_key_value()


func _seek(value: float) -> void:
	controls.time_slider.set_value_no_signal(value)
	controls.time_label.text = "%.2f s" % value
	controls.timeline.queue_redraw()
	sample_stage.queue_redraw()
	if phase == 3:
		_clear_attention()
		if is_equal_approx(value, 1.0):
			callout.text = "2 · Choose Override to unlock the value fields."
			_highlight(controls.mode_switch)
		else:
			callout.text = "1 · Drag the outlined timeline playhead to the right edge at 1 second."
			_highlight(controls.timeline)
	if clip.get_track_count() > 0 and clip.track_get_key_count(0) > 0:
		feedback.text = "Sample at %.2f s: %s" % [value, clip.value_track_interpolate(0, value)]
	_update_key_value()


func _update_key_value() -> void:
	if clip == null:
		return
	if clip.get_track_count() == 0:
		controls.set_value_context("", null)
		return
	var current: Variant = _pose()
	if phase == 4 and clip.track_get_key_count(0) > 0:
		current = clip.value_track_interpolate(0, controls.time_slider.value)
	var saved: Variant = null
	var has_key := false
	for key in clip.track_get_key_count(0):
		if is_equal_approx(clip.track_get_key_time(0, key), controls.time_slider.value):
			saved = clip.track_get_key_value(0, key)
			has_key = true
			break
	controls.set_value_context(str(clip.track_get_path(0)), current, {}, saved, has_key, controls.time_slider.value, "Preview value" if phase == 4 else "Tutorial node value")


func _override_changed() -> void:
	if phase == 3 and is_equal_approx(controls.time_slider.value, 1.0):
		_clear_attention()
		if not controls._override_requested:
			callout.text = "2 · Choose Override to unlock the value fields."
			_highlight(controls.mode_switch)
		elif controls.capture_value().value == _pose():
			callout.text = "3 · Change %s to %s in the outlined fields." % ["value" if mode == 2 else "X", "1" if mode == 2 else ("2" if mode == 1 else "100")]
			_highlight(controls.value_readout)
		elif controls.capture_value().ok:
			callout.text = "4 · Capture saves these fields as the destination key."
			_highlight(controls.capture_key_button)
		else:
			callout.text = "Enter a valid value in the outlined fields."
			_highlight(controls.value_readout)


func _toggle_play() -> void:
	if clip.get_track_count() == 0 or clip.track_get_key_count(0) < 2:
		feedback.text = "Capture two keys at different times before previewing."
		return
	playing = not playing
	play_button.text = "Pause preview" if playing else "Play preview"


func _set_interval(seconds: float) -> void:
	if phase != 4 or clip == null or clip.get_track_count() == 0:
		return
	while clip.track_get_key_count(0) > 2:
		clip.track_remove_key(0, clip.track_get_key_count(0) - 1)
	clip.length = 1.0 + seconds
	if seconds > 0.0:
		clip.track_insert_key(0, clip.length, clip.track_get_key_value(0, 1))
	controls.time_slider.max_value = clip.length
	_refresh_keys()
	feedback.text = "Effect: 1.0 s · interval: %.1f s · total: %.1f s. The extra key holds the final pose; the next loop starts after the wait." % [seconds, clip.length]


func _process(delta: float) -> void:
	if playing and is_visible_in_tree():
		var next_time: float = fmod(controls.time_slider.value + delta, clip.length)
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
	var draw_border := func():
		var accent := EditorInterface.get_base_control().get_theme_color("accent_color", "Editor")
		var frame := Rect2(Vector2(-4, -4), control.size + Vector2(8, 8))
		control.draw_rect(frame, Color(accent, 0.08), true)
		# Draw outside child buttons so their normal backgrounds cannot cover the border.
		control.draw_rect(frame, accent, false, 3.0)
	control.draw.connect(draw_border)
	_highlights.append({"control": control, "draw": draw_border})
	control.queue_redraw()


func _clear_attention() -> void:
	for highlight in _highlights:
		var control: Control = highlight.control
		if is_instance_valid(control):
			control.draw.disconnect(highlight.draw)
			control.queue_redraw()
	_highlights.clear()


func _text(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label
