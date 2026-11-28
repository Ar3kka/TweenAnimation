class_name Tweenimator
extends RefCounted
## Intent-first effects based on the original Tween Animator implementation.
## All effects return ordinary Godot Tweens for chaining and awaiting.
## A new effect replaces an active effect on the same target/property only.
## Animation helpers accept an optional final interval in seconds, after the whole effect.

## Optional default owner. Node-target effects can use the target instead.
var node: Node
## Named live Tweens; external code can access them directly.
## Prefer store()/create() for validation, name replacement and cleanup.
var tweens: Dictionary[StringName, Tween] = {}
var random := RandomNumberGenerator.new()
var transition_type: Tween.TransitionType = Tween.TRANS_SINE
var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
## Center UI scale/rotation effects. Set false to preserve a custom pivot.
var auto_center_pivot := true
var _active: Dictionary = {}
var _origins: Dictionary = {}
var _sequence_tween: Tween


## No Tween is needed at construction. An optional Node binds created Tweens.
## Without one, Node-target effects bind to their target. Resource/callback
## effects need an explicit owner because those targets are not Nodes.
func _init(owner: Node = null, transition: Tween.TransitionType = Tween.TRANS_SINE) -> void:
	node = owner
	transition_type = transition
	random.randomize()


func _new_tween(transition: int = -1, target_owner: Node = null, explicit_owner: bool = false) -> Tween:
	var owner := target_owner if explicit_owner and is_instance_valid(target_owner) else (node if is_instance_valid(node) else target_owner)
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		push_error("Tweenimator needs a live owner Node, or a Node target already in the scene tree.")
		return null
	return owner.create_tween().set_trans(transition_type if transition < 0 else transition).set_ease(ease_type)


## Create a named Tween and append ordinary Godot operations to the return value.
func create(name: StringName, owner: Node = null) -> Tween:
	if name == &"":
		push_error("Give the Tween a non-empty name.")
		return null
	var tween := _new_tween(-1, owner, true)
	return store(name, tween) if tween else null


## Track ANY valid Godot Tween. This does not rebind it, change easing, or
## reconstruct its operations. Name replacement kills only the previous Tween.
func store(name: StringName, tween: Tween, replace: bool = true) -> Tween:
	if name == &"" or not is_instance_valid(tween) or not tween.is_valid():
		push_error("store() needs a non-empty name and a valid Godot Tween.")
		return null
	var previous := get_tween(name)
	if previous and previous != tween:
		if not replace:
			push_error("A live Tween already uses this name: " + str(name))
			return null
		previous.kill()
		_forget_named(previous.get_instance_id())
	tweens[name] = tween
	var cleanup := _forget_named.bind(tween.get_instance_id())
	if not tween.finished.is_connected(cleanup):
		tween.finished.connect(cleanup, CONNECT_ONE_SHOT)
	return tween


func get_tween(name: StringName) -> Tween:
	var tween: Tween = tweens.get(name)
	if is_instance_valid(tween) and tween.is_valid():
		return tween
	tweens.erase(name)
	return null


func has_tween(name: StringName) -> bool:
	return get_tween(name) != null


func list_tweens() -> Array[StringName]:
	var names: Array[StringName] = []
	for name: StringName in tweens.keys():
		if has_tween(name):
			names.append(name)
	return names


func pause(name: StringName) -> void:
	var tween := get_tween(name)
	if tween:
		tween.pause()


func resume(name: StringName) -> void:
	var tween := get_tween(name)
	if tween:
		tween.play()


func stop_named(name: StringName) -> void:
	var tween := release(name)
	if is_instance_valid(tween) and tween.is_valid():
		tween.kill()
		_forget_named(tween.get_instance_id())


## Hand a Tween back to outside code without killing or resetting it.
## For a helper effect, also remove its automatic replacement channel.
func release(name: StringName) -> Tween:
	var tween := get_tween(name)
	tweens.erase(name)
	if tween:
		for key in _active.keys():
			if _active[key] == tween:
				_active.erase(key)
				_origins.erase(key)
	return tween


## Clear the named registry. Pass false to let the released Tweens continue.
func clear(kill_tweens: bool = true) -> void:
	for name: StringName in tweens.keys():
		if kill_tweens:
			stop_named(name)
		else:
			release(name)


func _forget_named(tween_id: int) -> void:
	# One Tween may have several names. Clean every alias in one callback.
	for name: StringName in tweens.keys():
		if not is_instance_valid(tweens[name]) or tweens[name].get_instance_id() == tween_id:
			tweens.erase(name)


func _channel(target: Object, property: NodePath) -> String:
	return str(target.get_instance_id()) + ":" + str(property)


## Append helper effects to an existing live Tween. The returned adapter shares
## its sequence; it does not replace active effects or create another Tween.
func on_tween(tween: Tween) -> Tweenimator:
	if not is_instance_valid(tween) or not tween.is_valid():
		push_error("on_tween() needs a live Tween; completed Tweens cannot be reused.")
		return null
	var adapter := Tweenimator.new(node, transition_type)
	adapter.ease_type = ease_type
	adapter.auto_center_pivot = auto_center_pivot
	adapter._sequence_tween = tween
	return adapter


func _effect(target: Object, property: NodePath, duration: float, transition: int = -1) -> Tween:
	if not is_instance_valid(target) or not is_finite(duration) or duration < 0.0:
		push_error("Tweenimator needs a valid target and a finite, non-negative duration.")
		return null
	if _sequence_tween != null:
		if not _sequence_tween.is_valid():
			push_error("The connected Tween has finished or was killed.")
			return null
		return _sequence_tween.chain()
	var key := _channel(target, property)
	if _active.has(key):
		var previous: Tween = _active[key]
		if previous.is_valid():
			previous.kill()
		_forget_named(previous.get_instance_id())
	var target_owner: Node = target as Node
	var tween := _new_tween(transition, target_owner)
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
			_forget_named(tween.get_instance_id())
			_active.erase(key)
			_origins.erase(key)


func stop_all() -> void:
	clear()
	for tween: Tween in _active.values():
		if tween.is_valid():
			tween.kill()
	_active.clear()
	_origins.clear()


## Reject invalid waits before replacing any existing effect or changing a UI pivot.
func _valid_interval(interval: float) -> bool:
	if not is_finite(interval) or interval < 0.0:
		push_error("Tweenimator interval must be finite and non-negative (seconds).")
		return false
	return true


## Append exactly one wait after all stages. Zero adds no empty step.
func _finish_effect(tween: Tween, interval: float) -> Tween:
	if tween and interval > 0.0:
		tween.tween_interval(interval)
	return tween


func custom(target: Object, property: NodePath, value: Variant, duration: float = 0.5, transition: int = -1, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	var tween := _effect(target, property, duration, transition)
	if tween:
		tween.tween_property(target, property, value, duration)
	return _finish_effect(tween, interval)


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


func move_to(target: Node, value: Variant, duration: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	if not _vector(target, value):
		return null
	return custom(target, ^"position", value, duration, -1, interval)


func move_by(target: Node, offset: Variant, duration: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	if not _vector(target, offset):
		return null
	return move_to(target, target.get("position") + offset, duration, interval)


func _direction(target: Node, direction: Vector3, distance: float, duration: float, interval: float) -> Tween:
	if not _spatial(target):
		return null
	var offset: Variant = direction * distance if target is Node3D else Vector2(direction.x, -direction.y) * distance
	return move_by(target, offset, duration, interval)


func move_left(target: Node, distance: float = 1.0, duration: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	return _direction(target, Vector3.LEFT, distance, duration, interval)


func move_right(target: Node, distance: float = 1.0, duration: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	return _direction(target, Vector3.RIGHT, distance, duration, interval)


func move_up(target: Node, distance: float = 1.0, duration: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	return _direction(target, Vector3.UP, distance, duration, interval)


func move_down(target: Node, distance: float = 1.0, duration: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	return _direction(target, Vector3.DOWN, distance, duration, interval)


func move_forward(target: Node3D, distance: float = 1.0, duration: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	return _direction(target, Vector3.FORWARD, distance, duration, interval)


func move_back(target: Node3D, distance: float = 1.0, duration: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	return _direction(target, Vector3.BACK, distance, duration, interval)


func scale_to(target: Node, value: Variant, duration: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	if not _spatial(target):
		return null
	var final_value: Variant = value
	if value is float or value is int:
		final_value = Vector3.ONE * value if target is Node3D else Vector2.ONE * value
	if not _vector(target, final_value):
		return null
	_pivot(target)
	return custom(target, ^"scale", final_value, duration, -1, interval)


func scale_up(target: Node, amount: float = 0.1, duration: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	if not _spatial(target):
		return null
	return scale_to(target, target.get("scale") * (1.0 + amount), duration, interval)


func scale_down(target: Node, amount: float = 0.1, duration: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	return scale_up(target, -clampf(amount, 0.0, 1.0), duration, interval)


func rotate_to(target: Node, radians: Variant, duration: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	if not _spatial(target):
		return null
	if (target is Node3D and not radians is Vector3) or (not target is Node3D and not (radians is float or radians is int)):
		push_error("Use Vector3 radians for 3D and a numeric angle for 2D/UI.")
		return null
	_pivot(target)
	return custom(target, ^"rotation", radians, duration, -1, interval)


func rotate_degrees(target: Node, degrees: Variant, duration: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	if degrees is Vector3:
		return rotate_to(target, Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z)), duration, interval)
	if degrees is float or degrees is int:
		return rotate_to(target, deg_to_rad(float(degrees)), duration, interval)
	push_error("Use Vector3 degrees for 3D and a numeric angle for 2D/UI.")
	return null


func press(target: Node, amount: float = 0.05, duration_down: float = 0.1, duration_up: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
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
	return _finish_effect(tween, interval)


func wiggle(target: Node, strength: float = 0.15, duration: float = 0.4, loops: int = 1, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
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
	return _finish_effect(tween, interval)


func fade_to(target: CanvasItem, alpha: float, duration: float = 0.5, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	return custom(target, ^"modulate:a", clampf(alpha, 0.0, 1.0), duration, -1, interval)


func fade_in(target: CanvasItem, duration: float = 0.5, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	return fade_to(target, 1.0, duration, interval)


func fade_out(target: CanvasItem, duration: float = 0.5, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	return fade_to(target, 0.0, duration, interval)


func resize_to(target: Control, value: Vector2, duration: float = 0.2, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	return custom(target, ^"size", value, duration, -1, interval)


func set_volume(target: Node, decibels: float = 0.0, duration: float = 0.5, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	if not is_instance_valid(target) or not (target is AudioStreamPlayer or target is AudioStreamPlayer2D or target is AudioStreamPlayer3D):
		push_error("set_volume needs an AudioStreamPlayer, AudioStreamPlayer2D or AudioStreamPlayer3D.")
		return null
	return custom(target, ^"volume_db", decibels, duration, -1, interval)


func shader_transition(material: ShaderMaterial, parameter: String, value: Variant = 1.0, duration: float = 0.5, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	return custom(material, NodePath("shader_parameter/" + parameter), value, duration, -1, interval)


func method(callback: Callable, from: Variant, to: Variant, duration: float = 0.5, interval: float = 0.0) -> Tween:
	if not _valid_interval(interval):
		return null
	if not callback.is_valid() or duration < 0.0 or not is_finite(duration):
		return null
	var tween := _new_tween()
	if tween:
		var key := "method:" + str(tween.get_instance_id())
		_active[key] = tween
		tween.finished.connect(_forget.bind(key, tween.get_instance_id()), CONNECT_ONE_SHOT)
		tween.tween_method(callback, from, to, duration)
	return _finish_effect(tween, interval)
