class_name TweenAnimation
extends RefCounted
## Intent-first effects based on the original Tween Animator implementation.
## All effects return ordinary Godot Tweens for chaining and awaiting.
## A new effect replaces an active effect on the same target/property only.

var node: Node
var random := RandomNumberGenerator.new()
var transition_type: Tween.TransitionType = Tween.TRANS_SINE
var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
## Center UI scale/rotation effects. Set false to preserve a custom pivot.
var auto_center_pivot := true
var _active: Dictionary = {}
var _origins: Dictionary = {}


## This RefCounted helper needs a Node to call create_tween() and bind lifetime.
## Pass self, the animated node, or another controller Node; owner and target
## need not match. The owner must be inside the tree when an effect starts.
func _init(owner: Node, transition: Tween.TransitionType = Tween.TRANS_SINE) -> void:
	assert(owner != null, "TweenAnimation needs an owner node.")
	node = owner
	transition_type = transition
	random.randomize()


func _new_tween(transition: int = -1) -> Tween:
	if not is_instance_valid(node) or not node.is_inside_tree():
		push_error("TweenAnimation's owner must be inside the scene tree.")
		return null
	return node.create_tween().set_trans(transition_type if transition < 0 else transition).set_ease(ease_type)


func _channel(target: Object, property: NodePath) -> String:
	return str(target.get_instance_id()) + ":" + str(property)


func _effect(target: Object, property: NodePath, duration: float, transition: int = -1) -> Tween:
	if not is_instance_valid(target) or not is_finite(duration) or duration < 0.0:
		push_error("TweenAnimation needs a valid target and a finite, non-negative duration.")
		return null
	var key := _channel(target, property)
	if _active.has(key):
		var previous: Tween = _active[key]
		if previous.is_valid():
			previous.kill()
	var tween := _new_tween(transition)
	_origins.erase(key)
	if tween:
		_active[key] = tween
		tween.finished.connect(_forget.bind(key, tween.get_instance_id()), CONNECT_ONE_SHOT)
	return tween


func _forget(key: String, tween_id: int) -> void:
	if _active.has(key) and _active[key].get_instance_id() == tween_id:
		_active.erase(key)
		_origins.erase(key)


func stop(target: Object, property: NodePath = NodePath()) -> void:
	if not is_instance_valid(target):
		return
	var prefix := str(target.get_instance_id()) + ":"
	for key in _active.keys():
		if (property.is_empty() and str(key).begins_with(prefix)) or key == _channel(target, property):
			var tween: Tween = _active[key]
			if tween.is_valid():
				tween.kill()
			_active.erase(key)
			_origins.erase(key)


func stop_all() -> void:
	for tween: Tween in _active.values():
		if tween.is_valid():
			tween.kill()
	_active.clear()
	_origins.clear()


func custom(target: Object, property: NodePath, value: Variant, duration: float = 0.5, transition: int = -1) -> Tween:
	var tween := _effect(target, property, duration, transition)
	if tween:
		tween.tween_property(target, property, value, duration)
	return tween


func _spatial(target: Node) -> bool:
	if is_instance_valid(target) and (target is Node2D or target is Node3D or target is Control):
		return true
	push_error("This effect needs a Node2D, Node3D or Control target.")
	return false


func _vector(target: Node, value: Variant) -> bool:
	if not _spatial(target):
		return false
	if (target is Node3D and value is Vector3) or (not target is Node3D and value is Vector2):
		return true
	push_error("Use Vector3 for 3D and Vector2 for 2D/UI.")
	return false


func _pivot(target: Node) -> void:
	if auto_center_pivot and target is Control:
		target.pivot_offset = target.size * 0.5


func move_to(target: Node, value: Variant, duration: float = 0.2) -> Tween:
	if not _vector(target, value):
		return null
	return custom(target, ^"position", value, duration)


func move_by(target: Node, offset: Variant, duration: float = 0.2) -> Tween:
	if not _vector(target, offset):
		return null
	return move_to(target, target.get("position") + offset, duration)


func _direction(target: Node, direction: Vector3, distance: float, duration: float) -> Tween:
	if not _spatial(target):
		return null
	var offset: Variant = direction * distance if target is Node3D else Vector2(direction.x, -direction.y) * distance
	return move_by(target, offset, duration)


func move_left(target: Node, distance: float = 1.0, duration: float = 0.2) -> Tween:
	return _direction(target, Vector3.LEFT, distance, duration)


func move_right(target: Node, distance: float = 1.0, duration: float = 0.2) -> Tween:
	return _direction(target, Vector3.RIGHT, distance, duration)


func move_up(target: Node, distance: float = 1.0, duration: float = 0.2) -> Tween:
	return _direction(target, Vector3.UP, distance, duration)


func move_down(target: Node, distance: float = 1.0, duration: float = 0.2) -> Tween:
	return _direction(target, Vector3.DOWN, distance, duration)


func move_forward(target: Node3D, distance: float = 1.0, duration: float = 0.2) -> Tween:
	return _direction(target, Vector3.FORWARD, distance, duration)


func move_back(target: Node3D, distance: float = 1.0, duration: float = 0.2) -> Tween:
	return _direction(target, Vector3.BACK, distance, duration)


func scale_to(target: Node, value: Variant, duration: float = 0.2) -> Tween:
	if not _spatial(target):
		return null
	var final_value: Variant = value
	if value is float or value is int:
		final_value = Vector3.ONE * value if target is Node3D else Vector2.ONE * value
	if not _vector(target, final_value):
		return null
	_pivot(target)
	return custom(target, ^"scale", final_value, duration)


func scale_up(target: Node, amount: float = 0.1, duration: float = 0.2) -> Tween:
	if not _spatial(target):
		return null
	return scale_to(target, target.get("scale") * (1.0 + amount), duration)


func scale_down(target: Node, amount: float = 0.1, duration: float = 0.2) -> Tween:
	return scale_up(target, -clampf(amount, 0.0, 1.0), duration)


func rotate_to(target: Node, radians: Variant, duration: float = 0.2) -> Tween:
	if not _spatial(target):
		return null
	if (target is Node3D and not radians is Vector3) or (not target is Node3D and not (radians is float or radians is int)):
		push_error("Use Vector3 radians for 3D and a numeric angle for 2D/UI.")
		return null
	_pivot(target)
	return custom(target, ^"rotation", radians, duration)


func rotate_degrees(target: Node, degrees: Variant, duration: float = 0.2) -> Tween:
	if degrees is Vector3:
		return rotate_to(target, Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z)), duration)
	if degrees is float or degrees is int:
		return rotate_to(target, deg_to_rad(float(degrees)), duration)
	push_error("Use Vector3 degrees for 3D and a numeric angle for 2D/UI.")
	return null


func press(target: Node, amount: float = 0.05, duration_down: float = 0.1, duration_up: float = 0.2) -> Tween:
	if not _spatial(target) or duration_up < 0.0 or not is_finite(duration_up):
		return null
	_pivot(target)
	var key := _channel(target, ^"scale")
	var origin: Variant = _origins.get(key, target.get("scale"))
	var tween := _effect(target, ^"scale", duration_down)
	if tween:
		_origins[key] = origin
		tween.tween_property(target, ^"scale", origin * (1.0 - clampf(amount, 0.0, 1.0)), duration_down)
		tween.tween_property(target, ^"scale", origin, duration_up)
	return tween


func wiggle(target: Node, strength: float = 0.15, duration: float = 0.4, loops: int = 1) -> Tween:
	if not _spatial(target) or loops < 1:
		return null
	_pivot(target)
	var key := _channel(target, ^"rotation")
	var origin: Variant = _origins.get(key, target.get("rotation"))
	var offset: Variant = Vector3(0, strength, 0) if target is Node3D else strength
	var tween := _effect(target, ^"rotation", duration)
	if tween:
		_origins[key] = origin
		var segment := duration / float(loops * 4)
		for index in loops:
			tween.tween_property(target, ^"rotation", origin - offset, segment)
			tween.tween_property(target, ^"rotation", origin, segment)
			tween.tween_property(target, ^"rotation", origin + offset, segment)
			tween.tween_property(target, ^"rotation", origin, segment)
	return tween


func fade_to(target: CanvasItem, alpha: float, duration: float = 0.5) -> Tween:
	return custom(target, ^"modulate:a", clampf(alpha, 0.0, 1.0), duration)


func fade_in(target: CanvasItem, duration: float = 0.5) -> Tween:
	return fade_to(target, 1.0, duration)


func fade_out(target: CanvasItem, duration: float = 0.5) -> Tween:
	return fade_to(target, 0.0, duration)


func resize_to(target: Control, value: Vector2, duration: float = 0.2) -> Tween:
	return custom(target, ^"size", value, duration)


func set_volume(target: Node, decibels: float = 0.0, duration: float = 0.5) -> Tween:
	if not is_instance_valid(target) or not (target is AudioStreamPlayer or target is AudioStreamPlayer2D or target is AudioStreamPlayer3D):
		push_error("set_volume needs an AudioStreamPlayer, AudioStreamPlayer2D or AudioStreamPlayer3D.")
		return null
	return custom(target, ^"volume_db", decibels, duration)


func shader_transition(material: ShaderMaterial, parameter: String, value: Variant = 1.0, duration: float = 0.5) -> Tween:
	return custom(material, NodePath("shader_parameter/" + parameter), value, duration)


func method(callback: Callable, from: Variant, to: Variant, duration: float = 0.5) -> Tween:
	if not callback.is_valid() or duration < 0.0 or not is_finite(duration):
		return null
	var tween := _new_tween()
	if tween:
		var key := "method:" + str(tween.get_instance_id())
		_active[key] = tween
		tween.finished.connect(_forget.bind(key, tween.get_instance_id()), CONNECT_ONE_SHOT)
		tween.tween_method(callback, from, to, duration)
	return tween
