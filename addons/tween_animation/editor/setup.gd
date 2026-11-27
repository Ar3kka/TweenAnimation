@tool
extends VBoxContainer
## In-editor onboarding. Examples are displayed as text and never executed.

signal start_requested(mode: String)
signal open_requested

const MODES := ["2D", "3D", "UI"]
var mode_picker: OptionButton
var guide: RichTextLabel
var code_view: CodeEdit
var start_button: Button


func build(logo_texture: Texture2D) -> void:
	name = "Setup"
	add_theme_constant_override("separation", 12)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	add_child(header)
	var logo := TextureRect.new()
	logo.texture = logo_texture
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(120, 40)
	header.add_child(logo)
	var title := Label.new()
	title.text = "Welcome to Tweenimation"
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)
	var intro := Label.new()
	intro.text = "Choose your target, follow the guide, then build your animation in the Timeline tab."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(intro)
	mode_picker = OptionButton.new()
	for mode in MODES:
		mode_picker.add_item(mode + " animation")
	mode_picker.item_selected.connect(_show_guide)
	add_child(mode_picker)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	add_child(actions)
	start_button = Button.new()
	start_button.custom_minimum_size.y = 36
	start_button.pressed.connect(func(): start_requested.emit(MODES[mode_picker.selected]))
	actions.add_child(start_button)
	var open_button := Button.new()
	open_button.text = "Open existing Animation (.tres)…"
	open_button.custom_minimum_size.y = 36
	open_button.pressed.connect(func(): open_requested.emit())
	actions.add_child(open_button)
	guide = RichTextLabel.new()
	guide.bbcode_enabled = true
	guide.fit_content = true
	guide.scroll_active = false
	guide.selection_enabled = true
	add_child(guide)
	var code_title := Label.new()
	code_title.text = "CODE EXAMPLES · Select and copy the parts you need"
	add_child(code_title)
	code_view = CodeEdit.new()
	code_view.editable = false
	code_view.custom_minimum_size.y = 250
	code_view.gutters_draw_line_numbers = true
	add_child(code_view)
	_show_guide(0)


func _show_guide(index: int) -> void:
	var mode: String = MODES[index]
	start_button.text = "Set up " + mode + " animation →"
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
