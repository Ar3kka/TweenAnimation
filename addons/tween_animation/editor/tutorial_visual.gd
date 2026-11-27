@tool
extends Control
## A schematic illustration only; never changes the user's scene.

var mode := 0
var step := 0
var elapsed := 0.0
var caption := "READ  →  TRY  →  CONTINUE"


func _process(delta: float) -> void:
	if is_visible_in_tree():
		elapsed += delta
		queue_redraw()


func _draw() -> void:
	var accent: Color = [Color("78b9ff"), Color("ff8f91"), Color("8fdfb3")][mode]
	var foreground := get_theme_color("font_color", "Label")
	var subdued := foreground
	subdued.a = 0.16
	var stage_width := minf(380.0, size.x - 80)
	var left := Vector2((size.x - stage_width) / 2.0, 65)
	var right := Vector2((size.x + stage_width) / 2.0, 65)
	var fraction := (sin(elapsed * 2.0 - PI / 2.0) + 1.0) / 2.0 if step >= 1 else 0.0
	var stage := StyleBoxFlat.new()
	stage.bg_color = Color(accent, 0.035)
	stage.border_color = Color(accent, 0.12)
	stage.set_border_width_all(1)
	stage.set_corner_radius_all(10)
	draw_style_box(stage, Rect2(Vector2(left.x - 30, 12), Vector2(stage_width + 60, 94)))
	draw_line(left, right, subdued, 2)
	draw_circle(left, 5, subdued)
	draw_circle(right, 5, subdued)
	var center := left.lerp(right, fraction)
	if mode == 0:
		var character := StyleBoxFlat.new()
		character.bg_color = accent
		character.set_corner_radius_all(7)
		draw_style_box(character, Rect2(center - Vector2(17, 17), Vector2(34, 34)))
		draw_circle(center + Vector2(-5, -3), 2, Color("20242c"))
		draw_circle(center + Vector2(5, -3), 2, Color("20242c"))
	elif mode == 1:
		var a := center + Vector2(0, -23)
		var b := center + Vector2(21, -11)
		var c := center + Vector2(0, 1)
		var d := center + Vector2(-21, -11)
		draw_colored_polygon(PackedVector2Array([a, b, c, d]), accent.lightened(0.2))
		draw_colored_polygon(PackedVector2Array([d, c, center + Vector2(0, 25), center + Vector2(-21, 13)]), accent.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([c, b, center + Vector2(21, 13), center + Vector2(0, 25)]), accent)
	else:
		center = Vector2(size.x / 2.0, 65)
		var tint := accent
		tint.a = 1.0 if step == 0 else lerpf(0.2, 1.0, fraction)
		var panel := StyleBoxFlat.new()
		panel.bg_color = tint
		panel.set_corner_radius_all(8)
		draw_style_box(panel, Rect2(center - Vector2(70, 28), Vector2(140, 56)))
		draw_line(center - Vector2(45, 9), center + Vector2(25, -9), Color(0.1, 0.2, 0.15, tint.a), 4)
		draw_line(center - Vector2(45, -9), center + Vector2(45, 9), Color(0.1, 0.2, 0.15, tint.a), 4)
	var font := get_theme_font("font", "Label")
	draw_line(Vector2(left.x, 124), Vector2(right.x, 124), subdued, 3)
	for point in [Vector2(left.x, 124), Vector2(right.x, 124)]:
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -5), point + Vector2(5, 0), point + Vector2(0, 5), point + Vector2(-5, 0)]), accent)
	draw_circle(Vector2(lerpf(left.x, right.x, fraction), 124), 3, foreground)
	draw_string(font, Vector2(left.x - 26, 128), "0s", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, foreground)
	draw_string(font, Vector2(right.x + 12, 128), "1s", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, foreground)
	draw_string(font, Vector2(20, 154), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x - 40, 14, foreground)
