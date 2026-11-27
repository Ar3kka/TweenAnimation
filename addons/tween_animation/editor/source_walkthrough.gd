@tool
extends VBoxContainer
## A focused, isolated preview of the code-backed workflow; never edits project files.

var step := 0
var target_mode := 0
var selected := false
var target_button: Button
var stage: VBoxContainer
var readout: Label


func build() -> void:
	add_theme_constant_override("separation", 12)
	var badge := Label.new()
	badge.text = "PRACTICE · SAMPLE DATA ONLY"
	badge.modulate = Color("92c6ee")
	add_child(badge)
	stage = VBoxContainer.new()
	stage.add_theme_constant_override("separation", 12)
	add_child(stage)


func configure(mode: int, phase: int) -> void:
	target_mode = mode
	step = phase
	for child in stage.get_children():
		stage.remove_child(child)
		child.queue_free()
	var names := ["Sprite2D", "MeshInstance3D", "Panel"]
	var icons := ["Node2D", "Node3D", "Control"]
	if step == 0:
		_label("SCENE  →  SELECT TARGET")
		target_button = Button.new()
		target_button.text = "  " + names[mode] + ("  ✓ selected" if selected else "  · click to select")
		target_button.icon = EditorInterface.get_base_control().get_theme_icon(icons[mode], "EditorIcons")
		target_button.toggle_mode = true
		target_button.set_pressed_no_signal(selected)
		target_button.pressed.connect(func(): selected = target_button.button_pressed; configure(mode, phase))
		stage.add_child(target_button)
		_label("The real timeline follows Godot’s Scene selection. This practice target stands in for your scene node.")
	elif step == 1:
		_label("ADD KEY  →  METHOD AND LOCATION")
		_picker("Method", ["_ready() · on scene start", "on_button_pressed() · when clicked"])
		_picker("Placement", ["End of method", "Before: play_sound()", "After: show_panel()"])
		_label("Placement decides when the call is reached. A method only runs when your game calls it.")
	elif step == 2:
		_label("DESTINATION  →  DYNAMIC VALUE")
		_picker("Property", ["position", "scale", "rotation" if mode != 2 else "modulate:a"])
		var field = preload("res://addons/tween_animation/editor/source_value_field.gd").new()
		field.build("Destination / offset", "", Vector3(1, 0, 0) if mode == 1 else Vector2(100, 0), [{"name": "destination", "type": "Vector3" if mode == 1 else "Vector2"}], PackedStringArray(["position", "scale"]), true)
		stage.add_child(field)
		field.choose("relative")
		_label("Offset reads the current position each time the method runs. Value uses a fixed destination; Method parameter uses data supplied by your game.")
	elif step == 3:
		_label("TIMING  →  DURATION AND WAIT")
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
		_label("SELECT KEY  →  INSPECT AND EDIT")
		var key := Button.new()
		key.text = "◆  position   ━━━ 0.4 s ━━━   ░ wait 0.2 s"
		stage.add_child(key)
		readout = Label.new()
		readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		readout.text = "Click the sample key."
		stage.add_child(readout)
		key.pressed.connect(func(): readout.text = "move_right() · actor.gd · line 12\nPosition · offset X +100 · duration 0.4 s · wait 0.2 s\nIn the real workspace, edit these fields and Apply; Move this call changes its method location.")
	else:
		_label("SOURCE CALLS  ↔  VISUAL KEYS")
		_label("Create code-backed key writes the selected parameters at your chosen method location. Undo restores the previous source. Rescan reads later script changes.")
		_label("Runtime means the order or duration depends on live data, branches or loops. It is not an exact playback time. Source line is optional: visual editing does not require writing code.")
		_label("Animation clips remains available for fixed poses and AnimationPlayer resources. Code Tweens is for runtime motion; it does not execute arbitrary gameplay methods as an editor preview.")


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
