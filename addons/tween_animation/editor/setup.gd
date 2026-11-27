@tool
extends MarginContainer
## Centered landing menu with tutorials shown only after choosing a target.

signal start_requested(mode: String)
signal open_requested

const MODES := ["2D", "3D", "UI"]
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


func build(logo_texture: Texture2D) -> void:
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
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	progress = _text("", 13)
	body.add_child(progress)
	var progress_style := StyleBoxFlat.new()
	progress_style.bg_color = Color(0.16, 0.18, 0.21)
	progress_style.content_margin_left = 20
	progress_style.content_margin_right = 20
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
	card_body.add_child(guide)

	code_view = CodeEdit.new()
	code_view.editable = false
	code_view.custom_minimum_size.y = 250
	code_view.gutters_draw_line_numbers = true
	card_body.add_child(code_view)
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
			start_requested.emit(MODES[selected_mode])
		else:
			_change_step(1)
	)
	navigation.add_child(next_button)
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
	code_view.text = ("# Attach to the scene root; add AnimationPlayer as a child.\n" +
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

	step_index = 0
	_render_step()


func _change_step(direction: int) -> void:
	step_index = clampi(step_index + direction, 0, steps.size() - 1)
	_render_step()


func _render_step() -> void:
	progress.text = MODES[selected_mode] + " QUEST   ·   STEP %d OF %d   " % [step_index + 1, steps.size()]
	for index in steps.size():
		progress.text += "●  " if index <= step_index else "○  "
	step_title.text = str(steps[step_index]["title"])
	guide.text = str(steps[step_index]["body"])
	visual.set("mode", selected_mode)
	visual.set("step", step_index)
	visual.set("elapsed", 0.0)
	code_view.visible = step_index == 5
	reuse_button.visible = step_index == 6
	previous.disabled = step_index == 0
	next_button.text = "Let's animate →" if step_index == steps.size() - 1 else "Next step →"
	details.scroll_vertical = 0
