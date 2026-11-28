@tool
extends VBoxContainer
## Shared read-only source placement preview. Clicking never edits source text.

signal placement_selected(index: int)
const WRITER = preload("res://addons/tween_animation/editor/tween_source_writer.gd")
const SYNTAX = preload("res://addons/tween_animation/editor/source_syntax.gd")
var editor: CodeEdit
var marker: Label
var side: OptionButton
var source := ""
var method: Dictionary = {}
var anchors: Array[Dictionary] = []
var selected := 0
var _updating := false
var _marked_line := -1
var _gutter := -1
var preview_start := -1
var preview_lines := 0
var global_start := -1
var global_lines := 0


func build() -> void:
	add_theme_constant_override("separation", 8)
	var tools := HBoxContainer.new()
	add_child(tools)
	var title := Label.new()
	title.text = "Pick a line"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(title)
	side = OptionButton.new()
	side.add_item("Insert before ↓")
	side.add_item("Insert after ↑")
	side.item_selected.connect(func(_index: int): _pick_line())
	side.hide()
	tools.add_child(side)
	editor = CodeEdit.new()
	editor.editable = false
	editor.gutters_draw_line_numbers = true
	editor.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	editor.add_gutter()
	_gutter = editor.get_gutter_count() - 1
	editor.set_gutter_type(_gutter, TextEdit.GUTTER_TYPE_STRING)
	editor.set_gutter_width(_gutter, 24)
	editor.custom_minimum_size = Vector2(0, 250)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.caret_changed.connect(_pick_line)
	editor.tooltip_text = "Click a code line to choose a gap. Existing code is preserved. Multiline statements stay together."
	add_child(editor)
	var foreground := EditorInterface.get_base_control().get_theme_color("font_color", "Label")
	editor.add_theme_color_override("font_readonly_color", foreground)
	var syntax := CodeHighlighter.new()
	syntax.symbol_color = foreground
	syntax.member_variable_color = foreground
	syntax.number_color = Color("a8d6a0")
	syntax.function_color = Color("8bc9ef")
	syntax.add_color_region('"', '"', Color("e8ca95"))
	syntax.add_color_region("#", "", Color("94a3b8"), true)
	syntax.add_color_region("//", "", Color("94a3b8"), true)
	for keyword in ["var", "func", "extends", "await", "if", "return", "public", "private", "void", "new", "class"]:
		syntax.add_keyword_color(keyword, Color("c8a6e6"))
	editor.syntax_highlighter = syntax
	marker = Label.new()
	marker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	marker.custom_minimum_size.x = 280
	marker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marker.modulate = Color("92d6b0")
	add_child(marker)


func configure(text: String, chosen_method: Dictionary, locations: Array[Dictionary], index: int) -> void:
	preview_start = -1
	preview_lines = 0
	global_start = -1
	global_lines = 0
	source = text
	method = chosen_method
	anchors = locations
	_updating = true
	editor.text = text
	_marked_line = -1
	_updating = false
	select_anchor(index)


func select_anchor(index: int) -> void:
	if index < 0 or index >= anchors.size():
		return
	selected = index
	var anchor: Dictionary = anchors[index]
	var location := WRITER.location(source, method, anchor)
	if not location.ok:
		marker.text = location.error
		return
	var line := clampi(SYNTAX.line_at(source, location.offset) - 1, 0, editor.get_line_count() - 1)
	_updating = true
	if _marked_line >= 0:
		editor.set_line_background_color(_marked_line, Color.TRANSPARENT)
		editor.set_line_gutter_text(_marked_line, _gutter, "")
	_marked_line = line
	editor.set_line_background_color(line, Color(0.3, 0.65, 1.0, 0.22))
	editor.set_line_gutter_text(line, _gutter, "↱" if anchor.kind == "after" else "↳")
	editor.set_line_gutter_item_color(line, _gutter, Color("92d6b0"))
	editor.set_caret_line(line)
	editor.center_viewport_to_caret()
	if anchor.kind in ["before", "after"]:
		side.select(1 if anchor.kind == "after" else 0)
	_updating = false
	marker.text = ("↑ Insert after line %d" if anchor.kind == "after" else "↓ Insert before line %d") % (line + 1)
	if anchor.kind in ["start", "end"]:
		marker.text = "◆ " + str(anchor.label)
	marker.text += "  ·  Existing code moves down; nothing is replaced."


func _pick_line() -> void:
	if _updating or method.is_empty():
		return
	var line := editor.get_caret_line()
	if preview_start >= 0:
		if line >= preview_start and line < preview_start + preview_lines:
			return
		if line >= preview_start + preview_lines:
			line -= preview_lines
	if global_start >= 0:
		if line >= global_start and line < global_start + global_lines:
			return
		if line >= global_start + global_lines:
			line -= global_lines
	choose_line(line, false)


func choose_line(line: int, after: bool = false) -> void:
	var first := SYNTAX.line_at(source, method.body) - 1
	var last := SYNTAX.line_at(source, maxi(method.body, method.end - 1)) - 1
	if line < first or line > last:
		marker.text = "Choose a line inside " + str(method.name) + "(), or change the method above."
		return
	if line == first and anchors[0].kind == "start":
		select_anchor(0)
		placement_selected.emit(0)
		return
	var kind := "after" if after else "before"
	var best := -1
	var distance := 2147483647
	for index in anchors.size():
		var anchor: Dictionary = anchors[index]
		if anchor.kind != kind:
			continue
		for statement in method.statements:
			if statement.start != anchor.start:
				continue
			var start := int(statement.line) - 1
			var end := SYNTAX.line_at(source, statement.end) - 1
			var gap := 0 if line >= start and line <= end else absi(start - line)
			if gap < distance:
				best = index
				distance = gap
	if best < 0:
		best = 0 if line <= first else anchors.size() - 1
	select_anchor(best)
	placement_selected.emit(best)


func show_generated(text: String, offset: int, added_length: int, global_offset: int = -1, added_global_lines: int = 0) -> void:
	_updating = true
	editor.text = text
	preview_start = SYNTAX.line_at(text, offset) - 1
	global_start = SYNTAX.line_at(source, global_offset) - 1 if global_offset >= 0 else -1
	global_lines = added_global_lines
	preview_lines = text.substr(offset, added_length).count("\n")
	for line in range(preview_start, mini(preview_start + preview_lines, editor.get_line_count())):
		editor.set_line_background_color(line, Color(0.3, 0.65, 1.0, 0.2))
	editor.set_caret_line(preview_start)
	editor.center_viewport_to_caret()
	_updating = false
