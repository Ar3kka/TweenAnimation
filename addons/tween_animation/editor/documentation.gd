@tool
extends HSplitContainer
## Searchable in-editor reference. Signatures are read from the runtime source.

const DATA := preload("res://addons/tween_animation/editor/documentation_data.gd")
const RUNTIME := preload("res://addons/tween_animation/src/tweenimator.gd")
var entries: Dictionary = {}
var search: LineEdit
var category: OptionButton
var navigation: ItemList
var results: Label
var scroll: ScrollContainer
var content: VBoxContainer
var current_key := ""
var kind_tabs: TabBar
var visible_items: Array[int] = []
var target_filter: OptionButton
var content_mode := 0

const PARAMETER_HELP := {
	"name": "Non-empty StringName used as a key in this Tweenimator's registry.",
	"owner": "Optional Node owner; it must be in the tree when creating a Tween. create() uses this explicit owner or the manager default.",
	"tween": "A valid Godot Tween, whether created here or in external code.",
	"target": "The object receiving the effect. Spatial effects accept Node2D, Node3D or Control; see the signature and notes for narrower target types.",
	"duration": "Duration in seconds. Must be finite and non-negative; the signature shows this effect's default. For wiggle this is the total duration.",
	"interval": "Optional wait in seconds after the entire effect. Defaults to 0.0 (no wait). Must be finite and non-negative. It belongs to the returned Tween, so sequential callbacks, finished, and named cleanup wait for it too."
}


func build() -> void:
	name = "Documentation"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_offset = 260
	entries = DATA.SOURCE.duplicate(true)
	entries.merge(DATA.ITEMS.duplicate(true))
	_read_signatures()
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 220
	sidebar.add_theme_constant_override("separation", 10)
	add_child(sidebar)
	sidebar.add_child(_label("Tweenimator reference", 19))
	search = LineEdit.new()
	search.placeholder_text = "Search functions or topics…"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_text: String): _filter())
	sidebar.add_child(search)
	kind_tabs = TabBar.new()
	for kind in ["All", "Guides", "Functions"]:
		kind_tabs.add_tab(kind)
	kind_tabs.tab_changed.connect(func(_index: int): _filter())
	sidebar.add_child(kind_tabs)
	category = OptionButton.new()
	category.add_item("All sections")
	for group in ["Start here", "Configuration", "Setup", "Named registry", "Playback", "Movement", "Transform", "Effects", "Advanced"]:
		category.add_item(group)
	category.item_selected.connect(func(_index: int): _filter())
	sidebar.add_child(category)
	target_filter = OptionButton.new()
	for target_type in ["All targets", "2D", "3D", "UI", "Audio", "Shader resources", "Callbacks"]:
		target_filter.add_icon_item(_target_icon(target_type), target_type)
	target_filter.item_selected.connect(func(_index: int): _filter())
	sidebar.add_child(target_filter)
	results = _label("", 12)
	sidebar.add_child(results)
	navigation = ItemList.new()
	navigation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation.item_selected.connect(func(index: int):
		if navigation.get_item_metadata(index) != null:
			_show_entry(str(navigation.get_item_metadata(index)))
	)
	sidebar.add_child(navigation)
	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)
	_filter()


func _read_signatures() -> void:
	var pattern := RegEx.new()
	pattern.compile("(?m)^func ([a-z_]+)\\((.*)\\) -> ([^:]+):")
	var runtime_script: Script = RUNTIME
	for matched in pattern.search_all(runtime_script.get_source_code()):
		var key := matched.get_string(1)
		if key.begins_with("_") and key != "_init":
			continue
		if key == "_init":
			key = "new"
		if not entries.has(key):
			continue
		entries[key]["signature"] = key + "(" + matched.get_string(2) + ") → " + ("Tweenimator" if key == "new" else matched.get_string(3))
		entries[key]["args"] = matched.get_string(2).split(",", false)


func _filter() -> void:
	navigation.clear()
	visible_items.clear()
	var query := search.text.strip_edges().to_lower()
	var chosen := category.get_item_text(category.selected)
	var last_section := ""
	for key in entries:
		var item: Dictionary = entries[key]
		if bool(item.get("visual_only", false)) != (content_mode == 2):
			continue
		var is_guide := str(key).begins_with("guide_")
		var target_type := target_filter.get_item_text(target_filter.selected)
		if target_filter.selected > 0 and not "Any Tween" in item["targets"] and not target_type in item["targets"]:
			continue
		if (kind_tabs.current_tab == 1 and not is_guide) or (kind_tabs.current_tab == 2 and is_guide):
			continue
		if category.selected > 0 and item["group"] != chosen:
			continue
		if not query.is_empty() and not (str(key) + " " + str(item)).to_lower().contains(query):
			continue
		var section := "GUIDES · HOW TO" if is_guide else ("CONTROLS · TIMELINE" if content_mode == 2 else "FUNCTIONS · API")
		if section != last_section:
			var heading := navigation.add_item(section, null, false)
			navigation.set_item_disabled(heading, true)
			navigation.set_item_custom_fg_color(heading, _kind_color(is_guide))
			last_section = section
		var index := navigation.add_item(str(item["title"]), _kind_icon(is_guide))
		navigation.set_item_icon_modulate(index, _kind_color(is_guide))
		navigation.set_item_metadata(index, key)
		navigation.set_item_tooltip(index, ("Workflow guide" if is_guide else ("Timeline control" if content_mode == 2 else "Function reference")) + " · " + str(item["summary"]))
		visible_items.append(index)
	results.text = "%d entries" % visible_items.size()
	if not visible_items.is_empty():
		var selected := visible_items[0]
		for index in visible_items:
			if str(navigation.get_item_metadata(index)) == current_key:
				selected = index
		navigation.select(selected)
		_show_entry(str(navigation.get_item_metadata(selected)))
	else:
		_clear_content()
		content.add_child(_label("No matching entries", 24))
		content.add_child(_label("Try another word, section, target or entry type.", 17))


func _clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()


func _show_entry(key: String) -> void:
	current_key = key
	_clear_content()
	var item: Dictionary = entries[key]
	var is_guide := key.begins_with("guide_")
	var kind := ("VISUAL GUIDE" if is_guide else "TIMELINE CONTROL") if content_mode == 2 else ("WORKFLOW GUIDE" if is_guide else "FUNCTION REFERENCE")
	var badge := _label(kind + "  /  " + str(item["group"]).to_upper(), 12)
	badge.modulate = _kind_color(is_guide)
	content.add_child(badge)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.texture = _kind_icon(is_guide)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(28, 28)
	icon.modulate = _kind_color(is_guide)
	heading.add_child(icon)
	var title := _label(str(item["title"]), 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	content.add_child(_card(heading, _kind_color(is_guide)))
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 8)
	tags.add_theme_constant_override("v_separation", 6)
	for target_type in item["targets"]:
		var tag := HBoxContainer.new()
		tag.add_theme_constant_override("separation", 7)
		var target_icon := TextureRect.new()
		target_icon.texture = _target_icon(str(target_type))
		target_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		target_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		target_icon.custom_minimum_size = Vector2(20, 20)
		tag.add_child(target_icon)
		var target_name := _label(str(target_type), 14)
		target_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		tag.add_child(target_name)
		tags.add_child(_card(tag, _kind_color(is_guide)))
	content.add_child(tags)
	content.add_child(_label(str(item["target_note"]), 15))
	content.add_child(_label(str(item["summary"]), 17))
	if content_mode == 2:
		var practice = preload("res://addons/tween_animation/editor/source_walkthrough.gd").new()
		practice.build()
		var target_mode := 1 if target_filter.get_item_text(target_filter.selected) == "3D" else (2 if target_filter.get_item_text(target_filter.selected) == "UI" else 0)
		practice.configure(target_mode, item.get("source_phase", 1))
		content.add_child(practice)
		var number := 1
		for instruction in item["steps"]:
			content.add_child(_card(_label(str(number) + ".  " + str(instruction), 18), _kind_color(is_guide)))
			number += 1
		if not str(item["notes"]).is_empty():
			content.add_child(_label(str(item["notes"]), 16))
		scroll.scroll_vertical = 0
		return
	if item.has("signature"):
		if content_mode == 1:
			content.add_child(_label("RUNTIME SIGNATURE · Call this GDScript API through GodotObject.Call()", 13))
		var signature := _label(str(item["signature"]), 15)
		signature.add_theme_font_override("font", EditorInterface.get_base_control().get_theme_font("source", "EditorFonts"))
		content.add_child(_card(signature))
		var arguments: PackedStringArray = item["args"]
		content.add_child(_label("PARAMETERS", 13))
		if arguments.is_empty():
			content.add_child(_label("No parameters.", 16))
		else:
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 18)
			grid.add_theme_constant_override("v_separation", 12)
			for argument in arguments:
				var param_name := str(argument).get_slice(":", 0).strip_edges()
				var label := _label(param_name, 16)
				label.custom_minimum_size.x = 90
				grid.add_child(label)
				var description := str(item["params"].get(param_name, PARAMETER_HELP.get(param_name, "See the typed signature and notes for accepted values.")))
				var help := _label(description, 16)
				help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.add_child(help)
			content.add_child(_card(grid))
	if not str(item["returns"]).is_empty():
		content.add_child(_label("RETURNS", 13))
		content.add_child(_label(str(item["returns"]), 16))
	if not str(item["notes"]).is_empty():
		content.add_child(_label("BEHAVIOR & OPTIONS", 13))
		content.add_child(_label(str(item["notes"]), 16))
	content.add_child(HSeparator.new())
	var examples := preload("res://addons/tween_animation/editor/tutorial_examples.gd")
	_add_example(str(item["csharp"]) if content_mode == 1 else examples.documentation(str(item["code"]), key == "guide_setup" or key == "guide_external"))
	scroll.scroll_vertical = 0


func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _card(child: Control, accent: Color = Color.TRANSPARENT) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = EditorInterface.get_base_control().get_theme_color("dark_color_1", "Editor")
	style.set_corner_radius_all(6)
	if accent.a > 0.0:
		style.border_color = EditorInterface.get_base_control().get_theme_color("font_color", "Label") * Color(1, 1, 1, 0.25)
		style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(child)
	return panel


func _add_example(source: String) -> void:
	source = preload("res://addons/tween_animation/editor/snippet_format.gd").prepare(source, content_mode == 1)
	var body := VBoxContainer.new()
	content.add_child(_card(body))
	var header := HBoxContainer.new()
	body.add_child(header)
	var label := _label("FOCUSED EXAMPLE", 13)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var copy := Button.new()
	copy.icon = EditorInterface.get_base_control().get_theme_icon("ActionCopy", "EditorIcons")
	copy.tooltip_text = "Copy complete example"
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(source)
		copy.icon = EditorInterface.get_base_control().get_theme_icon("StatusSuccess", "EditorIcons")
		copy.tooltip_text = "Copied!"
	)
	header.add_child(copy)
	var view := CodeEdit.new()
	view.editable = false
	view.text = source
	view.gutters_draw_line_numbers = true
	view.custom_minimum_size.y = 0
	# Let the outer page scroll; don't crop a complete example inside a fixed box.
	view.scroll_fit_content_height = true
	var background := EditorInterface.get_base_control().get_theme_color("dark_color_2", "Editor")
	var dark := background.get_luminance() < 0.5
	var foreground := Color("dce4ef") if dark else Color("202733")
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
	syntax.add_color_region("//" if content_mode == 1 else "#", "", Color("a5afbe") if dark else Color("546070"), true)
	for keyword in ["extends", "var", "func", "await", "if", "for", "in", "return", "using", "public", "private", "partial", "readonly", "class", "void", "new", "null", "false", "true"]:
		syntax.add_keyword_color(keyword, Color("d4b8f4") if dark else Color("663795"))
	view.syntax_highlighter = syntax
	var context := "Use these lines in your existing Node script. Calls run inside a method; function definitions remain at script scope. Unless shown, tweenimator is a shared Tweenimator.new(self) instance. Adjust $node paths to your scene."
	if content_mode == 1:
		context = "C# requires Godot .NET and using Godot;. Add fields/methods inside an existing Node class. _tweenimator is a GodotObject loaded from tweenimator.gd; use the setup guide to initialize it. Call() accesses the same runtime, not a separate C# port."
	body.add_child(_label(context, 14))
	body.add_child(view)


func _kind_color(is_guide: bool) -> Color:
	var editor := EditorInterface.get_base_control()
	if not is_guide:
		return editor.get_theme_color("accent_color", "Editor")
	return Color("72d7bb") if editor.get_theme_color("dark_color_2", "Editor").get_luminance() < 0.5 else Color("147257")


func _kind_icon(is_guide: bool) -> Texture2D:
	var editor := EditorInterface.get_base_control()
	var name := "Help" if is_guide else "GDScript"
	return editor.get_theme_icon(name if editor.has_theme_icon(name, "EditorIcons") else "Node", "EditorIcons")


func _target_icon(target_type: String) -> Texture2D:
	var editor := EditorInterface.get_base_control()
	var icon_name: String = {"2D": "Node2D", "3D": "Node3D", "UI": "Control", "Audio": "AudioStreamPlayer", "Shader resources": "ShaderMaterial", "Callbacks": "Callable", "Any Tween": "Tween"}.get(target_type, "Node")
	return editor.get_theme_icon(icon_name if editor.has_theme_icon(icon_name, "EditorIcons") else "Node", "EditorIcons")


func set_content_mode(value: int) -> void:
	var old_mode := content_mode
	content_mode = clampi(value, 0, 2)
	if (old_mode == 2) != (content_mode == 2):
		category.clear()
		category.add_item("All sections")
		var groups := ["Visual guides", "Timeline controls"] if content_mode == 2 else ["Start here", "Configuration", "Setup", "Named registry", "Playback", "Movement", "Transform", "Effects", "Advanced"]
		for group in groups:
			category.add_item(group)
		category.select(0)
		target_filter.clear()
		for target_type in (["All targets", "2D", "3D", "UI"] if content_mode == 2 else ["All targets", "2D", "3D", "UI", "Audio", "Shader resources", "Callbacks"]):
			target_filter.add_icon_item(_target_icon(target_type), target_type)
		target_filter.select(0)
		kind_tabs.set_tab_title(2, "Controls" if content_mode == 2 else "Functions")
		kind_tabs.current_tab = 0
		search.clear()
		current_key = ""
	_filter()
