@tool
extends Control
## A schematic illustration only; never changes the user's scene.

var mode := 0
var step := 0
var elapsed := 0.0


func _process(delta: float) -> void:
	if is_visible_in_tree():
		elapsed += delta
		queue_redraw()


func _draw() -> void:
	var accent: Color = [Color("78b9ff"), Color("ff8f91"), Color("8fdfb3")][mode]
	var foreground := get_theme_color("font_color", "Label")
	var subdued := foreground
	subdued.a = 0.16
	var left := Vector2(50, 70)
	var right := Vector2(size.x - 60, 70)
	var fraction := (sin(elapsed * 2.0 - PI / 2.0) + 1.0) / 2.0 if step >= 3 else (1.0 if step == 2 else 0.0)
	draw_line(left, right, subdued, 2)
	draw_circle(left, 5, subdued)
	draw_circle(right, 5, subdued)
	var center := left.lerp(right, fraction)
	if mode == 0:
		draw_rect(Rect2(center - Vector2(15, 15), Vector2(30, 30)), accent)
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
		tint.a = lerpf(0.1, 1.0, fraction)
		draw_rect(Rect2(center - Vector2(70, 28), Vector2(140, 56)), tint)
		draw_line(center - Vector2(45, 9), center + Vector2(25, -9), Color(0.1, 0.2, 0.15, tint.a), 4)
		draw_line(center - Vector2(45, -9), center + Vector2(45, 9), Color(0.1, 0.2, 0.15, tint.a), 4)
	var font := get_theme_font("font", "Label")
	draw_string(font, Vector2(20, 125), "0 s  ◆ ━━━━━━━━━━━━━ ◆  1 s", HORIZONTAL_ALIGNMENT_CENTER, size.x - 40, 14, foreground)
	draw_string(font, Vector2(20, 152), "Illustration · your scene stays untouched", HORIZONTAL_ALIGNMENT_CENTER, size.x - 40, 12, foreground)
