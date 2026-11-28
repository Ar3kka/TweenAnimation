@tool
extends VBoxContainer
## A focused, isolated preview of the code-backed workflow; never edits project files.

var step := 0
var target_mode := 0
var selected := false
var target_button: Button
var stage: VBoxContainer
var readout: Label
var _accent := Color("92c6ee")


func build() -> void:
	add_theme_constant_override("separation", 12)
	var badge := Label.new()
	badge.text = "PRACTICE · SAMPLE DATA ONLY"
	badge.modulate = Color("92c6ee")
	add_child(badge)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = EditorInterface.get_base_control().get_theme_color("dark_color_2", "Editor")
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	stage = VBoxContainer.new()
	stage.add_theme_constant_override("separation", 12)
	panel.add_child(stage)


func configure(mode: int, phase: int) -> void:
	target_mode = mode
	step = phase
	_accent = [Color("8dc6ff"), Color("ffa7aa"), Color("9eddb7")][mode]
	for child in stage.get_children():
		stage.remove_child(child)
		child.queue_free()
	var names := ["Sprite2D", "MeshInstance3D", "Panel"]
	var icons := ["Node2D", "Node3D", "Control"]
	if step == 0:
		_journey("Scene", "Node", "Select target", icons[mode])
		target_button = Button.new()
		target_button.text = "  " + names[mode] + ("  ✓ selected" if selected else "  · click to select")
		target_button.icon = EditorInterface.get_base_control().get_theme_icon(icons[mode], "EditorIcons")
		target_button.toggle_mode = true
		target_button.set_pressed_no_signal(selected)
		target_button.pressed.connect(func(): selected = target_button.button_pressed; configure(mode, phase))
		target_button.custom_minimum_size.y = 46
		stage.add_child(target_button)
		_label("The real timeline follows Godot’s Scene selection. This practice target stands in for your scene node.")
	elif step == 1:
		_journey("Choose method", "Script", "Pick a gap", "MoveDown")
		var source := "extends Node\n\nfunc _on_button_pressed() -> void:\n    $Panel.show()\n    $ClickSound.play()\n"
		var syntax = preload("res://addons/tween_animation/editor/source_syntax.gd")
		var method: Dictionary = syntax.methods(source, "gd")[0]
		method.statements = syntax.statements(source, method)
		var anchors: Array[Dictionary] = []
		for statement in method.statements:
			anchors.append({"kind": "before", "start": statement.start, "label": "Before line " + str(statement.line)})
			anchors.append({"kind": "after", "start": statement.start, "label": "After line " + str(statement.line)})
		var placement = preload("res://addons/tween_animation/editor/placement_picker.gd").new()
		placement.build()
		placement.editor.custom_minimum_size.y = 150
		stage.add_child(placement)
		placement.configure(source, method, anchors, 2)
		_label("Try clicking a line, then Before or After. The highlight marks the gap; existing code moves down. This sample never changes your project.")

	elif step == 2:
		_journey("Current position", icons[mode], "Your offset", "MoveRight")
		var field = preload("res://addons/tween_animation/editor/source_value_field.gd").new()
		field.build("Destination / offset", "", Vector3(1, 0, 0) if mode == 1 else Vector2(100, 0), [{"name": "destination", "type": "Vector3" if mode == 1 else "Vector2"}], PackedStringArray(["position", "scale"]), true)
		stage.add_child(field)
		field.choose("relative")
		_label("Offset reads the current position each time the method runs. Value uses a fixed destination; Method parameter uses data supplied by your game.")
	elif step == 3:
		_journey("Move · 0.4 s", "Play", "Wait · 0.2 s", "Timer")
		for spec in [["Duration · seconds", 0.4], ["Wait afterwards · seconds", 0.2]]:
			var row := HBoxContainer.new()
			var label := Label.new()
			label.text = spec[0]
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var input := SpinBox.new()
			input.step = 0.05
			input.max_value = 60
			input.value = spec[1]
			row.add_child(input)
			stage.add_child(row)
		_picker("Sequence", ["Join earlier Tween · append a step", "Independent Tween · starts alongside others"])
		_label("Appending to a sequential Tween waits for earlier steps. Independent Tweens start together unless control flow awaits them.")
	elif step == 4:
		_journey("Select call", "Script", "Edit its values", "Edit")
		var call_item := Button.new()
		call_item.text = "move_right()   ━━━ 0.4 s ━━━   ░ wait 0.2 s"
		call_item.icon = EditorInterface.get_base_control().get_theme_icon("Script", "EditorIcons")
		call_item.custom_minimum_size.y = 48
		call_item.toggle_mode = true
		stage.add_child(call_item)
		readout = Label.new()
		readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		readout.text = "Click the sample call."
		stage.add_child(readout)
		call_item.pressed.connect(func(): readout.text = "move_right() · actor.gd · line 12\nPosition · offset X +100 · duration 0.4 s · wait 0.2 s\nIn the real workspace, edit these fields and Apply; Move this call changes its method location.")
	else:
		_journey("Tween call", "Script", "Editable timeline", "Call")
		_label("Add Tween inserts a native call at your chosen method location. Its timeline entry shows where and how long it runs; edit its supported parameters here or jump to its code. Undo restores the previous source.")
		_label("Runtime means the order or duration depends on live data, branches or loops. It is not an exact playback time. Source line is optional: visual editing does not require writing code.")
		_label("Tweenimation maps recognizable runtime Tween calls to editable timeline entries. Run your scene to see gameplay behavior; computed values and branches are marked Runtime.")


func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	stage.add_child(label)


func _picker(title: String, options: Array) -> void:
	_label(title)
	var picker := OptionButton.new()
	picker.fit_to_longest_item = false
	for option in options:
		picker.add_item(option)
	stage.add_child(picker)


func _journey(left: String, left_icon: String, right: String, right_icon: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for spec in [[left, left_icon], [right, right_icon]]:
		if row.get_child_count() > 0:
			var arrow := Label.new()
			arrow.text = "→"
			arrow.add_theme_font_size_override("font_size", 24)
			arrow.modulate = _accent
			row.add_child(arrow)
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color(_accent, 0.07)
		style.border_color = Color(_accent, 0.35)
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(12)
		tile.add_theme_stylebox_override("panel", style)
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 10)
		tile.add_child(content)
		var icon := TextureRect.new()
		icon.texture = EditorInterface.get_base_control().get_theme_icon(spec[1], "EditorIcons")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)
		icon.modulate = _accent
		content.add_child(icon)
		var label := Label.new()
		label.text = spec[0]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 17)
		content.add_child(label)
		row.add_child(tile)
	stage.add_child(row)
