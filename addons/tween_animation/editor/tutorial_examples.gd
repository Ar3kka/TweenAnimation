@tool
extends RefCounted
## Presentation snippets. GDScript setup appears once; later snippets share it.

static func gdscript(source: String, first_step: bool) -> String:
	var code := source.replace("func animate()", "func play_effect()").replace("    animate()", "    play_effect()")
	var names := RegEx.new()
	names.compile("\\b(animate|animator)\\b")
	code = names.sub(code, "tweenimator", true)
	if first_step:
		return code.strip_edges() + "\n"
	var lines := PackedStringArray()
	for line in code.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed == "extends Node" or trimmed.begins_with("@onready var target"):
			continue
		if "Tweenimator.new()" in trimmed and not trimmed.begins_with("#"):
			continue
		if trimmed.begins_with("# Attach") or trimmed.begins_with("# Wait until children") or trimmed.begins_with("# No existing Tween") or trimmed.begins_with("# Option: Tweenimator.new") or trimmed.begins_with("# Reuse this helper"):
			continue
		lines.append(line)
	return "\n".join(lines).strip_edges() + "\n"


static func csharp(mode: int, title: String, helper: bool) -> String:
	var target_type: String = ["Node2D", "Node3D", "Control"][mode]
	var target_path: String = ["Sprite2D", "MeshInstance3D", "Panel"][mode]
	var vector := "Vector3" if mode == 1 else "Vector2"
	var distance := "2.0f" if mode == 1 else "100.0f"
	var position := "new Vector3(2, 0, 0)" if mode == 1 else "new Vector2(100, 0)"
	var header := "using Godot;\n\npublic partial class TweenExample : Node\n{\n    private " + target_type + " _target;\n"
	if title == "Your animation toolbox":
		if helper:
			return header + "    private GodotObject _tweenimator;\n\n    public override void _Ready()\n    {\n        _target = GetNode<" + target_type + ">(" + JSON.stringify(target_path) + ");\n        // Load the SAME GDScript runtime; there is no separate C# class.\n        var script = GD.Load<GDScript>(\"res://addons/tween_animation/src/tweenimator.gd\");\n        _tweenimator = (GodotObject)script.New();\n        // Optional default owner: (GodotObject)script.New(this)\n    }\n}\n"
		return header + "\n    public override void _Ready()\n    {\n        _target = GetNode<" + target_type + ">(" + JSON.stringify(target_path) + ");\n    }\n}\n"
	var move := '(Tween)_tweenimator.Call("move_left", _target, ' + distance + ', 0.4).AsGodotObject()'
	var native_move := 'var tween = CreateTween();\n    tween.TweenProperty(_target, "position", _target.Position + ' + vector + '.Left * ' + distance + ', 0.4);'
	var text := ""
	match title:
		"Make your first move", "Move left without the vector math":
			text = "var tween = " + move + ";" if helper else native_move
		"Keep the Tween you just made":
			text = "var slide = " + move + ';\n    _tweenimator.Call("store", new StringName("slide"), slide);' if helper else 'var slide = CreateTween();\n    slide.TweenProperty(_target, "position", _target.Position + ' + vector + '.Left * ' + distance + ', 0.4);'
			text += '\n    slide.TweenInterval(0.2);\n    await ToSignal(slide, Tween.SignalName.Finished);\n    GD.Print("Slide complete");'
			return "public async void PlaySlide()\n{\n    " + text + "\n}\n"
		"Build a named animation":
			if helper:
				text = 'var intro = (Tween)_tweenimator.Call("create", new StringName("intro"), this).AsGodotObject();\n    intro.TweenProperty(_target, "position", _target.Position + ' + vector + '.Left * ' + distance + ', 0.4);'
			else:
				return 'private Tween _intro;\n\npublic void PlayIntro()\n{\n    if (_intro != null && _intro.IsValid()) _intro.Kill();\n    _intro = CreateTween();\n    _intro.TweenProperty(_target, "position", _target.Position + ' + vector + '.Left * ' + distance + ', 0.4);\n}\n'
			return "public void PlayIntro()\n{\n    " + text + "\n}\n"
		"Bring a Tween from anywhere":
			if helper:
				return 'public void RegisterExternal(Tween external)\n{\n    _tweenimator.Call("store", new StringName("external"), external);\n    _tweenimator.Call("pause", new StringName("external"));\n    _tweenimator.Call("resume", new StringName("external"));\n}\n'
			return 'private Tween _external;\n\npublic void RegisterExternal(Tween external)\n{\n    _external = external;\n    _external.Pause();\n    _external.Play();\n}\n'
		"Find it by name":
			if helper:
				text = 'var slide = ' + move + ';\n    _tweenimator.Call("store", new StringName("slide"), slide);\n    var entries = _tweenimator.Get("tweens").AsGodotDictionary();\n    var same = (Tween)entries[new StringName("slide")].AsGodotObject();\n    same.Pause();\n    var found = _tweenimator.Call("get_tween", new StringName("slide")).AsGodotObject() as Tween;\n    if (found != null) _tweenimator.Call("resume", new StringName("slide"));'
			else:
				text = native_move + '\n    var entries = new Godot.Collections.Dictionary<StringName, Tween>();\n    entries[new StringName("slide")] = tween;\n    if (entries.TryGetValue(new StringName("slide"), out Tween found))\n    {\n        found.Pause();\n        found.Play();\n    }'
		"Hand it back to your own code":
			text = 'var slide = ' + move + ';\n    _tweenimator.Call("store", new StringName("slide"), slide);\n    var returned = (Tween)_tweenimator.Call("release", new StringName("slide")).AsGodotObject();\n    returned.TweenInterval(0.2);' if helper else native_move + '\n    // Pass this same Tween to other code; it remains a normal Godot Tween.\n    tween.TweenInterval(0.2);'
		"Give it a property to play with", "See what each property does":
			var operations: Array[Array] = [
				["position", "move_to", position],
				["scale", "scale_to", "new " + vector + ("(1.2f, 1.2f, 1.2f)" if mode == 1 else "(1.2f, 1.2f)")],
				["rotation", "rotate_to", "new Vector3(0, Mathf.Pi / 2.0f, 0)" if mode == 1 else "Mathf.Pi / 2.0f"],
				["rotation_degrees", "rotate_degrees", "new Vector3(0, 180, 0)" if mode == 1 else "180.0f"]
			]
			if mode == 2:
				operations = [["position", "move_to", "new Vector2(100, 40)"], ["size", "resize_to", "new Vector2(240, 100)"], ["scale", "scale_to", "new Vector2(1.1f, 1.1f)"], ["modulate:a", "fade_to", "0.3f"]]
			text = "" if helper else "var tween = CreateTween();"
			for operation in operations:
				if helper:
					text += ('\n    var piece%d = (Tween)_tweenimator.Call("%s", _target, %s, 0.5).AsGodotObject();\n    await ToSignal(piece%d, Tween.SignalName.Finished);' % [operations.find(operation), operation[1], operation[2], operations.find(operation)])
				else:
					text += '\n    tween.TweenProperty(_target, "%s", %s, 0.5);' % [operation[0], operation[2]]
			return ("public async void PlayPropertyTour()" if helper else "public void PlayPropertyTour()") + "\n{\n    " + text + "\n}\n"
		"Plant the first key", "Choose the destination":
			var start := "Vector3.Zero" if mode == 1 else "Vector2.Zero"
			var property := "modulate:a" if mode == 2 else "position"
			var finish := "1.0f" if mode == 2 else position
			text = '_target.Modulate = new Color(1, 1, 1, 0);' if mode == 2 else '_target.Position = ' + start + ';'
			text += '\n    _tweenimator.Call("custom", _target, new NodePath("' + property + '"), ' + finish + ', 1.0);' if helper else '\n    var tween = CreateTween();\n    tween.TweenProperty(_target, "' + property + '", ' + finish + ', 1.0);'
		"Bring it to life", "Let your game press Play", "Bring your existing work along":
			return 'public void PlaySavedClip()\n{\n    var clip = GD.Load<Animation>("res://animations/my_animation.tres");\n    var library = new AnimationLibrary();\n    library.AddAnimation("clip", clip);\n    var player = GetNode<AnimationPlayer>("AnimationPlayer");\n    player.AddAnimationLibrary("tweenimation", library);\n    player.Play("tweenimation/clip");\n}\n'
		"A press that returns to its starting size":
			if helper:
				text = '_tweenimator.Call("press", _target);'
			else:
				text = '_target.PivotOffset = _target.Size / 2.0f;\n    ' if mode == 2 else ""
				text += 'var rest = _target.Scale;\n    var tween = CreateTween();\n    tween.SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);\n    tween.TweenProperty(_target, "scale", rest * 0.95f, 0.1);\n    tween.TweenProperty(_target, "scale", rest, 0.2);'
		"Give the movement a feel":
			text = '_tweenimator.Set("transition_type", (int)Tween.TransitionType.Back);\n    _tweenimator.Set("ease_type", (int)Tween.EaseType.Out);\n    var tween = ' + move + ';' if helper else 'var tween = CreateTween();\n    tween.SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);\n    tween.TweenProperty(_target, "position", _target.Position + ' + vector + '.Left * ' + distance + ', 0.4);'
		"Make one thing follow another":
			text = "var tween = " + move + ";" if helper else native_move
			text += '\n    tween.TweenInterval(0.2);\n    tween.TweenCallback(Callable.From(() => GD.Print("Finished")));'
		_:
			text = "var tween = " + move + ";" if helper else native_move
	return "public void PlayExample()\n{\n    " + text + "\n}\n"
