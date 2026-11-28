@tool
extends VBoxContainer
## Live context for the visual guide. Actions open the actual timeline workspace.
signal workspace_requested(add_tween: bool)
var selected_node: Node
var step := 0
var target_mode := 0
var stage: VBoxContainer

func build() -> void:
	stage = VBoxContainer.new()
	stage.add_theme_constant_override("separation", 12)
	add_child(stage)

func set_node(node: Node) -> void:
	selected_node = node
	if is_instance_valid(stage):
		configure(target_mode, step)

func configure(mode: int, phase: int) -> void:
	target_mode = mode
	step = phase
	for child in stage.get_children():
		stage.remove_child(child)
		child.queue_free()
	var has_node := is_instance_valid(selected_node)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var editor := EditorInterface.get_base_control()
	style.bg_color = editor.get_theme_color("dark_color_2", "Editor")
	style.border_color = editor.get_theme_color("font_color", "Label") * Color(1, 1, 1, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	stage.add_child(panel)
	var context := VBoxContainer.new()
	context.add_theme_constant_override("separation", 6)
	panel.add_child(context)
	var title := Label.new()
	title.text = "Editing: " + str(selected_node.name) if has_node else "Editing: no node selected in Godot"
	title.add_theme_font_size_override("font_size", 20)
	context.add_child(title)
	var detail := Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.text = selected_node.get_class() + " · " + str(selected_node.get_path()) if has_node else "The timeline follows Godot's Scene tree selection. Its node name will appear here automatically."
	context.add_child(detail)
	var flow := Label.new()
	flow.text = ["GODOT SCENE TREE  →  CURRENT TARGET", "ADD TWEEN  →  LOCATION", "CONFIGURATION  →  ANIMATED PROPERTY  →  VALUE", "CONFIGURATION  →  DURATION / WAIT / SEQUENCE", "TIMELINE BAR  →  PARAMETERS  →  APPLY", "RUN SCENE  →  CHECK RESULT  →  REFINE"][clampi(step, 0, 5)]
	flow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flow.modulate.a = 0.75
	stage.add_child(flow)
	var explanation := Label.new()
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.text = [
		"This node is the target of the timeline edits. Choose another node in Godot's Scene tree whenever you want to change the target; this card and the Timeline tab update together.",
		"Open Add Tween. Under Location, Run inside method chooses when the game runs the animation. Click a statement in that method: the new lines appear above it and the original code moves down. All generated lines are highlighted, including a new script-level Tweenimator.",
		"Under Configuration, choose Godot Tween or Tweenimator. Tweenimator defaults to a new script instance outside methods; the Tween name stores the returned Tween in that instance. Animated property chooses what changes. Offset adds to the node's value when called; Value supplies an absolute destination; Method parameter uses a value supplied by gameplay.",
		"Duration is movement time. Wait is a hold afterwards. Independent creates its own Tween. Join earlier top-level Tween appends to a recognized preceding sequence in this method when available; otherwise it creates its own. Add Tween commits the highlighted source and refreshes the map. Close the dialog to cancel without saving.",
		"In Timeline, click one of this node's bars to inspect its method, source line and parameters. Change the supported fields and press Apply parameters to source. Move this call changes its location inside the method. Source line is optional; it opens the code for developers who want to inspect it.",
		"Run the scene to see the actual animation. The method you chose must be called by the game: _ready runs on entering the scene, while a button handler runs on that signal. Each method invocation is its own sequence. Runtime labels mean branches or computed values prevent exact timing from being known in the editor."
	][clampi(step, 0, 5)]
	stage.add_child(explanation)
	var action := Button.new()
	action.text = "Open Add Tween for " + str(selected_node.name) if has_node and step in [1, 2, 3] else "Open Timeline"
	action.icon = editor.get_theme_icon("Add" if step in [1, 2, 3] else "Animation", "EditorIcons")
	action.disabled = not has_node
	action.pressed.connect(func(): workspace_requested.emit(step in [1, 2, 3]))
	stage.add_child(action)
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "These actions open the real workspace for the node shown above. Next and Back only change the explanation; they do not edit your scene or unlock controls."
	note.modulate.a = 0.7
	stage.add_child(note)
