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
	guide = RichTextLabel.new()
	guide.bbcode_enabled = true
	guide.fit_content = true
	guide.scroll_active = false
	guide.selection_enabled = true
	body.add_child(guide)
	body.add_child(_text("CODE EXAMPLES · Select and copy", 14))
	code_view = CodeEdit.new()
	code_view.editable = false
	code_view.custom_minimum_size.y = 250
	code_view.gutters_draw_line_numbers = true
	body.add_child(code_view)
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
	guide.text = ("[b]%s · Target and differences[/b]\n%s\n%s\n\n" +
		"[b]Create your first animation[/b]\n" +
		"1. Open a scene and select a %s node.\n" +
		"2. Choose Set up above. In Timeline, add the property [code]%s[/code].\n" +
		"3. At 0 seconds, type [code]%s[/code] and Capture key.\n" +
		"4. Scrub to 1 second, type [code]%s[/code] and Capture key again.\n" +
		"5. Play preview, then Save as a .tres resource. Blank Value captures the node's current value.\n\n" +
		"[b]See the preview[/b]\n" +
		"Preview writes properties into the open scene. Switch to Godot's 2D/3D view while playback continues to see it; return here to pause. There is no embedded scene viewport. Preview currently leaves the last sampled values on the nodes.\n\n" +
		"[b]Use the saved animation in code[/b]\n" +
		"Add an AnimationPlayer under the same scene root used when authoring. Its default root_node (..) resolves tracks from that root. The first example below loads your saved resource into an AnimationLibrary. Adjust paths to your scene.\n\n" +
		"[b]Connect existing work[/b]\n" +
		"• Existing .tres Animation: use Open above; its node paths must resolve from the open scene root. Value tracks are supported for editing and preview.\n" +
		"• AnimationPlayer animation: save that Animation resource as .tres from Godot's resource inspector, then Open it here.\n" +
		"• Existing create_tween()/tween_property() code: keep using that code, or recreate its property, start/end values and duration as timeline keys. Running Tweens cannot be imported or linked as tracks.\n" +
		"• TweenAnimation helper: custom() accepts 2D, 3D and UI properties. move/scale/rotate/wiggle shortcuts currently accept Node2D; fade helpers accept CanvasItem.\n\n" +
		"[b]Timeline scope[/b]\nSaved output is a standard Godot Animation. Runtime Tween easing and chained/parallel calls are not automatically copied into it.\n") % [mode, target, differences, mode, property, start_value, end_value]
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
