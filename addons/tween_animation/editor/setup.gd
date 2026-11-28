@tool
extends MarginContainer
## Centered landing menu with tutorials shown only after choosing a target.

signal start_requested(mode: String)
signal code_start_requested
signal open_requested

const MODES := ["2D", "3D", "UI"]
const UI_REVISION := 25
var selected_mode := 0
var menu: CenterContainer
var details: ScrollContainer
var guide: RichTextLabel
var code_view: CodeEdit
var start_button: Button
var step_index := 0
var progress: Label
var step_title: Label
var previous: Button
var next_button: Button
var visual: Control
var steps: Array[Dictionary] = []
var lesson_picker: OptionButton
var lesson_path := 0
var content_body: VBoxContainer
var card_style: StyleBoxFlat
var copy_button: Button
var helper_view: CodeEdit
var comparison: RichTextLabel
var action_label: Label
var language_picker: OptionButton
var snippet_context: Label
var content_mode := 0
var navigation_hint: Label
var code_practice
var code_guide := true


func build(logo_texture: Texture2D) -> void:
	set_meta("ui_revision", UI_REVISION)
	name = "Setup"
	menu = CenterContainer.new()
	add_child(menu)
	var landing := VBoxContainer.new()
	landing.add_theme_constant_override("separation", 18)
	menu.add_child(landing)
	var logo := TextureRect.new()
	logo.texture = logo_texture
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(180, 60)
	landing.add_child(logo)
	var title := _text("Tweenimation", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	landing.add_child(title)
	var subtitle := _text("What would you like to animate?", 16)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate.a = 0.7
	landing.add_child(subtitle)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 12)
	landing.add_child(choices)
	var descriptions := ["Sprites & 2D worlds", "Objects & 3D worlds", "Menus & interfaces"]
	var icons := ["Node2D", "Node3D", "Control"]
	var colors := [Color("78b9ff"), Color("ff8f91"), Color("8fdfb3")]
	for index in range(3):
		var choice := Button.new()
		choice.custom_minimum_size = Vector2(170, 144)
		choice.tooltip_text = "Choose " + MODES[index] + " animation"
		choice.pressed.connect(_show_guide.bind(index))
		choices.add_child(choice)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.18, 0.19, 0.21)
		normal.border_color = colors[index].darkened(0.35)
		normal.border_width_top = 3
		normal.set_corner_radius_all(10)
		choice.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = colors[index].darkened(0.75)
		hover.border_color = colors[index]
		choice.add_theme_stylebox_override("hover", hover)
		choice.add_theme_stylebox_override("focus", hover)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 9)
		choice.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_top = 22
		var symbol := TextureRect.new()
		symbol.texture = EditorInterface.get_base_control().get_theme_icon(icons[index], "EditorIcons")
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.custom_minimum_size.y = 28
		symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(symbol)
		var label := _text(MODES[index] + " animation", 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(label)
		var hint := _text(descriptions[index], 12)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.modulate.a = 0.65
		content.add_child(hint)
	var open_button := Button.new()
	open_button.text = "Open Tween timeline"
	open_button.flat = true
	open_button.pressed.connect(func(): code_start_requested.emit())
	landing.add_child(open_button)

	details = ScrollContainer.new()
	details.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(details)
	var body := VBoxContainer.new()
	content_body = body
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not resized.is_connected(_fit_body):
		resized.connect(_fit_body)
	_fit_body()
	body.add_theme_constant_override("separation", 14)
	details.add_child(body)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 12)
	body.add_child(actions)
	var back := Button.new()
	back.text = "← Change animation type"
	back.pressed.connect(show_menu)
	actions.add_child(back)
	start_button = Button.new()
	start_button.custom_minimum_size.y = 36
	start_button.pressed.connect(_open_workspace)
	actions.add_child(start_button)
	lesson_picker = OptionButton.new()
	lesson_picker.add_item("Quick start · Your named Tween toolbox")
	lesson_picker.add_item("Go further · Visual timeline")
	lesson_picker.add_item("Go further · Effects and easing")
	lesson_picker.item_selected.connect(func(index: int):
		lesson_path = index
		_show_guide(selected_mode)
	)
	var lesson_row := HBoxContainer.new()
	lesson_row.add_theme_constant_override("separation", 10)
	lesson_row.add_child(_text("Tutorial path", 14))
	lesson_picker.tooltip_text = "Choose which series of lessons to read. Next and Back navigate within this path. This does not change your animation."
	lesson_picker.custom_minimum_size.x = 320
	lesson_row.add_child(lesson_picker)
	body.add_child(lesson_row)
	code_practice = preload("res://addons/tween_animation/editor/source_walkthrough.gd").new()
	code_practice.build()
	language_picker = OptionButton.new()
	language_picker.add_item("GDScript")
	language_picker.add_item("C# · Godot .NET")
	language_picker.add_item("Visual Timeline")
	language_picker.item_selected.connect(func(_index: int): _render_step())
	body.add_child(language_picker)
	language_picker.hide()
	snippet_context = _text("", 14)
	snippet_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(snippet_context)
	progress = _text("", 14)
	progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(progress)
	var progress_style := StyleBoxFlat.new()
	card_style = progress_style
	progress_style.bg_color = EditorInterface.get_base_control().get_theme_color("dark_color_1", "Editor")
	progress_style.border_width_top = 3
	progress_style.content_margin_left = 26
	progress_style.content_margin_right = 26
	progress_style.content_margin_top = 16
	progress_style.content_margin_bottom = 16
	progress_style.set_corner_radius_all(12)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", progress_style)
	body.add_child(card)
	var card_body := VBoxContainer.new()
	card_body.add_theme_constant_override("separation", 14)
	card.add_child(card_body)
	step_title = _text("", 26)
	step_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_body.add_child(step_title)
	visual = preload("res://addons/tween_animation/editor/tutorial_visual.gd").new()
	visual.custom_minimum_size.y = 170
	card_body.add_child(visual)
	card_body.add_child(code_practice)
	code_practice.hide()
	guide = RichTextLabel.new()
	guide.bbcode_enabled = true
	guide.fit_content = true
	guide.scroll_active = false
	guide.selection_enabled = true
	guide.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	guide.add_theme_font_size_override("normal_font_size", 17)
	guide.add_theme_font_size_override("bold_font_size", 17)
	guide.add_theme_font_size_override("mono_font_size", 16)
	action_label = _text("", 20)
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_body.add_child(action_label)
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_constant_override("line_separation", 6)
	card_body.add_child(guide)

	code_view = CodeEdit.new()
	code_view.editable = false
	code_view.custom_minimum_size.y = 0
	code_view.gutters_draw_line_numbers = true
	_style_code(code_view)
	copy_button = _snippet(card_body, code_view, "REGULAR GODOT TWEEN ANIMATION")
	helper_view = CodeEdit.new()
	helper_view.editable = false
	helper_view.custom_minimum_size.y = 0
	helper_view.gutters_draw_line_numbers = true
	_style_code(helper_view)
	_snippet(card_body, helper_view, "TWEENIMATION")
	card_body.move_child(helper_view.get_parent().get_parent(), code_view.get_parent().get_parent().get_index())
	comparison = RichTextLabel.new()
	comparison.bbcode_enabled = true
	comparison.fit_content = true
	comparison.scroll_active = false
	comparison.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	card_body.add_child(comparison)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 12)
	body.add_child(navigation)
	previous = Button.new()
	previous.text = "← Back"
	previous.custom_minimum_size = Vector2(110, 38)
	previous.pressed.connect(func(): _change_step(-1))
	navigation.add_child(previous)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(spacer)
	next_button = Button.new()
	next_button.custom_minimum_size = Vector2(150, 38)
	next_button.pressed.connect(func():
		if step_index == steps.size() - 1:
			if content_mode != 2 and lesson_path == 2:
				show_menu()
			else:
				_open_workspace()
		else:
			_change_step(1)
	)
	navigation.add_child(next_button)
	navigation_hint = _text("", 12)
	navigation_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	navigation_hint.modulate.a = 0.7
	body.add_child(navigation_hint)
	show_menu()


func show_menu() -> void:
	details.hide()
	menu.show()


func _text(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _open_workspace() -> void:
	code_start_requested.emit()


func _show_guide(index: int) -> void:
	_ensure_ui()
	selected_mode = index
	start_button.text = "Open " + MODES[index] + " timeline →"
	navigation_hint.text = "Next / Back show prepared practice examples. Open timeline shows the Tween calls found in your project scripts." if content_mode == 2 else "Next / Back change the lesson. Run copied code in your scene, or use Open timeline to try the editor steps."
	menu.hide()
	details.show()
	lesson_picker.get_parent().visible = content_mode != 2
	if content_mode == 2:
		steps = _source_lessons()
		start_button.text = "Open Tween timeline"
		navigation_hint.text = "Practice controls use isolated sample data. Next changes the explanation; Open takes you to your project."
		step_index = 0
		_render_step()
		return
	var mode: String = MODES[index]
	var target := "Node2D (Sprite2D, CharacterBody2D, etc.)"
	var differences := "Position and scale use Vector2. Rotation uses a single angle in radians."
	var property := "position"
	var start_value := "Vector2(0, 0)"
	var end_value := "Vector2(100, 0)"
	var node_path := "$Sprite2D"
	if mode == "3D":
		target = "Node3D (MeshInstance3D, Camera3D, etc.)"
		differences = "Position, scale and rotation use Vector3. Rotation is in radians; rotation_degrees is also available. These are value tracks; specialized skeleton tracks are not authored here."
		start_value = "Vector3(0, 0, 0)"
		end_value = "Vector3(2, 0, 0)"
		node_path = "$MeshInstance3D"
	elif mode == "UI":
		target = "Control (Panel, Button, Label, etc.)"
		differences = "Position and size use Vector2. modulate:a is a number from 0 to 1. Containers can override child position and size; animate a wrapper Control outside the Container's direct layout, or use scale/opacity."
		property = "modulate:a"
		start_value = "0.0"
		end_value = "1.0"
		node_path = "$Panel"
	steps = _source_lessons()
	_build_code_lesson(node_path, property, end_value)
	if lesson_path == 2:
		_build_code_lesson(node_path, property, end_value)
	steps.insert(2, _direction_lesson())
	steps.insert(3, _press_lesson())
	steps.insert(4, _owner_lesson(node_path, property, end_value))
	steps.insert(5, _registry_lesson(node_path, property, end_value))
	step_index = 0
	_render_step()


func _change_step(direction: int) -> void:
	var previous_step := step_index
	if _ensure_ui():
		_show_guide(selected_mode)
	step_index = clampi(previous_step + direction, 0, steps.size() - 1)
	_render_step()


func _render_step() -> void:
	next_button.disabled = false
	progress.text = MODES[selected_mode] + " GUIDE   ·   STEP %d OF %d   " % [step_index + 1, steps.size()]
	for index in steps.size():
		progress.text += "●  " if index <= step_index else "○  "
	step_title.text = str(steps[step_index]["title"])
	start_button.visible = content_mode == 2 or lesson_path != 2
	action_label.text = str(steps[step_index].get("action", "Try it in your scene, then continue when you are ready."))
	action_label.modulate = [Color("a1ccff"), Color("ffb4b5"), Color("ace8c5")][selected_mode]
	guide.text = str(steps[step_index]["body"])
	visual.set("caption", str(steps[step_index].get("visual", "READ  →  TRY  →  CONTINUE")))
	visual.set("mode", selected_mode)
	visual.set("step", step_index)
	visual.set("elapsed", 0.0)
	card_style.border_color = [Color("78b9ff"), Color("ff8f91"), Color("8fdfb3")][selected_mode]
	var visual_only := content_mode == 2
	visual.visible = not visual_only
	code_practice.visible = visual_only
	code_view.get_parent().get_parent().visible = not visual_only
	helper_view.get_parent().get_parent().visible = not visual_only
	snippet_context.visible = not visual_only
	if visual_only:
		code_practice.configure(selected_mode, step_index)
		comparison.hide()
		previous.disabled = step_index == 0
		next_button.text = "Open timeline →" if step_index == steps.size() - 1 else "Next step →"
		details.scroll_vertical = 0
		return
	var examples := preload("res://addons/tween_animation/editor/tutorial_examples.gd")
	var title := str(steps[step_index]["title"])
	if language_picker.selected == 0:
		code_view.text = examples.gdscript(str(steps[step_index]["native"]), step_index == 0)
		helper_view.text = examples.gdscript(str(steps[step_index]["helper"]), step_index == 0)
		snippet_context.text = "Add step 1 variables to your existing Node script. Run later action lines inside _ready() or an input handler; add any shown function definitions at script scope."
	else:
		var instructions := preload("res://addons/tween_animation/editor/tutorial_copy.gd").for_csharp(title)
		action_label.text = instructions["action"]
		guide.text = instructions["body"]
		code_view.text = examples.csharp(selected_mode, title, false)
		helper_view.text = examples.csharp(selected_mode, title, true)
		snippet_context.text = "Requires Godot .NET and using Godot;. Add step 1 fields to your existing Node class, then call the shown methods from _Ready() or a button/input handler. Helper examples access the GDScript runtime through Call()."
	_style_code(code_view)
	_style_code(helper_view)
	code_view.show()
	helper_view.show()
	copy_button.show()
	copy_button.tooltip_text = "Copy regular Godot Tween example"
	comparison.text = str(steps[step_index]["comparison"]).get_slice("\n\n[b]Defaults:", 0)
	comparison.visible = content_mode == 0 and not comparison.text.is_empty()
	previous.disabled = step_index == 0
	next_button.text = "Let's animate →" if step_index == steps.size() - 1 else "Next step →"
	if lesson_path == 2 and step_index == steps.size() - 1:
		next_button.text = "Choose another guide →"
	details.scroll_vertical = 0


func _fit_body() -> void:
	if is_instance_valid(content_body):
		content_body.custom_minimum_size.x = 0
		content_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ensure_ui() -> bool:
	# Tool scripts can reload while their existing controls remain alive.
	# Rebuild added fields and signal targets together rather than using stale UI.
	if get_meta("ui_revision", 0) == UI_REVISION and is_instance_valid(card_style) and is_instance_valid(copy_button) and is_instance_valid(helper_view) and is_instance_valid(language_picker):
		return false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	build(preload("res://addons/tween_animation/header_logo.svg"))
	lesson_picker.select(lesson_path)
	return true


func _property_lesson() -> Dictionary:
	var path := "$Sprite2D"
	var operations: Array[Array] = [
		["position", "Vector2(100, 0)", "position is measured in 2D units"],
		["scale", "Vector2(1.2, 1.2)", "scale is a multiplier; (1, 1) is normal size"],
		["rotation", "PI / 2.0", "rotation uses radians: PI / 2 is 90 degrees"],
		["rotation_degrees", "180.0", "same angle, expressed in degrees instead"]
	]
	var explanation := "[b]Position and scale → Vector2. Rotation → one number.[/b]\n\nThis script moves, grows, then turns the target. rotation and rotation_degrees describe the same angle in different units. Each operation below lasts half a second."
	if selected_mode == 1:
		path = "$MeshInstance3D"
		operations = [
			["position", "Vector3(2, 0, 0)", "move 2 units along local X"],
			["scale", "Vector3(1.2, 1.2, 1.2)", "grow evenly on all three axes"],
			["rotation", "Vector3(0, PI / 2.0, 0)", "turn 90 degrees around Y, expressed in radians"],
			["rotation_degrees", "Vector3(0, 180, 0)", "continue to 180 degrees around Y, using degrees"]
		]
		explanation = "[b]Three axes → Vector3(x, y, z).[/b]\n\nPosition moves the target; scale changes its size. rotation uses radians on each axis. rotation_degrees describes the same orientation using degrees.\n\nThe script below shows all four properties in sequence. These are ordinary Node3D properties; specialized skeleton tracks are outside this editor's scope."
	elif selected_mode == 2:
		path = "$Panel"
		operations = [
			["position", "Vector2(100, 40)", "move the Control in its parent's coordinates"],
			["size", "Vector2(240, 100)", "request a size; minimum size may constrain it"],
			["scale", "Vector2(1.1, 1.1)", "scale is a multiplier"],
			["modulate:a", "0.3", "alpha: 0 is transparent, 1 is opaque"]
		]
		explanation = "[b]UI layout → Vector2. Opacity → a number from 0 to 1.[/b]\n\nPosition moves a Control, size resizes it, and modulate:a fades it. A Container can override its direct child's position and size. Try this on a Panel outside a Container, or animate a nested wrapper."
	var code := "# Attach to the parent. Update the child path to match your scene.\nextends Node\n\n@onready var target = " + path + "\n\nfunc _ready() -> void:\n"
	if selected_mode == 2 and lesson_path != 2:
		code += "    target.pivot_offset = target.size / 2.0 # Center scaling and rotation\n"
	if lesson_path == 2:
		code += "    var animator := Tweenimator.new()\n"
	else:
		code += "    var tween := create_tween()\n"
	for operation in operations:
		code += "    # " + str(operation[2]) + "\n"
		if lesson_path == 2:
			var method_name: String = {"position": "move_to", "scale": "scale_to", "rotation": "rotate_to", "rotation_degrees": "rotate_degrees", "size": "resize_to", "modulate:a": "fade_to"}[operation[0]]
			code += '    await animator.%s(target, %s, 0.5).finished\n' % [method_name, operation[1]]
		else:
			code += '    tween.tween_property(target, "%s", %s, 0.5)\n' % [operation[0], operation[1]]
	return {"title": "See what each property does", "body": explanation + "\n\nCopy the script, run the scene, and compare the results. Next step advances this guide; it does not change your scene.", "code": code}


func _build_code_lesson(node_path: String, property: String, end_value: String) -> void:
	var header := "# Attach this script to the scene root. Adjust the child path.\nextends Node\n\n@onready var target = " + node_path + "\n\n"
	var create := "var tween := create_tween()" if lesson_path == 1 else "var animator := Tweenimator.new()"
	var animate := 'tween.tween_property(target, "%s", %s, 1.0)' % [property, end_value]
	var helper := 'var tween := animator.move_to(target, %s, 1.0)' % end_value
	if selected_mode == 0:
		helper = 'var tween := animator.move_to(target, %s, 1.0)' % end_value
	elif selected_mode == 2:
		helper = 'var tween := animator.fade_to(target, %s, 1.0)' % end_value
	var basic := header + "func _ready() -> void:\n    " + create + "\n    " + (animate if lesson_path == 1 else helper) + "\n"
	var eased := header + "func _ready() -> void:\n    " + create + "\n"
	if lesson_path == 1:
		eased += "    tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)\n    " + animate + "\n"
	else:
		eased += '    animator.transition_type = Tween.TRANS_SINE\n    ' + helper + "\n"
	var sequence := basic + '    tween.tween_interval(0.2)\n' if lesson_path == 1 else basic.replace(helper, helper.trim_suffix(")") + ", 0.2)")
	sequence += '    tween.tween_callback(func(): print("Movement and wait complete"))\n'
	var cancel := header + "var active_tween: Tween\n\nfunc _ready() -> void:\n    animate()\n\nfunc animate() -> void:\n    if active_tween and active_tween.is_running():\n        active_tween.kill()\n"
	if lesson_path == 1:
		cancel += '    active_tween = create_tween()\n    active_tween.tween_property(target, "%s", %s, 1.0)\n' % [property, end_value]
	else:
		cancel = header + "@onready var animator := Tweenimator.new()\n\nfunc _ready() -> void:\n    animate()\n\nfunc animate() -> void:\n"
		cancel += ('    animator.fade_to(target, %s, 1.0)\n' if selected_mode == 2 else '    animator.move_to(target, %s, 1.0)\n') % end_value

	var api := "Godot's built-in Tween API" if lesson_path == 1 else "the add-on's Tweenimator helper"
	steps = [
		{"title": "A little motion, all in code", "body": "[b]This path uses %s.[/b]\n\nCreate the matching child node, attach this script to its parent, and adjust the child path. Run the scene: _ready() creates the animation. No timeline resource is needed.\n\nThe property name is %s; the destination is %s. Duration is 1 second. The Tween starts at the property's current value." % [api, property, end_value], "code": basic},
		{"title": "Give the movement a feel", "body": "[b]Easing shapes the journey.[/b]\n\nSine easing makes the start and finish softer. Try a different transition, such as TRANS_BACK, and run again.\n\nNative defaults are linear. The helper defaults to Sine with Ease In/Out. Its custom() returns a Godot Tween; transition settings must be chosen before the property is added.", "code": eased},
		{"title": "Make one thing follow another", "body": "[b]Move → wait → celebrate.[/b]\n\nPass interval as the helper's optional final argument: the effect runs, waits 0.2 seconds, then reaches the callback. Omit interval or use 0.0 for no wait. Native Godot adds the same wait with tween_interval(0.2).\n\nThe interval belongs to the returned Tween. await tween.finished waits for it, and named entries stay live until it ends. press/wiggle wait after all of their stages. You can still append tween_interval() elsewhere in a longer sequence.", "code": sequence},
		{"title": "Handle another click gracefully", "body": "[b]One target, one active animation.[/b]\n\nNative code stores and kills its previous Tween. Reuse one Tweenimator instance and it replaces the active effect on that target/property automatically. Connect an input action to animate() to try repeated triggers.\n\nThe helper can be constructed first with no owner. Node-target effects create their Tween using the target unless you supply a default owner. After a Tween finishes, create a new one to replay it.", "code": cancel}
	]


func _attach_comparisons(node_path: String, property: String, end_value: String, start_value: String) -> void:
	var original_steps := steps
	var original_path := lesson_path
	lesson_path = 1
	_build_code_lesson(node_path, property, end_value)
	var native_steps := steps
	var native_properties := _property_lesson()
	lesson_path = 2
	_build_code_lesson(node_path, property, end_value)
	var helper_steps := steps
	var helper_properties := _property_lesson()
	lesson_path = original_path
	steps = original_steps
	for index in steps.size():
		var title := str(steps[index]["title"])
		var example_index := 0
		for candidate in native_steps.size():
			if native_steps[candidate]["title"] == title:
				example_index = candidate
		steps[index]["native"] = native_steps[example_index]["code"]
		steps[index]["helper"] = helper_steps[example_index]["code"]
		var benefit := "[b]What the add-on saves:[/b] move_to() names the intent and wraps tween_property(). You can always use Godot's Tween API directly."
		if selected_mode == 1:
			benefit = "[b]What the add-on saves:[/b] Movement helpers centralize coordinates, easing and replacement of an active move. move_to() and directional helpers support Node3D directly, including its Vector3 coordinates."
		elif selected_mode == 2:
			benefit = "[b]What the add-on saves:[/b] fade_to() supplies modulate:a and clamps alpha to 0–1. Native tween_property() can do the same thing explicitly."
		if example_index >= 2:
			benefit = "[b]Same Tween underneath:[/b] the helper returns a Godot Tween. Sequencing, callbacks, finished and kill() use Godot's existing API in both examples."
		if example_index == 3:
			benefit = "[b]Less repeat-input bookkeeping:[/b] native code stores and kills its previous Tween. A persistent Tweenimator helper replaces only the matching target/property automatically; a simultaneous fade or scale can continue."
		if title == "See what each property does":
			steps[index]["native"] = native_properties["code"]
			steps[index]["helper"] = helper_properties["code"]
			benefit = "[b]Same properties, two entry points:[/b] named movement, rotation, size and fade methods remove property strings. Controls are centered for scale/rotation automatically; set auto_center_pivot = false to preserve your own pivot."
		if title == "Move left without the vector math":
			var pair := _direction_lesson()
			steps[index]["native"] = pair["native"]
			steps[index]["helper"] = pair["helper"]
			benefit = "[b]Less setup:[/b] move_left() calculates the relative destination, selects Vector2 or Vector3, applies shared easing, and replaces an active position effect. Reuse the same helper for that replacement behavior."
		if title == "A press that returns to its starting size":
			var pair := _press_lesson()
			steps[index]["native"] = pair["native"]
			steps[index]["helper"] = pair["helper"]
			benefit = "[b]A complete effect:[/b] press() captures the starting scale, builds both phases, centers Control pivots, and preserves the original rest scale across repeated presses."
		if title == "Who owns the Tween? Choose your entry point":
			var pair := _owner_lesson(node_path, property, end_value)
			steps[index]["native"] = pair["native"]
			steps[index]["helper"] = pair["helper"]
			benefit = "[b]Owner and target are separate:[/b] Node-target effects can infer the owner, or you can supply a controller. Creating the manager does not require a pre-existing Tween or a Node."
		if title == "Name it. Find it. Control it.":
			var pair := _registry_lesson(node_path, property, end_value)
			steps[index]["native"] = pair["native"]
			steps[index]["helper"] = pair["helper"]
			benefit = "[b]An individual Tween registry:[/b] tweens maps names to live Godot Tween objects. Create an animation here or register one from anywhere. Access it through the dictionary or use name-based controls; release() hands it back without killing it."
		if title == "Plant the first key":
			for api in ["native", "helper"]:
				steps[index][api] = str(steps[index][api]).replace("func _ready() -> void:\n", 'func _ready() -> void:\n    target.set_indexed(^"%s", %s) # Explicit starting value\n' % [property, start_value])
		steps[index]["native"] = _explain_code(str(steps[index]["native"]))
		steps[index]["helper"] = _explain_code(str(steps[index]["helper"]))
		steps[index]["comparison"] = benefit + "\n\n[b]Defaults:[/b] native Tween uses Linear / In-Out; Tweenimation uses Sine / In-Out. Set native transition/ease before tween_property() to match the helper. Both scripts are alternatives; run one at a time."


func _style_code(view: CodeEdit) -> void:
	view.text = preload("res://addons/tween_animation/editor/snippet_format.gd").prepare(view.text, content_mode == 1)
	view.custom_minimum_size.y = 0
	view.scroll_fit_content_height = true
	var background := EditorInterface.get_base_control().get_theme_color("dark_color_2", "Editor")
	var dark := background.get_luminance() < 0.5
	var foreground := Color("dce4ef") if dark else Color("202733")
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# CodeEdit uses a separate foreground for read-only text.
	view.add_theme_color_override("background_color", background)
	view.add_theme_color_override("font_color", foreground)
	view.add_theme_color_override("font_readonly_color", foreground)
	view.add_theme_color_override("font_selected_color", foreground)
	view.add_theme_color_override("line_number_color", Color("a5afbe") if dark else Color("546070"))
	var syntax := CodeHighlighter.new()
	syntax.symbol_color = foreground
	syntax.member_variable_color = foreground
	syntax.number_color = Color("b6dba3") if dark else Color("35631d")
	syntax.function_color = Color("92ccef") if dark else Color("145980")
	syntax.add_color_region('"', '"', Color("edce96") if dark else Color("785109"))
	syntax.add_color_region("#" if not is_instance_valid(language_picker) or language_picker.selected == 0 else "//", "", Color("a5afbe") if dark else Color("546070"), true)
	for keyword in ["extends", "var", "func", "await", "if", "return", "else", "using", "public", "private", "partial", "class", "override", "void", "async", "new", "null", "true", "false"]:
		syntax.add_keyword_color(keyword, Color("d4b8f4") if dark else Color("663795"))
	view.syntax_highlighter = syntax


func _direction_lesson() -> Dictionary:
	var path: String = ["$Sprite2D", "$MeshInstance3D", "$Panel"][selected_mode]
	var distance := "2.0" if selected_mode == 1 else "100.0"
	var vector := "Vector3.LEFT" if selected_mode == 1 else "Vector2.LEFT"
	var header := "extends Node\n\n@onready var target = " + str(path) + "\n\n"
	var native := header + "func _ready() -> void:\n    var tween := create_tween()\n    tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)\n    var destination = target.position + " + vector + " * " + distance + '\n    tween.tween_property(target, "position", destination, 0.3)\n'
	var helper := header + "@onready var animate := Tweenimator.new()\n\nfunc _ready() -> void:\n    animate.move_left(target, " + distance + ", 0.3)\n"
	return {"title": "Move left without the vector math", "body": "[b]Say the direction, distance and duration.[/b]\n\nmove_left(), move_right(), move_up() and move_down() work on 2D, 3D and UI nodes. All directions use the parent's axes, not the camera or the target's rotated axes.\n\nUp is -Y for 2D/UI and +Y for 3D. In 3D, move_forward() uses -Z and move_back() uses +Z. Distances are pixels for normal 2D/UI layouts and scene units for 3D. Containers may override UI movement.", "native": native, "helper": helper}


func _press_lesson() -> Dictionary:
	var path: String = ["$Sprite2D", "$MeshInstance3D", "$Panel"][selected_mode]
	var header := "extends Node\n\n@onready var target = " + str(path) + "\n\n"
	var pivot := "    target.pivot_offset = target.size / 2.0\n" if selected_mode == 2 else ""
	var native := header + "func _ready() -> void:\n" + pivot + "    var rest = target.scale\n    var tween := create_tween()\n    tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)\n    tween.tween_property(target, ^\"scale\", rest * 0.95, 0.1)\n    tween.tween_property(target, ^\"scale\", rest, 0.2)\n"
	var helper := header + "@onready var animate := Tweenimator.new()\n\nfunc _ready() -> void:\n    animate.press(target)\n"
	return {"title": "A press that returns to its starting size", "body": "[b]A whole effect in one call.[/b]\n\npress() shrinks by 5 percent, then returns to the target's original scale. It works on 2D, 3D and UI nodes. Reuse the helper for repeated triggers.\n\nFor UI, the pivot is centered automatically. Disable auto_center_pivot when you intentionally use a different pivot. scale_up(), scale_down() and wiggle() are also available.", "native": native, "helper": helper}


func _explain_code(source: String) -> String:
	# Setup and owner explanations live in their own step instead of being
	# inserted into every later snippet.
	return source


func _owner_lesson(node_path: String, property: String, end_value: String) -> Dictionary:
	var native := 'extends Node\n\n@onready var target = %s\n\nfunc _ready() -> void:\n    var tween := create_tween()\n    tween.tween_property(target, "%s", %s, 1.0)\n' % [node_path, property, end_value]
	var named := 'animate.fade_to(target, %s, 1.0)' % end_value if selected_mode == 2 else 'animate.move_to(target, %s, 1.0)' % end_value
	var helper := 'extends Node\n\n@onready var target = %s\nvar animate := Tweenimator.new()\n\nfunc _ready() -> void:\n    # Choose ONE approach. This example runs the named effect.\n    use_named_effect()\n\nfunc use_named_effect() -> void:\n    # Creates its own Tween, bound to the Node target.\n    %s\n\nfunc use_custom_property() -> void:\n    # Same property through the generic API. Also creates its own Tween.\n    animate.custom(target, ^"%s", %s, 1.0)\n\nfunc choose_controller_owner() -> void:\n    # Useful when the controller should determine the Tween lifetime.\n    var controller_owned := Tweenimator.new(self)\n    controller_owned.custom(target, ^"%s", %s, 1.0)\n' % [node_path, named, property, end_value, property, end_value]
	return {"title": "Who owns the Tween? Choose your entry point", "body": "[b]A Tweenimator does not need an existing Tween, or an owner at construction.[/b]\n\nTweenimator.new() can create Node-target effects later: move_left(), press() and custom() create their own Tween and bind it to the target Node. Freeing that owner kills its Tweens.\n\nUse Tweenimator.new(self) or another controller when you want a shared lifetime instead. create(name, owner) can choose a specific owner for one named animation. ShaderMaterial and callback-only effects need an explicit default owner because there is no Node target to infer.\n\nDedicated effects express intent. custom() animates any writable Tween-compatible property. method() handles callback-driven values. Returned Tweens work with ordinary Godot chaining and awaiting. Existing external Tweens can be stored by name without changing their owner or operations.", "native": native, "helper": helper}


func _snippet(parent: VBoxContainer, view: CodeEdit, caption: String) -> Button:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = view.get_theme_color("background_color")
	style.set_corner_radius_all(6)
	style.border_width_left = 3
	style.border_color = Color("72d7bb") if caption == "TWEENIMATION" else EditorInterface.get_base_control().get_theme_color("accent_color", "Editor")
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var body := VBoxContainer.new()
	panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var label := _text(caption, 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.modulate.a = 0.75
	header.add_child(label)
	var copy := Button.new()
	copy.flat = true
	copy.icon = EditorInterface.get_base_control().get_theme_icon("ActionCopy", "EditorIcons")
	copy.tooltip_text = "Copy " + caption.to_lower() + " example"
	copy.custom_minimum_size = Vector2(30, 30)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(view.text)
		copy.icon = EditorInterface.get_base_control().get_theme_icon("StatusSuccess", "EditorIcons")
		copy.tooltip_text = "Copied!"
	)
	header.add_child(copy)
	view.text_changed.connect(func():
		copy.icon = EditorInterface.get_base_control().get_theme_icon("ActionCopy", "EditorIcons")
		copy.tooltip_text = "Copy " + caption.to_lower() + " example"
	)
	body.add_child(view)
	return copy


func _registry_lesson(node_path: String, property: String, end_value: String) -> Dictionary:
	var native := 'extends Node\n\n@onready var target = %s\nvar tweens: Dictionary[StringName, Tween] = {}\n\nfunc _ready() -> void:\n    var tween := create_tween()\n    tween.tween_property(target, "%s", %s, 1.0)\n    tweens[&"intro"] = tween\n    # Plain dictionaries need their own lifetime/replacement handling.\n    tween.finished.connect(func():\n        if tweens.get(&"intro") == tween:\n            tweens.erase(&"intro")\n    )\n    tweens[&"intro"].pause()\n    tweens[&"intro"].play()\n' % [node_path, property, end_value]
	var helper := 'extends Node\n\n@onready var target = %s\nvar animate := Tweenimator.new()\n\nfunc _ready() -> void:\n    # Create a named animation here; append any Godot Tween operations.\n    var intro := animate.create(&"intro", self)\n    intro.tween_property(target, "%s", %s, 1.0)\n    intro.tween_interval(0.2)\n    # Direct dictionary access and the helper refer to the SAME Tween.\n    animate.tweens[&"intro"].pause()\n    animate.resume(&"intro")\n\nfunc register_external(external: Tween) -> void:\n    # Any valid Tween from other code can join the registry unchanged.\n    animate.store(&"external", external)\n    animate.pause(&"external")\n    animate.resume(&"external")\n\nfunc use_named_effect() -> void:\n    animate.store(&"slide", animate.move_left(target, %s, 0.3))\n\nfunc hand_back_to_other_code() -> Tween:\n    # Removes the name and replacement tracking, but does not kill it.\n    return animate.release(&"intro")\n\nfunc stop_one() -> void:\n    animate.stop_named(&"intro")\n' % [node_path, property, end_value, "2.0" if selected_mode == 1 else "100.0"]
	return {"title": "Name it. Find it. Control it.", "body": "[b]Give each animation a name you can reach from anywhere that has this Tweenimator.[/b]\n\ncreate(name, owner) creates and stores a new Tween. store(name, tween) tracks any valid existing Tween without rebuilding it. Dedicated effects also create their own Tweens; store their return values when you want names.\n\nAccess tweens[&\"intro\"] directly, or use get_tween() to safely handle a missing name. pause(), resume() and stop_named() address individual entries. release() removes tracking without stopping the Tween, so outside code can keep using it.\n\nReusing a name replaces and kills its old Tween by default. Pass false to store() to reject a duplicate instead. Finished entries are removed automatically. External kill() calls are cleaned up lazily by get_tween()/list_tweens(). Tweens cannot be replayed after completion; create a fresh one. store() does not introspect operations or turn arbitrary scripts into editor tracks. Direct dictionary writes bypass the helper's validation and automatic finished cleanup.", "native": native, "helper": helper}


func _prioritize_setup() -> void:
	var advanced := steps
	steps = preload("res://addons/tween_animation/editor/onboarding.gd").lessons(selected_mode)
	for index in steps.size():
		var lesson: Dictionary = steps[index]
		lesson["native"] = _explain_code(str(lesson["native"]))
		lesson["helper"] = _explain_code(str(lesson["helper"]))
		lesson["comparison"] = "Godot supplies the Tween engine; Tweenimator adds named tracking and effects. Defaults: native Linear, helper Sine / In-Out." if index == 0 else ""
	if lesson_path == 0:
		return
	var timeline_titles := ["Give it a property to play with", "Plant the first key", "Choose the destination", "Bring it to life", "Let your game press Play", "Bring your existing work along"]
	var effect_titles := ["See what each property does", "A press that returns to its starting size", "Give the movement a feel", "Make one thing follow another"]
	for lesson in advanced:
		if (lesson_path == 1 and lesson["title"] in timeline_titles) or (lesson_path == 2 and lesson["title"] in effect_titles):
			steps.append(lesson)


func set_content_mode(value: int) -> void:
	_ensure_ui()
	var was_menu := menu.visible
	var previous_step := step_index
	var old_mode := content_mode
	content_mode = clampi(value, 0, 2)
	language_picker.select(content_mode)
	_show_guide(selected_mode)
	if old_mode != 2 and content_mode != 2:
		step_index = clampi(previous_step, 0, steps.size() - 1)
		_render_step()
	if was_menu:
		show_menu()


func _source_lessons() -> Array[Dictionary]:
	return [
		{"title": "Choose who moves", "action": "Try selecting the practice node below.", "body": "[b]Selection gives the timeline its target.[/b] Choose a scene node in your project. Tweenimation detects 2D, 3D or UI and reads recognizable Tween calls from scripts attached to the open scene. This practice selection does not unlock or block Next."},
		{"title": "Choose when your game asks it to move", "action": "Click a sample code line, then choose Before or After.", "body": "[b]A timeline entry represents a Tween call in your script.[/b] Add Tween shows the existing method as a read-only preview. Click a line to pick a gap before or after its statement. Existing code moves down; nothing is replaced. If the node has no script, a file picker can create a GDScript entry point. You enter data and locations; the addon writes the call."},
		{"title": "Let the destination change", "action": "Try Offset, Value or Method parameter below.", "body": "[b]This is where Tweens shine.[/b] Offset reads the current property each time the call runs. Move a character, then call the same animation again: its starting position can be different. A method parameter supplies a destination chosen by gameplay. The fields stay visual."},
		{"title": "Give motion a rhythm", "action": "Try a duration, a wait and a sequence choice.", "body": "[b]Duration moves; interval waits afterwards.[/b] Join an earlier Tween to append a step, or create an independent Tween that runs alongside it. The map shows known timing within each method invocation. Different methods are not one shared playback sequence."},
		{"title": "A call you can understand", "action": "Click the sample Tween call to reveal its details.", "body": "[b]Select a timeline entry to see its source method, line and editable parameters.[/b] Apply writes only changed arguments. Original runtime expressions are kept until you choose a replacement. Move this call changes placement inside its method; Source line is optional for coders."},
		{"title": "Read your Tween map", "action": "Open the Tween timeline and select a scene node.", "body": "[b]Your timeline is a readable map of runtime Tween calls.[/b] Select an operation to inspect its method, source line, target and parameters. Edit values visually or jump to the source. Branches and runtime values remain marked as such; run the scene to see gameplay behavior."}
	]
