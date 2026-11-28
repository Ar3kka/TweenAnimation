@tool
extends EditorPlugin

const ADDON_ICON := preload("res://addons/tween_animation/icon.svg")
const HEADER_LOGO := preload("res://addons/tween_animation/header_logo.svg")

var frame: MarginContainer
var tabs: TabContainer
var code_timeline
var content_mode := 0
var content_mode_buttons: Array[Button] = []
var navigation_buttons: Array[Button] = []


func _enter_tree() -> void:
	_build_ui()
	get_editor_interface().get_editor_main_screen().add_child(frame)
	set_process(true)
	_make_visible(false)
	get_editor_interface().get_selection().selection_changed.connect(_selection_changed)
	_selection_changed()


func _exit_tree() -> void:
	var selection := get_editor_interface().get_selection()
	if selection.selection_changed.is_connected(_selection_changed):
		selection.selection_changed.disconnect(_selection_changed)
	if is_instance_valid(frame):
		frame.queue_free()


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "Tweenimation"


func _get_plugin_icon() -> Texture2D:
	return ADDON_ICON


func _make_visible(visible: bool) -> void:
	if is_instance_valid(frame):
		frame.visible = visible
		if visible:
			_selection_changed()


func _process(_delta: float) -> void:
	pass


func _build_ui() -> void:
	frame = MarginContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.theme = get_editor_interface().get_base_control().theme
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 12)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	frame.add_child(layout)
	_build_navigation_bar(layout)
	tabs = TabContainer.new()
	tabs.tabs_visible = false
	tabs.tab_changed.connect(_sync_navigation_buttons)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	var setup := preload("res://addons/tween_animation/editor/setup.gd").new()
	setup.build(HEADER_LOGO)
	setup.start_requested.connect(_start_setup)
	setup.code_start_requested.connect(_open_timeline)
	setup.open_requested.connect(_open_timeline)
	tabs.add_child(setup)
	var timeline_scroll := ScrollContainer.new()
	timeline_scroll.name = "Timeline"
	timeline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(timeline_scroll)
	code_timeline = preload("res://addons/tween_animation/editor/code_timeline.gd").new()
	code_timeline.build(self)
	timeline_scroll.add_child(code_timeline)
	var documentation := preload("res://addons/tween_animation/editor/documentation.gd").new()
	documentation.build()
	tabs.add_child(documentation)
	tabs.set_tab_icon(0, _editor_icon("Node"))
	tabs.set_tab_icon(1, ADDON_ICON)
	tabs.set_tab_icon(2, _editor_icon("Help"))
	tabs.current_tab = 0
	_set_content_mode(content_mode)
	_sync_navigation_buttons(tabs.current_tab)


func _start_setup(mode: String) -> void:
	_open_timeline()


func _open_timeline() -> void:
	tabs.current_tab = 1
	_sync_navigation_buttons(1)
	_selection_changed()
	code_timeline.rescan()


func _selection_changed() -> void:
	if not is_instance_valid(code_timeline):
		return
	var nodes := get_editor_interface().get_selection().get_selected_nodes()
	code_timeline.set_node(nodes[0] if not nodes.is_empty() else null)


func _set_content_mode(index: int) -> void:
	content_mode = clampi(index, 0, 2)
	if is_instance_valid(code_timeline):
		code_timeline.set_content_mode(content_mode)
	for item in content_mode_buttons.size():
		content_mode_buttons[item].set_pressed_no_signal(item == content_mode)
	if tabs != null and tabs.get_tab_count() == 3:
		tabs.get_child(0).call("set_content_mode", content_mode)
		tabs.get_child(2).call("set_content_mode", content_mode)


func _build_navigation_bar(layout: VBoxContainer) -> void:
	var editor := get_editor_interface().get_base_control()
	var bar := PanelContainer.new()
	var background := StyleBoxFlat.new()
	background.bg_color = editor.get_theme_color("dark_color_1", "Editor")
	background.content_margin_left = 6
	background.content_margin_right = 6
	background.content_margin_top = 4
	background.content_margin_bottom = 4
	background.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("panel", background)
	layout.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	var pages := HBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.alignment = BoxContainer.ALIGNMENT_CENTER
	pages.add_theme_constant_override("separation", 2)
	row.add_child(pages)
	var page_group := ButtonGroup.new()
	for index in range(3):
		var button := Button.new()
		button.text = ["Setup", "Timeline", "Documentation"][index]
		button.icon = [_editor_icon("Node"), ADDON_ICON, _editor_icon("Help")][index]
		button.toggle_mode = true
		button.button_group = page_group
		button.pressed.connect(_select_page.bind(index))
		_style_bar_button(button, index, false)
		navigation_buttons.append(button)
		pages.add_child(button)
	row.add_child(VSeparator.new())
	var segments := HBoxContainer.new()
	segments.add_theme_constant_override("separation", 0)
	row.add_child(segments)
	var mode_group := ButtonGroup.new()
	for index in range(3):
		var button := Button.new()
		button.text = ["GDScript", "C#", "Visual Timeline"][index]
		button.toggle_mode = true
		button.button_group = mode_group
		button.tooltip_text = "Show " + button.text + " content in Tutorials and Documentation"
		button.pressed.connect(_set_content_mode.bind(index))
		_style_bar_button(button, index, true)
		content_mode_buttons.append(button)
		segments.add_child(button)


func _style_bar_button(button: Button, index: int, segmented: bool) -> void:
	var editor := get_editor_interface().get_base_control()
	var accent := editor.get_theme_color("accent_color", "Editor")
	var base := editor.get_theme_color("dark_color_2", "Editor")
	var normal := StyleBoxFlat.new()
	normal.bg_color = base if segmented else Color.TRANSPARENT
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	if segmented:
		normal.border_color = editor.get_theme_color("font_color", "Editor") * Color(1, 1, 1, 0.2)
		normal.set_border_width_all(1)
		normal.corner_radius_top_left = 5 if index == 0 else 0
		normal.corner_radius_bottom_left = 5 if index == 0 else 0
		normal.corner_radius_top_right = 5 if index == 2 else 0
		normal.corner_radius_bottom_right = 5 if index == 2 else 0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = base.lerp(accent, 0.2)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent if segmented else base
	pressed.border_color = accent
	pressed.border_width_bottom = 3
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	var active_text := (Color.BLACK if accent.get_luminance() > 0.179 else Color.WHITE) if segmented else accent
	button.add_theme_color_override("font_pressed_color", active_text)
	button.add_theme_color_override("font_hover_pressed_color", active_text)
	button.add_theme_color_override("icon_pressed_color", active_text)
	button.add_theme_color_override("icon_hover_pressed_color", active_text)


func _select_page(index: int) -> void:
	tabs.current_tab = index
	_sync_navigation_buttons(index)


func _sync_navigation_buttons(index: int) -> void:
	for item in navigation_buttons.size():
		navigation_buttons[item].set_pressed_no_signal(item == index)


func _editor_icon(name: String) -> Texture2D:
	var editor := get_editor_interface().get_base_control()
	return editor.get_theme_icon(name, "EditorIcons") if editor.has_theme_icon(name, "EditorIcons") else null
