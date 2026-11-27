@tool
extends MarginContainer
## Centered landing menu with tutorials shown only after choosing a target.

signal start_requested(mode: String)
signal open_requested

const MODES := ["2D", "3D", "UI"]
const UI_REVISION := 3
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
var reuse_button: Button
var visual: Control
var steps: Array[Dictionary] = []
var lesson_picker: OptionButton
var lesson_path := 0
var content_body: VBoxContainer
var card_style: StyleBoxFlat
var copy_button: Button
var timeline_example := ""
var helper_view: CodeEdit
var comparison: RichTextLabel
var resource_view: CodeEdit


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
	open_button.text = "Open an existing animation…"
	open_button.flat = true
	open_button.pressed.connect(func(): open_requested.emit())
	landing.add_child(open_button)

	details = ScrollContainer.new()
	details.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(details)
	var body := VBoxContainer.new()
	content_body = body
	body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	start_button.pressed.connect(func(): start_requested.emit(MODES[selected_mode]))
	actions.add_child(start_button)
	lesson_picker = OptionButton.new()
	lesson_picker.add_item("Learn visually · Timeline")
	lesson_picker.add_item("Learn Godot Tweens · Code only")
	lesson_picker.add_item("Use Tweenimation · Helper code")
	lesson_picker.item_selected.connect(func(index: int):
		lesson_path = index
		_show_guide(selected_mode)
	)
	body.add_child(lesson_picker)
	progress = _text("", 13)
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
	step_title = _text("", 24)
	card_body.add_child(step_title)
	visual = preload("res://addons/tween_animation/editor/tutorial_visual.gd").new()
	visual.custom_minimum_size.y = 170
	card_body.add_child(visual)
	guide = RichTextLabel.new()
	guide.bbcode_enabled = true
	guide.fit_content = true
	guide.scroll_active = false
	guide.selection_enabled = true
	guide.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	guide.add_theme_font_size_override("normal_font_size", 15)
	card_body.add_child(guide)

	code_view = CodeEdit.new()
	code_view.editable = false
	code_view.custom_minimum_size.y = 250
	code_view.gutters_draw_line_numbers = true
	var syntax := CodeHighlighter.new()
	syntax.number_color = Color("a7d5a0")
	syntax.add_color_region('"', '"', Color("e8c988"))
	syntax.add_color_region("#", "", Color("88949d"), true)
	syntax.function_color = Color("83c5ed")
	for keyword in ["extends", "var", "func", "await", "if", "return", "else"]:
		syntax.add_keyword_color(keyword, Color("c7a9ed"))
	code_view.syntax_highlighter = syntax
	card_body.add_child(_text("GODOT TWEEN · Built into Godot", 14))
	card_body.add_child(code_view)
	copy_button = Button.new()
	copy_button.text = "Copy example"
	copy_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	copy_button.pressed.connect(func():
		DisplayServer.clipboard_set(code_view.text)
		copy_button.text = "Copied!"
	)
	card_body.add_child(copy_button)
	card_body.add_child(_text("TWEENIMATION · Optional convenience helper", 14))
	helper_view = CodeEdit.new()
	helper_view.editable = false
	helper_view.custom_minimum_size.y = 230
	helper_view.gutters_draw_line_numbers = true
	helper_view.syntax_highlighter = syntax.duplicate()
	card_body.add_child(helper_view)
	var copy_helper := Button.new()
	copy_helper.text = "Copy helper example"
	copy_helper.size_flags_horizontal = Control.SIZE_SHRINK_END
	copy_helper.pressed.connect(func(): DisplayServer.clipboard_set(helper_view.text))
	card_body.add_child(copy_helper)
	comparison = RichTextLabel.new()
	comparison.bbcode_enabled = true
	comparison.fit_content = true
	comparison.scroll_active = false
	comparison.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	card_body.add_child(comparison)
	resource_view = CodeEdit.new()
	resource_view.editable = false
	resource_view.custom_minimum_size.y = 230
	resource_view.gutters_draw_line_numbers = true
	card_body.add_child(resource_view)
	reuse_button = Button.new()
	reuse_button.text = "Open an existing .tres animation…"
	reuse_button.pressed.connect(func(): open_requested.emit())
	card_body.add_child(reuse_button)
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
			if lesson_path > 0:
				show_menu()
			else:
				start_requested.emit(MODES[selected_mode])
		else:
			_change_step(1)
	)
	navigation.add_child(next_button)
	var navigation_hint := _text("Next / Back change the lesson. Run copied code in your scene, or use Open timeline to try the editor steps.", 12)
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


func _show_guide(index: int) -> void:
	_ensure_ui()
	selected_mode = index
	menu.hide()
	details.show()
	var mode: String = MODES[index]
	start_button.text = "Open " + mode + " timeline →"
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
	steps = [
		{"title": "Meet your animation target", "body": "[b]Mission: pick something to bring to life.[/b]\n\nOpen a scene and select a [b]%s[/b] in the Scene tree.\n\n%s" % [target, differences]},
		{"title": "Give it a property to play with", "body": "[b]A track = one property changing over time.[/b]\n\nOpen the timeline, enter [code]%s[/code], then choose [b]Add track[/b].\n\nThink of a track as a lane; its keys are the stops along the way. Return to Setup to continue this guide." % property},
		{"title": "Plant the first key", "body": "[b]This is where the journey begins. ◆[/b]\n\nAt [b]0 seconds[/b], enter [code]%s[/code] in Value and press [b]Capture key[/b].\n\nTip: an empty Value field captures what the selected node already has." % start_value},
		{"title": "Choose the destination", "body": "[b]Two keys. One little journey. ◆ ━━━ ◆[/b]\n\nMove the playhead to [b]1 second[/b], enter [code]%s[/code], then [b]Capture key[/b] again.\n\nScrub between them: Godot fills in the values along the way." % end_value},
		{"title": "Bring it to life", "body": "[b]Press Play preview, then take a look![/b]\n\nSwitch to Godot's [b]%s view[/b] while playback continues; return to Timeline to pause. Then [b]Save[/b] your animation as a .tres file.\n\nPreview changes the open scene's properties and leaves the last sampled values on its nodes. The animation illustrated here is only a demonstration." % ("3D" if mode == "3D" else "2D")},
		{"title": "Let your game press Play", "body": "[b]Your animation is ready for code.[/b]\n\nAdd an [b]AnimationPlayer[/b] as a child of the scene root used when authoring. Keep its default root_node (..).\n\nThe example loads your saved Animation into a library. Replace the file path with yours. The other two functions show direct Tween and helper alternatives."},
		{"title": "Bring your existing work along", "body": "[b]Already made an animation? Give it a home here.[/b]\n\n[b].tres Animation[/b] → Open it below. Its track paths must match the open scene.\n\n[b]AnimationPlayer[/b] → Save its Animation resource as .tres, then Open it.\n\n[b]Tween code[/b] → Keep running it, or recreate its property, values and duration as keys. Running Tweens cannot be imported.\n\nValue tracks are supported. Script easing, chained and parallel Tween calls are not automatically converted. The helper's custom() works across 2D, 3D and UI; its movement shortcuts currently accept Node2D."}
	]
	code_view.text = ("# Attach to the scene root; add AnimationPlayer as a child.\nextends Node\n\n" +
		"func _ready() -> void:\n" +
		"    var clip := load(\"res://animations/my_animation.tres\") as Animation\n" +
		"    var library := AnimationLibrary.new()\n" +
		"    library.add_animation(\"my_animation\", clip)\n" +
		"    $AnimationPlayer.add_animation_library(\"tweenimation\", library)\n" +
		"    $AnimationPlayer.play(\"tweenimation/my_animation\")\n\n" +
		"# Alternative: animate directly with a runtime Tween.\n" +
		"func animate_directly() -> void:\n" +
		"    var tween := create_tween()\n" +
		"    tween.tween_property(%s, \"%s\", %s, 1.0)\n\n" +
		"# Or use the add-on's runtime helper (same property and target).\n" +
		"func animate_with_helper() -> void:\n" +
		"    var animator := TweenAnimation.new(self)\n" +
		"    animator.custom(%s, ^\"%s\", %s, 1.0)\n") % [node_path, property, end_value, node_path, property, end_value]

	timeline_example = code_view.text
	if lesson_path > 0:
		_build_code_lesson(node_path, property, end_value)
	steps.insert(1, _property_lesson())
	_attach_comparisons(node_path, property, end_value, start_value)
	step_index = 0
	_render_step()


func _change_step(direction: int) -> void:
	var previous_step := step_index
	if _ensure_ui():
		_show_guide(selected_mode)
	step_index = clampi(previous_step + direction, 0, steps.size() - 1)
	_render_step()


func _render_step() -> void:
	progress.text = MODES[selected_mode] + " GUIDE   ·   STEP %d OF %d   " % [step_index + 1, steps.size()]
	for index in steps.size():
		progress.text += "●  " if index <= step_index else "○  "
	step_title.text = str(steps[step_index]["title"])
	start_button.visible = lesson_path == 0
	guide.text = str(steps[step_index]["body"])
	visual.set("mode", selected_mode)
	visual.set("step", step_index)
	visual.set("elapsed", 0.0)
	card_style.border_color = [Color("78b9ff"), Color("ff8f91"), Color("8fdfb3")][selected_mode]
	code_view.text = str(steps[step_index]["native"])
	helper_view.text = str(steps[step_index]["helper"])
	code_view.show()
	helper_view.show()
	copy_button.show()
	copy_button.text = "Copy Godot example"
	comparison.text = str(steps[step_index]["comparison"])
	resource_view.visible = lesson_path == 0 and step_index == 6
	resource_view.text = "# Play the saved .tres timeline with AnimationPlayer.\n" + timeline_example
	reuse_button.visible = lesson_path == 0 and step_index == 7
	previous.disabled = step_index == 0
	next_button.text = "Let's animate →" if step_index == steps.size() - 1 else "Next step →"
	if lesson_path > 0 and step_index == steps.size() - 1:
		next_button.text = "Choose another guide →"
	details.scroll_vertical = 0


func _fit_body() -> void:
	if is_instance_valid(content_body):
		content_body.custom_minimum_size.x = maxf(300.0, minf(860.0, size.x - 32.0))


func _ensure_ui() -> bool:
	# Tool scripts can reload while their existing controls remain alive.
	# Rebuild added fields and signal targets together rather than using stale UI.
	if get_meta("ui_revision", 0) == UI_REVISION and is_instance_valid(card_style) and is_instance_valid(copy_button) and is_instance_valid(helper_view):
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
	if lesson_path == 2:
		code += "    var animator := TweenAnimation.new(self)\n"
	else:
		code += "    var tween := create_tween()\n"
	for operation in operations:
		code += "    # " + str(operation[2]) + "\n"
		if lesson_path == 2:
			code += '    await animator.custom(target, ^"%s", %s, 0.5).finished\n' % [operation[0], operation[1]]
		else:
			code += '    tween.tween_property(target, "%s", %s, 0.5)\n' % [operation[0], operation[1]]
	return {"title": "See what each property does", "body": explanation + "\n\nCopy the script, run the scene, and compare the results. Next step advances this guide; it does not change your scene.", "code": code}


func _build_code_lesson(node_path: String, property: String, end_value: String) -> void:
	var header := "# Attach this script to the scene root. Adjust the child path.\nextends Node\n\n@onready var target = " + node_path + "\n\n"
	var create := "var tween := create_tween()" if lesson_path == 1 else "var animator := TweenAnimation.new(self)"
	var animate := 'tween.tween_property(target, "%s", %s, 1.0)' % [property, end_value]
	var helper := 'var tween := animator.custom(target, ^"%s", %s, 1.0)' % [property, end_value]
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
	var sequence := basic + '    tween.tween_interval(0.2)\n    tween.tween_callback(func(): print("Animation finished!"))\n'
	var cancel := header + "var active_tween: Tween\n\nfunc _ready() -> void:\n    animate()\n\nfunc animate() -> void:\n    if active_tween and active_tween.is_running():\n        active_tween.kill()\n"
	if lesson_path == 1:
		cancel += '    active_tween = create_tween()\n    active_tween.tween_property(target, "%s", %s, 1.0)\n' % [property, end_value]
	else:
		cancel += '    var animator := TweenAnimation.new(self)\n    active_tween = animator.custom(target, ^"%s", %s, 1.0)\n' % [property, end_value]
	var api := "Godot's built-in Tween API" if lesson_path == 1 else "the add-on's TweenAnimation helper"
	steps = [
		{"title": "A little motion, all in code", "body": "[b]This path uses %s.[/b]\n\nCreate the matching child node, attach this script to its parent, and adjust the child path. Run the scene: _ready() creates the animation. No timeline resource is needed.\n\nThe property name is %s; the destination is %s. Duration is 1 second. The Tween starts at the property's current value." % [api, property, end_value], "code": basic},
		{"title": "Give the movement a feel", "body": "[b]Easing shapes the journey.[/b]\n\nSine easing makes the start and finish softer. Try a different transition, such as TRANS_BACK, and run again.\n\nNative defaults are linear. The helper defaults to Sine with Ease In/Out. Its custom() returns a Godot Tween; transition settings must be chosen before the property is added.", "code": eased},
		{"title": "Make one thing follow another", "body": "[b]Move → wait → celebrate.[/b]\n\nTween operations are sequential by default. This example waits briefly after the motion, then runs a callback. The helper also returns a normal Tween, so the same chaining works.\n\nFor completion in an async function, use await tween.finished. To run properties together, configure parallel mode before appending those property operations.", "code": sequence},
		{"title": "Handle another click gracefully", "body": "[b]One target, one active animation.[/b]\n\nStore the Tween so a new action can kill the old one before starting again. Connect a button or input action to animate() to try repeated triggers.\n\nCreate the helper with an owner inside the scene tree. Node.create_tween() binds the Tween lifetime to that owner. After a Tween finishes, create a new one to replay it.", "code": cancel}
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
			benefit = "[b]What the add-on saves:[/b] custom() centralizes owner and transition setup. 3D uses the same property names and Vector3 values; the helper does not add a separate 3D animation engine."
		elif selected_mode == 2:
			benefit = "[b]What the add-on saves:[/b] fade_to() supplies modulate:a and clamps alpha to 0–1. Native tween_property() can do the same thing explicitly."
		if example_index >= 2:
			benefit = "[b]Same Tween underneath:[/b] the helper returns a Godot Tween. Sequencing, callbacks, finished and kill() use Godot's existing API in both examples."
		if title == "See what each property does":
			steps[index]["native"] = native_properties["code"]
			steps[index]["helper"] = helper_properties["code"]
			benefit = "[b]Same properties, two entry points:[/b] custom() wraps tween_property(); the property names and values stay the same. Use the helper when its defaults and shared owner are convenient."
		if title == "Plant the first key":
			for api in ["native", "helper"]:
				steps[index][api] = str(steps[index][api]).replace("func _ready() -> void:\n", 'func _ready() -> void:\n    target.set_indexed(^"%s", %s) # Explicit starting value\n' % [property, start_value])
		steps[index]["comparison"] = benefit + "\n\n[b]Defaults:[/b] native Tween uses Linear / In-Out; Tweenimation uses Sine / In-Out. Set native transition/ease before tween_property() to match the helper. Both scripts are alternatives; run one at a time."
