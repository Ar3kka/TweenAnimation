class_name TweenAnimation
extends RefCounted
## Reusable, effect-first helpers for creating tweens on a chosen node.
## Example: var animate := TweenAnimation.new(self); animate.fade_out(sprite)

var node: Node
var random := RandomNumberGenerator.new()
var transition_type: Tween.TransitionType = Tween.TRANS_SINE
var ease_type: Tween.EaseType = Tween.EASE_IN_OUT


func _init(owner: Node, transition: Tween.TransitionType = Tween.TRANS_SINE) -> void:
	assert(owner != null, "TweenAnimation needs an owner node.")
	node = owner
	transition_type = transition
	random.randomize()


func _new_tween(transition: int = -1, ease: Tween.EaseType = Tween.EASE_IN_OUT) -> Tween:
	if not is_instance_valid(node) or not node.is_inside_tree():
		push_error("TweenAnimation's owner must be inside the scene tree before starting an animation.")
		return null
	var selected_transition := transition_type if transition < 0 else transition
	return node.create_tween().set_trans(selected_transition).set_ease(ease)


func custom(target: Object, property: NodePath, value: Variant, duration: float = 0.5, transition: int = -1) -> Tween:
	if target == null or duration < 0.0:
		return null
	var tween := _new_tween(transition)
	if tween:
		tween.tween_property(target, property, value, duration)
	return tween


func fade_to(target: CanvasItem, alpha: float, duration: float = 0.5) -> Tween:
	return custom(target, ^"modulate:a", clampf(alpha, 0.0, 1.0), duration)


func fade_in(target: CanvasItem, duration: float = 0.5) -> Tween:
	return fade_to(target, 1.0, duration)


func fade_out(target: CanvasItem, duration: float = 0.5) -> Tween:
	return fade_to(target, 0.0, duration)


func scale_to(target: Node2D, value: Vector2, duration: float = 0.2) -> Tween:
	return custom(target, ^"scale", value, duration)


func move_to(target: Node2D, value: Vector2, duration: float = 0.2) -> Tween:
	return custom(target, ^"position", value, duration)


func move_by(target: Node2D, offset: Vector2, duration: float = 0.2) -> Tween:
	if target == null:
		return null
	return move_to(target, target.position + offset, duration)


func rotate_to(target: Node2D, radians: float, duration: float = 0.2) -> Tween:
	return custom(target, ^"rotation", radians, duration)


func wiggle(target: Node2D, strength: float = 0.15, duration: float = 0.4, loops: int = 1) -> Tween:
	if target == null or loops < 1 or duration < 0.0:
		return null
	var origin := target.rotation
	var tween := _new_tween()
	if tween == null:
		return null
	tween.set_parallel(false)
	var step_duration := duration / float(loops * 4)
	for _i in range(loops):
		tween.tween_property(target, ^"rotation", origin - strength, step_duration)
		tween.tween_property(target, ^"rotation", origin, step_duration)
		tween.tween_property(target, ^"rotation", origin + strength, step_duration)
		tween.tween_property(target, ^"rotation", origin, step_duration)
	return tween
