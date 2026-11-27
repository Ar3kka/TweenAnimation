@tool
extends RefCounted

const ITEMS := {
	"guide_setup": {
		"group": "Start here",
		"title": "Set up your Tweenimator",
		"summary": "Three ways to set up the same runtime class: no owner yet, a shared default owner, or an explicit owner for one named animation.",
		"code": "extends Node\n\n# Can exist before the scene is ready. No Tween is required.\nvar animator := Tweenimator.new()\n\nfunc _ready() -> void:\n    # Node-target effects infer their owner from the target.\n    animator.move_left($Sprite2D, 100, 0.3)\n    # A shared controller owner is optional, not compulsory.\n    var controlled := Tweenimator.new(self)\n    controlled.fade_out($Panel)\n    # A named factory can select an owner for this animation only.\n    var intro := animator.create(&\"intro\", self)\n    intro.tween_interval(0.2)\n",
		"returns": "",
		"notes": "The owner must be inside the scene tree when creating an effect. Freeing an owner kills its bound Tweens. Resource-only and callback-only effects need a default owner because they have no Node target. Share the same Tweenimator instance with code that should access the same dictionary. TweenAnimation remains a compatibility name.",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "private readonly GodotObject _tweenimator =\n    (GodotObject)GD.Load<GDScript>(\"res://addons/tween_animation/src/tweenimator.gd\").New();\n\n// Alternative, inside an existing method, to use this controller as owner:\nvar script = GD.Load<GDScript>(\"res://addons/tween_animation/src/tweenimator.gd\");\nvar controlled = (GodotObject)script.New(this);\n"
	},
	"guide_names": {
		"group": "Start here",
		"title": "Store, name and retrieve",
		"summary": "Keep the returned Tween reference, give it a name, then choose direct or safe access.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    var slide := animator.move_left($Sprite2D, 100, 0.3)\n    animator.store(&\"slide\", slide)\n    # Same object: storing does not create a second animation.\n    var same: Tween = animator.tweens[&\"slide\"]\n    same.pause()\n    # Safe lookup when a name might have finished or been removed.\n    var found := animator.get_tween(&\"slide\")\n    if found:\n        animator.resume(&\"slide\")\n",
		"returns": "",
		"notes": "Names are local to one Tweenimator. Finished entries are removed automatically. Reusing a name kills the old Tween by default; store(name, tween, false) rejects a duplicate. Direct dictionary writes bypass validation and finished cleanup. Externally killed entries are pruned on get_tween()/list_tweens().",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "var slide = (Tween)_tweenimator.Call(\"move_left\", GetNode<Node2D>(\"Sprite2D\"), 100.0f, 0.3).AsGodotObject();\n_tweenimator.Call(\"store\", new StringName(\"slide\"), slide);\nvar found = _tweenimator.Call(\"get_tween\", new StringName(\"slide\")).AsGodotObject() as Tween;\nif (found != null) found.Pause();\n"
	},
	"guide_external": {
		"group": "Start here",
		"title": "Bring your own Tween",
		"summary": "Register a Tween made anywhere else without altering its existing owner, easing, progress, or operations.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    # This Tween predates its manager.\n    var external := create_tween()\n    external.set_trans(Tween.TRANS_LINEAR)\n    external.tween_property($Sprite2D, \"position:x\", 100.0, 1.0)\n    var animator := Tweenimator.new()\n    animator.store(&\"external\", external)\n    animator.pause(&\"external\")\n    animator.resume(&\"external\")\n    # Hand it back: release removes tracking, not playback.\n    var returned := animator.release(&\"external\")\n    returned.tween_interval(0.2)\n",
		"returns": "",
		"notes": "store() accepts a valid Godot Tween; it does not inspect property tracks or convert scripts into timeline resources. External Tweens are managed by name, not by inferred target/property replacement channels. A Tween can have aliases: release every name to fully detach it.",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "var external = CreateTween();\nexternal.TweenProperty(GetNode<Control>(\"Panel\"), \"modulate:a\", 0.0f, 0.5);\n_tweenimator.Call(\"store\", new StringName(\"external\"), external);\n"
	},
	"guide_chains": {
		"group": "Start here",
		"title": "Chains, parallel groups and completion",
		"summary": "Build sequences or parallel groups using ordinary Godot operations on the Tween returned by Tweenimator.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    var intro := animator.create(&\"intro\", self)\n    intro.set_parallel(true)\n    intro.tween_property($Panel, \"position:x\", 100.0, 0.4)\n    intro.tween_property($Panel, \"modulate:a\", 1.0, 0.4)\n    # chain() starts the next sequential group after the parallel group.\n    intro.chain().tween_interval(0.2)\n    intro.tween_callback(func(): print(\"Intro finished\"))\n    await intro.finished\n    print(\"Continue game logic here\")\n",
		"returns": "",
		"notes": "Append operations before the next process frame. Tweens are sequential unless configured otherwise. Finished Tweens cannot be replayed; call a function that creates a fresh Tween. Killed Tweens do not emit finished. Replacing a named/helper effect cancels its whole Tween, including any appended steps.",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "var intro = (Tween)_tweenimator.Call(\"create\", new StringName(\"intro\"), this).AsGodotObject();\nintro.SetParallel(true);\nintro.TweenProperty(GetNode<Control>(\"Panel\"), \"position:x\", 100.0f, 0.4);\nintro.TweenProperty(GetNode<Control>(\"Panel\"), \"modulate:a\", 1.0f, 0.4);\nintro.Chain().TweenInterval(0.2);\nintro.TweenCallback(Callable.From(() => GD.Print(\"Finished\")));\n"
	},
	"guide_intervals": {
		"group": "Start here",
		"title": "Move, then wait · optional interval",
		"summary": "An optional final interval argument adds a wait to the same returned Tween after the whole helper effect. Default 0.0 keeps existing calls unchanged.",
		"code": "# Choose one function to run; both move for 0.4s and wait for 0.2s.\nfunc play_with_helper() -> void:\n    var slide := tweenimator.move_left($Sprite2D, 100, 0.4, 0.2)\n    tweenimator.store(&\"slide\", slide)\n    await slide.finished\n    print(\"Movement and wait complete\")\n\nfunc play_with_godot() -> void:\n    var slide := create_tween()\n    slide.tween_property($Sprite2D, \"position\", $Sprite2D.position + Vector2.LEFT * 100, 0.4)\n    slide.tween_interval(0.2)\n    await slide.finished\n    print(\"Movement and wait complete\")\n\n# Optional arguments keep their existing positions:\n# press(target, amount, duration_down, duration_up, interval)\nfunc play_press() -> void:\n    tweenimator.press($Button, 0.05, 0.1, 0.2, 0.4)\n\n# custom(target, property, value, duration, transition, interval)\nfunc play_custom() -> void:\n    tweenimator.custom($Panel, ^\"modulate:a\", 1.0, 0.5, -1, 0.2)\n",
		"returns": "Each animation helper still returns an ordinary Godot Tween.",
		"notes": "duration controls the animation itself; interval adds a finite, non-negative wait afterward. interval defaults to 0.0 and adds no extra step when omitted. Sequential callbacks, finished and named cleanup occur after the wait. Pause/resume also control the wait. Replacing or killing the Tween cancels it, including its pending wait. press/wiggle wait once after all stages/loops, not after every segment. custom() keeps transition before interval; use -1 to inherit the default curve. Factory/registry operations such as create() and store() do not take interval. Existing/external Tweens can still use tween_interval().",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Available on every animation-producing helper for 2D, 3D, UI, audio, shader properties and callback values. Normal sequential Tween chaining includes the wait.",
		"csharp": "// Add these methods to the class from the setup guide; call either one.\npublic async void PlayWithHelper()\n{\n    var slide = (Tween)_tweenimator.Call(\"move_left\", GetNode<Node2D>(\"Sprite2D\"), 100.0f, 0.4, 0.2).AsGodotObject();\n    _tweenimator.Call(\"store\", new StringName(\"slide\"), slide);\n    await ToSignal(slide, Tween.SignalName.Finished);\n    GD.Print(\"Movement and wait complete\");\n}\n\npublic async void PlayWithGodot()\n{\n    var target = GetNode<Node2D>(\"Sprite2D\");\n    var slide = CreateTween();\n    slide.TweenProperty(target, \"position\", target.Position + Vector2.Left * 100, 0.4);\n    slide.TweenInterval(0.2);\n    await ToSignal(slide, Tween.SignalName.Finished);\n    GD.Print(\"Movement and wait complete\");\n}\n\npublic void PlayPress()\n{\n    _tweenimator.Call(\"press\", GetNode<Button>(\"Button\"), 0.05, 0.1, 0.2, 0.4);\n}\n\npublic void PlayCustom()\n{\n    _tweenimator.Call(\"custom\", GetNode<Control>(\"Panel\"), new NodePath(\"modulate:a\"), 1.0f, 0.5, -1, 0.2);\n}"
	},
	"guide_replay": {
		"group": "Start here",
		"title": "Pause, stop and replay",
		"summary": "Pause an active animation, resume it, or call its factory function to start a new run.",
		"code": "extends Node\n\nvar animator := Tweenimator.new()\n\nfunc _ready() -> void:\n    play_intro()\n    animator.pause(&\"intro\")\n    animator.resume(&\"intro\")\n\n# Connect a button or input action to this function to replay.\nfunc play_intro() -> void:\n    var intro := animator.create(&\"intro\", self)\n    intro.tween_property($Panel, \"modulate:a\", 0.3, 0.5)\n    intro.tween_property($Panel, \"modulate:a\", 1.0, 0.5)\n\nfunc cancel_intro() -> void:\n    animator.stop_named(&\"intro\")\n",
		"returns": "",
		"notes": "pause/resume work only on live entries. A completed Tween must be recreated. create() replaces an existing name, so replaying the factory cancels a previous run automatically.",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "public void PlayIntro()\n{\n    var intro = (Tween)_tweenimator.Call(\"create\", new StringName(\"intro\"), this).AsGodotObject();\n    intro.TweenProperty(GetNode<Control>(\"Panel\"), \"modulate:a\", 0.3f, 0.5);\n    intro.TweenProperty(GetNode<Control>(\"Panel\"), \"modulate:a\", 1.0f, 0.5);\n}\n"
	},
	"guide_settings": {
		"group": "Configuration",
		"title": "Properties and defaults",
		"summary": "Configuration is shared by newly created helper Tweens. Existing external Tweens are not modified by store().",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.transition_type = Tween.TRANS_BACK\n    animator.ease_type = Tween.EASE_OUT\n    # Preserve an intentionally placed Control pivot.\n    animator.auto_center_pivot = false\n    animator.scale_to($Panel, 1.1, 0.2)\n    print(animator.list_tweens())\n",
		"returns": "",
		"notes": "Public fields: node: Node (optional default owner); tweens: Dictionary[StringName, Tween] (named handles); transition_type: Tween.TransitionType (Sine); ease_type: Tween.EaseType (In-Out); auto_center_pivot: bool (true); random: RandomNumberGenerator (available for your own randomized effects; built-in effects are deterministic).",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "_tweenimator.Set(\"transition_type\", (int)Tween.TransitionType.Back);\n_tweenimator.Set(\"ease_type\", (int)Tween.EaseType.Out);\n_tweenimator.Set(\"auto_center_pivot\", false);\n_tweenimator.Call(\"scale_to\", GetNode<Control>(\"Panel\"), 1.1f, 0.2);\n"
	},
	"new": {
		"group": "Setup",
		"title": "new()",
		"summary": "Construct an empty manager. It does not create or require a Tween.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    var inferred := Tweenimator.new()\n    var shared := Tweenimator.new(self, Tween.TRANS_BACK)\n    inferred.move_left($Sprite2D, 100)\n    shared.fade_out($Panel)\n",
		"returns": "A new Tweenimator instance.",
		"notes": "Without a default owner, Node-target effects bind to the target. With one, they bind to that owner. create(name, owner) can override the owner for a specific named animation.",
		"params": {
			"owner": "Optional default owner; null lets Node-target effects infer ownership from their target.",
			"transition": "Default transition curve for future created Tweens. Defaults to Tween.TRANS_SINE."
		},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "private readonly GodotObject _tweenimator =\n    (GodotObject)GD.Load<GDScript>(\"res://addons/tween_animation/src/tweenimator.gd\").New();\n\n// Alternative, inside an existing method, to use this controller as owner:\nvar script = GD.Load<GDScript>(\"res://addons/tween_animation/src/tweenimator.gd\");\nvar controlled = (GodotObject)script.New(this);\n"
	},
	"create": {
		"group": "Named registry",
		"title": "create()",
		"summary": "Create and store a named Tween, ready for any Godot Tween operations.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    var intro := animator.create(&\"intro\", self)\n    intro.tween_property($Panel, \"modulate:a\", 0.0, 0.5)\n    intro.tween_interval(0.2)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Replaces and kills an existing Tween using that name. Append operations immediately; an empty Tween cannot stay active indefinitely. Explicit owner takes precedence over the default owner.",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "var intro = (Tween)_tweenimator.Call(\"create\", new StringName(\"intro\"), this).AsGodotObject();\nintro.SetParallel(true);\nintro.TweenProperty(GetNode<Control>(\"Panel\"), \"position:x\", 100.0f, 0.4);\nintro.TweenProperty(GetNode<Control>(\"Panel\"), \"modulate:a\", 1.0f, 0.4);\nintro.Chain().TweenInterval(0.2);\nintro.TweenCallback(Callable.From(() => GD.Print(\"Finished\")));\n"
	},
	"store": {
		"group": "Named registry",
		"title": "store()",
		"summary": "Store an existing Tween under a name and return the identical object.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    var external := create_tween()\n    external.tween_interval(1.0)\n    animator.store(&\"external\", external)\n    # A helper-created Tween can be stored the same way.\n    animator.store(&\"slide\", animator.move_left($Sprite2D, 100))\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Does not rebind, rebuild or change an adopted Tween. Finished entries clean themselves up. replace=false rejects a live duplicate and returns null without killing either Tween.",
		"params": {
			"replace": "Whether a duplicate name replaces and kills its previous Tween. Defaults to true."
		},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "var external = CreateTween();\nexternal.TweenProperty(GetNode<Control>(\"Panel\"), \"modulate:a\", 0.0f, 0.5);\n_tweenimator.Call(\"store\", new StringName(\"external\"), external);\n"
	},
	"get_tween": {
		"group": "Named registry",
		"title": "get_tween()",
		"summary": "Safely retrieve a named live Tween, pruning an invalid entry.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.store(&\"slide\", animator.move_left($Sprite2D, 100))\n    var slide := animator.get_tween(&\"slide\")\n    if slide:\n        slide.pause()\n",
		"returns": "The stored Tween, or null when missing, completed/invalid or externally killed.",
		"notes": "",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "var slide = (Tween)_tweenimator.Call(\"move_left\", GetNode<Node2D>(\"Sprite2D\"), 100.0f, 0.3).AsGodotObject();\n_tweenimator.Call(\"store\", new StringName(\"slide\"), slide);\nvar found = _tweenimator.Call(\"get_tween\", new StringName(\"slide\")).AsGodotObject() as Tween;\nif (found != null) found.Pause();\n"
	},
	"has_tween": {
		"group": "Named registry",
		"title": "has_tween()",
		"summary": "Check whether a valid stored Tween exists, including a paused Tween.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.store(&\"slide\", animator.move_left($Sprite2D, 100))\n    if animator.has_tween(&\"slide\"):\n        animator.pause(&\"slide\")\n",
		"returns": "bool: true for a valid entry; false otherwise.",
		"notes": "",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "var slide = (Tween)_tweenimator.Call(\"move_left\", GetNode<Node2D>(\"Sprite2D\"), 100.0f, 0.3).AsGodotObject();\n_tweenimator.Call(\"store\", new StringName(\"slide\"), slide);\nif (_tweenimator.Call(\"has_tween\", new StringName(\"slide\")).AsBool())\n    _tweenimator.Call(\"pause\", new StringName(\"slide\"));\n"
	},
	"list_tweens": {
		"group": "Named registry",
		"title": "list_tweens()",
		"summary": "Get names of valid entries and remove invalid ones.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.store(&\"slide\", animator.move_left($Sprite2D, 100))\n    for name in animator.list_tweens():\n        print(name)\n",
		"returns": "Array[StringName].",
		"notes": "",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "var slide = (Tween)_tweenimator.Call(\"move_left\", GetNode<Node2D>(\"Sprite2D\"), 100.0f, 0.3).AsGodotObject();\n_tweenimator.Call(\"store\", new StringName(\"slide\"), slide);\nvar names = _tweenimator.Call(\"list_tweens\").AsGodotArray();\nforeach (var name in names) GD.Print(name);\n"
	},
	"pause": {
		"group": "Playback",
		"title": "pause()",
		"summary": "Pause one live named Tween.",
		"code": "func _on_pause_pressed() -> void:\n    tweenimator.pause(&\"intro\")\n",
		"returns": "void.",
		"notes": "Missing names are harmless. pause() preserves progress; resume() does not replay a completed Tween. stop_named() kills the whole Tween and does not restore prior property values. The example assumes intro was created earlier; connect the matching button to this handler.",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "_tweenimator.Call(\"pause\", new StringName(\"intro\"));\n"
	},
	"resume": {
		"group": "Playback",
		"title": "resume()",
		"summary": "Resume one paused named Tween.",
		"code": "func _on_continue_pressed() -> void:\n    tweenimator.resume(&\"intro\")\n",
		"returns": "void.",
		"notes": "Missing names are harmless. pause() preserves progress; resume() does not replay a completed Tween. stop_named() kills the whole Tween and does not restore prior property values. The example assumes intro was created earlier; connect the matching button to this handler.",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "_tweenimator.Call(\"resume\", new StringName(\"intro\"));\n"
	},
	"stop_named": {
		"group": "Playback",
		"title": "stop_named()",
		"summary": "Kill a named Tween and remove its registry/replacement tracking.",
		"code": "func _on_cancel_pressed() -> void:\n    tweenimator.stop_named(&\"intro\")\n",
		"returns": "void.",
		"notes": "Missing names are harmless. pause() preserves progress; resume() does not replay a completed Tween. stop_named() kills the whole Tween and does not restore prior property values. The example assumes intro was created earlier; connect the matching button to this handler.",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "_tweenimator.Call(\"stop_named\", new StringName(\"intro\"));\n"
	},
	"release": {
		"group": "Named registry",
		"title": "release()",
		"summary": "Remove a name and helper replacement tracking without killing the Tween.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.store(&\"slide\", animator.move_left($Sprite2D, 100))\n    var slide := animator.release(&\"slide\")\n    if slide:\n        slide.tween_interval(0.2)\n",
		"returns": "The detached Tween, or null if no valid entry exists.",
		"notes": "Other code may continue using the returned object. If the same Tween has other names, those aliases remain managed.",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "var returned = _tweenimator.Call(\"release\", new StringName(\"slide\")).AsGodotObject() as Tween;\nif (returned != null) returned.TweenInterval(0.2);\n"
	},
	"clear": {
		"group": "Playback",
		"title": "clear()",
		"summary": "Remove all named entries, optionally killing them.",
		"code": "tweenimator.clear(false) # Forget named handles, keep their animations running.\n",
		"returns": "void.",
		"notes": "clear() defaults to killing all named entries. Unnamed helper effects are unaffected; use stop_all() for both.",
		"params": {
			"kill_tweens": "true (default) kills entries; false releases names and replacement tracking without killing them."
		},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "_tweenimator.Call(\"clear\", false); // Release names, keep playing.\n"
	},
	"stop": {
		"group": "Playback",
		"title": "stop()",
		"summary": "Stop helper-created effects for a target, optionally on one property.",
		"code": "func _on_drag_started() -> void:\n    tweenimator.stop($Sprite2D, ^\"position\") # Let player dragging take over.\n",
		"returns": "void.",
		"notes": "Omit property to stop every helper effect for this target. This does not infer properties inside adopted external Tweens; use stop_named() for those.",
		"params": {
			"property": "Optional property channel, such as ^\"position\". Empty NodePath stops all helper channels for the target."
		},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "_tweenimator.Call(\"stop\", GetNode<Node2D>(\"Sprite2D\"), new NodePath(\"position\"));\n"
	},
	"stop_all": {
		"group": "Playback",
		"title": "stop_all()",
		"summary": "Kill all named entries and all other effects made by this manager.",
		"code": "func _on_leaving_screen() -> void:\n    tweenimator.stop_all()\n",
		"returns": "void.",
		"notes": "Released Tweens are no longer managed and keep running. Property values remain where they were sampled.",
		"params": {},
		"targets": [
			"Any Tween"
		],
		"target_note": "Target-independent: these operations manage Godot Tweens, including animations used in 2D, 3D or UI.",
		"csharp": "_tweenimator.Call(\"stop_all\");\n"
	},
	"custom": {
		"group": "Advanced",
		"title": "custom()",
		"summary": "Create a Tween for any writable, Tween-compatible property.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    var tween := animator.custom($Sprite2D, ^\"position:x\", 100.0, 0.5)\n    tween.tween_interval(0.2)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Creates its own Tween and participates in same-target/property replacement. transition=-1 uses the manager default. Resource targets need a default owner. This does not import arbitrary procedural Tween scripts.",
		"params": {
			"property": "Tween-compatible property/subproperty NodePath, e.g. ^\"position:x\" or ^\"modulate:a\".",
			"value": "Destination matching the property type.",
			"transition": "-1 uses the manager default; otherwise a Tween.TransitionType integer."
		},
		"targets": [
			"2D",
			"3D",
			"UI",
			"Audio",
			"Shader resources"
		],
		"target_note": "Any writable Tween-compatible property with a matching destination type. Resource targets need a default owner.",
		"csharp": "_tweenimator.Call(\"custom\", GetNode<Node2D>(\"Sprite2D\"), new NodePath(\"position:x\"), 100.0f, 0.5);\n"
	},
	"move_to": {
		"group": "Movement",
		"title": "move_to()",
		"summary": "Move to an absolute position in parent coordinates.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.move_to($Sprite2D, Vector2(100, 40), 0.3)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Node2D/Control use Vector2; Node3D uses Vector3. Container layout may override Control position. Parent axes are used, not camera or target-facing axes.",
		"params": {
			"value": "Vector2 for 2D/UI, Vector3 for 3D."
		},
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Node2D, Node3D or Control. Use Vector2 for 2D/UI and Vector3 for 3D where a vector is required.",
		"csharp": "_tweenimator.Call(\"move_to\", GetNode<Node2D>(\"Sprite2D\"), new Vector2(100, 40), 0.3);\n"
	},
	"move_by": {
		"group": "Movement",
		"title": "move_by()",
		"summary": "Move by an offset sampled from the current position.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.move_by($Sprite2D, Vector2(-100, 0), 0.3)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Node2D/Control use Vector2; Node3D uses Vector3. Container layout may override Control position. Parent axes are used, not camera or target-facing axes.",
		"params": {
			"offset": "Vector2 for 2D/UI, Vector3 for 3D."
		},
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Node2D, Node3D or Control. Use Vector2 for 2D/UI and Vector3 for 3D where a vector is required.",
		"csharp": "_tweenimator.Call(\"move_by\", GetNode<Node2D>(\"Sprite2D\"), new Vector2(-100, 0), 0.3);\n"
	},
	"move_left": {
		"group": "Movement",
		"title": "move_left()",
		"summary": "Move in negative parent X.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.move_left($Sprite2D, 100, 0.3)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Direction uses the parent coordinate axes. Distances are scene units (normally pixels for 2D/UI). Forward/back require Node3D.",
		"params": {
			"distance": "Signed distance in parent coordinates. A positive value moves in the named direction. Default 1.0."
		},
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Node2D, Node3D or Control. Use Vector2 for 2D/UI and Vector3 for 3D where a vector is required.",
		"csharp": "_tweenimator.Call(\"move_left\", GetNode<Node2D>(\"Sprite2D\"), 100.0f, 0.3);\n"
	},
	"move_right": {
		"group": "Movement",
		"title": "move_right()",
		"summary": "Move in positive parent X.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.move_right($Sprite2D, 100, 0.3)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Direction uses the parent coordinate axes. Distances are scene units (normally pixels for 2D/UI). Forward/back require Node3D.",
		"params": {
			"distance": "Signed distance in parent coordinates. A positive value moves in the named direction. Default 1.0."
		},
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Node2D, Node3D or Control. Use Vector2 for 2D/UI and Vector3 for 3D where a vector is required.",
		"csharp": "_tweenimator.Call(\"move_right\", GetNode<Node2D>(\"Sprite2D\"), 100.0f, 0.3);\n"
	},
	"move_up": {
		"group": "Movement",
		"title": "move_up()",
		"summary": "Move up: -Y in 2D/UI, +Y in 3D.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.move_up($Sprite2D, 100, 0.3)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Direction uses the parent coordinate axes. Distances are scene units (normally pixels for 2D/UI). Forward/back require Node3D.",
		"params": {
			"distance": "Signed distance in parent coordinates. A positive value moves in the named direction. Default 1.0."
		},
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Node2D, Node3D or Control. Use Vector2 for 2D/UI and Vector3 for 3D where a vector is required.",
		"csharp": "_tweenimator.Call(\"move_up\", GetNode<Node2D>(\"Sprite2D\"), 100.0f, 0.3);\n"
	},
	"move_down": {
		"group": "Movement",
		"title": "move_down()",
		"summary": "Move down: +Y in 2D/UI, -Y in 3D.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.move_down($Sprite2D, 100, 0.3)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Direction uses the parent coordinate axes. Distances are scene units (normally pixels for 2D/UI). Forward/back require Node3D.",
		"params": {
			"distance": "Signed distance in parent coordinates. A positive value moves in the named direction. Default 1.0."
		},
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Node2D, Node3D or Control. Use Vector2 for 2D/UI and Vector3 for 3D where a vector is required.",
		"csharp": "_tweenimator.Call(\"move_down\", GetNode<Node2D>(\"Sprite2D\"), 100.0f, 0.3);\n"
	},
	"move_forward": {
		"group": "Movement",
		"title": "move_forward()",
		"summary": "Move along parent -Z.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.move_forward($MeshInstance3D, 2, 0.3)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Direction uses the parent coordinate axes. Distances are scene units (normally pixels for 2D/UI). Forward/back require Node3D.",
		"params": {
			"distance": "Signed distance in parent coordinates. A positive value moves in the named direction. Default 1.0."
		},
		"targets": [
			"3D"
		],
		"target_note": "Node3D only. Forward/back follow the parent Z axis, not the camera.",
		"csharp": "_tweenimator.Call(\"move_forward\", GetNode<Node3D>(\"MeshInstance3D\"), 2.0f, 0.3);\n"
	},
	"move_back": {
		"group": "Movement",
		"title": "move_back()",
		"summary": "Move along parent +Z.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.move_back($MeshInstance3D, 2, 0.3)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Direction uses the parent coordinate axes. Distances are scene units (normally pixels for 2D/UI). Forward/back require Node3D.",
		"params": {
			"distance": "Signed distance in parent coordinates. A positive value moves in the named direction. Default 1.0."
		},
		"targets": [
			"3D"
		],
		"target_note": "Node3D only. Forward/back follow the parent Z axis, not the camera.",
		"csharp": "_tweenimator.Call(\"move_back\", GetNode<Node3D>(\"MeshInstance3D\"), 2.0f, 0.3);\n"
	},
	"scale_to": {
		"group": "Transform",
		"title": "scale_to()",
		"summary": "Scale to a uniform multiplier or an explicit scale vector.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.scale_to($Panel, 1.1, 0.2)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Supports Node2D, Node3D and Control. UI pivots are centered unless auto_center_pivot=false. A number selects Vector2/Vector3 automatically.",
		"params": {
			"value": "Number for uniform scale; Vector2 for 2D/UI; Vector3 for 3D."
		},
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Node2D, Node3D or Control. Use Vector2 for 2D/UI and Vector3 for 3D where a vector is required.",
		"csharp": "_tweenimator.Call(\"scale_to\", GetNode<Control>(\"Panel\"), 1.1f, 0.2);\n"
	},
	"scale_up": {
		"group": "Transform",
		"title": "scale_up()",
		"summary": "Multiply the current scale by 1 + amount.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.scale_up($Panel, 0.1, 0.2)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Works on Node2D, Node3D and Control. This scales from the current value; it is not an absolute size preset.",
		"params": {
			"amount": "Fractional scale change, default 0.1 (10 percent)."
		},
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Node2D, Node3D or Control. Use Vector2 for 2D/UI and Vector3 for 3D where a vector is required.",
		"csharp": "_tweenimator.Call(\"scale_up\", GetNode<Control>(\"Panel\"), 0.1f, 0.2);\n"
	},
	"scale_down": {
		"group": "Transform",
		"title": "scale_down()",
		"summary": "Multiply the current scale by 1 - amount, clamping amount to 0-1.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.scale_down($Panel, 0.1, 0.2)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Works on Node2D, Node3D and Control. This scales from the current value; it is not an absolute size preset.",
		"params": {
			"amount": "Fractional scale change, default 0.1 (10 percent)."
		},
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Node2D, Node3D or Control. Use Vector2 for 2D/UI and Vector3 for 3D where a vector is required.",
		"csharp": "_tweenimator.Call(\"scale_down\", GetNode<Control>(\"Panel\"), 0.1f, 0.2);\n"
	},
	"rotate_to": {
		"group": "Transform",
		"title": "rotate_to()",
		"summary": "Rotate to an absolute angle expressed in radians.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.rotate_to($Sprite2D, PI / 2.0, 0.3)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Use a number for Node2D/Control or Vector3 Euler radians for Node3D. UI pivots can be centered automatically.",
		"params": {
			"radians": "Number for 2D/UI; Vector3 for 3D. This is an absolute destination, not a relative increment."
		},
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Node2D, Node3D or Control. Use Vector2 for 2D/UI and Vector3 for 3D where a vector is required.",
		"csharp": "_tweenimator.Call(\"rotate_to\", GetNode<Node2D>(\"Sprite2D\"), Mathf.Pi / 2.0f, 0.3);\n"
	},
	"rotate_degrees": {
		"group": "Transform",
		"title": "rotate_degrees()",
		"summary": "Rotate to an absolute angle expressed in degrees.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.rotate_degrees($MeshInstance3D, Vector3(0, 90, 0), 0.3)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Converts to radians internally and uses the same rotation replacement channel as rotate_to().",
		"params": {
			"degrees": "Number for 2D/UI; Vector3 for 3D."
		},
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Node2D, Node3D or Control. Use Vector2 for 2D/UI and Vector3 for 3D where a vector is required.",
		"csharp": "_tweenimator.Call(\"rotate_degrees\", GetNode<Node3D>(\"MeshInstance3D\"), new Vector3(0, 90, 0), 0.3);\n"
	},
	"press": {
		"group": "Effects",
		"title": "press()",
		"summary": "Shrink and return to the captured starting scale as a two-phase effect.",
		"code": "func _on_button_pressed() -> void:\n    tweenimator.press($Button)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Supports Node2D, Node3D and Control. Repeated presses preserve the initial rest scale. UI pivots are centered unless opted out.",
		"params": {
			"amount": "Shrink fraction, clamped to 0-1. Default 0.05 (5 percent).",
			"duration_down": "Shrink duration in seconds; default 0.1.",
			"duration_up": "Return duration in seconds; default 0.2."
		},
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Node2D, Node3D or Control. Use Vector2 for 2D/UI and Vector3 for 3D where a vector is required.",
		"csharp": "_tweenimator.Call(\"press\", GetNode<Button>(\"Button\"));\n"
	},
	"wiggle": {
		"group": "Effects",
		"title": "wiggle()",
		"summary": "Oscillate rotation and return to its original value.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.wiggle($Sprite2D, 0.15, 0.4, 2)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "2D/UI oscillates the scalar angle; 3D oscillates around Y. UI pivot handling and same-property replacement apply.",
		"params": {
			"strength": "Angular excursion in radians; default 0.15.",
			"loops": "Number of oscillations, at least 1. duration covers the whole effect."
		},
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Node2D, Node3D or Control. Use Vector2 for 2D/UI and Vector3 for 3D where a vector is required.",
		"csharp": "_tweenimator.Call(\"wiggle\", GetNode<Node2D>(\"Sprite2D\"), 0.15f, 0.4, 2);\n"
	},
	"fade_to": {
		"group": "Effects",
		"title": "fade_to()",
		"summary": "Fade to a clamped alpha value.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.fade_to($Panel, 0.3, 0.5)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "CanvasItem only: 2D and UI, not arbitrary Node3D transparency. Uses the modulate:a replacement channel.",
		"params": {
			"alpha": "Destination alpha, clamped to 0-1."
		},
		"targets": [
			"2D",
			"UI"
		],
		"target_note": "CanvasItem only. This does not control transparency on an arbitrary Node3D.",
		"csharp": "_tweenimator.Call(\"fade_to\", GetNode<Control>(\"Panel\"), 0.3f, 0.5);\n"
	},
	"fade_in": {
		"group": "Effects",
		"title": "fade_in()",
		"summary": "Fade toward alpha 1 from the current value.",
		"code": "$Panel.modulate.a = 0.0\ntweenimator.fade_in($Panel, 0.3)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "CanvasItem only: 2D and UI, not arbitrary Node3D transparency. Uses the modulate:a replacement channel.",
		"params": {
			"alpha": "Destination alpha, clamped to 0-1."
		},
		"targets": [
			"2D",
			"UI"
		],
		"target_note": "CanvasItem only. This does not control transparency on an arbitrary Node3D.",
		"csharp": "GetNode<Control>(\"Panel\").Modulate = new Color(1, 1, 1, 0);\n_tweenimator.Call(\"fade_in\", GetNode<Control>(\"Panel\"), 0.3);\n"
	},
	"fade_out": {
		"group": "Effects",
		"title": "fade_out()",
		"summary": "Fade toward alpha 0 from the current value.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.fade_out($Panel, 0.5)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "CanvasItem only: 2D and UI, not arbitrary Node3D transparency. Uses the modulate:a replacement channel.",
		"params": {
			"alpha": "Destination alpha, clamped to 0-1."
		},
		"targets": [
			"2D",
			"UI"
		],
		"target_note": "CanvasItem only. This does not control transparency on an arbitrary Node3D.",
		"csharp": "_tweenimator.Call(\"fade_out\", GetNode<Control>(\"Panel\"), 0.3);\n"
	},
	"resize_to": {
		"group": "Effects",
		"title": "resize_to()",
		"summary": "Request a Control size through a Tween.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.resize_to($Panel, Vector2(240, 100), 0.3)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Containers and minimum size can override or constrain this property.",
		"params": {
			"value": "Destination size as Vector2, in Control coordinate units."
		},
		"targets": [
			"UI"
		],
		"target_note": "Control only. Containers and minimum size can override or constrain its layout.",
		"csharp": "_tweenimator.Call(\"resize_to\", GetNode<Control>(\"Panel\"), new Vector2(240, 100), 0.3);\n"
	},
	"set_volume": {
		"group": "Advanced",
		"title": "set_volume()",
		"summary": "Tween the volume_db property of an audio player.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.set_volume($AudioStreamPlayer, -12.0, 0.5)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Accepts AudioStreamPlayer, AudioStreamPlayer2D and AudioStreamPlayer3D.",
		"params": {
			"decibels": "Destination volume in dB, default 0.0. Negative values attenuate the audio."
		},
		"targets": [
			"Audio"
		],
		"target_note": "AudioStreamPlayer, AudioStreamPlayer2D or AudioStreamPlayer3D. This changes volume, not a visual node property.",
		"csharp": "_tweenimator.Call(\"set_volume\", GetNode<AudioStreamPlayer>(\"AudioStreamPlayer\"), -12.0f, 0.5);\n"
	},
	"shader_transition": {
		"group": "Advanced",
		"title": "shader_transition()",
		"summary": "Tween a ShaderMaterial uniform.",
		"code": "var material := $Sprite2D.material as ShaderMaterial\ntweenimator.shader_transition(material, \"dissolve\", 1.0, 0.5)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "The manager needs a default owner (e.g. new(self)); ShaderMaterial is not a Node. Uniform type must support Tween interpolation. This example assumes the Sprite2D already uses a shader with a float uniform named dissolve.",
		"params": {
			"material": "ShaderMaterial with the parameter defined in its shader.",
			"parameter": "Uniform name without the shader_parameter/ prefix.",
			"value": "Destination matching the uniform type."
		},
		"targets": [
			"Shader resources"
		],
		"target_note": "ShaderMaterial uniform, not a spatial-node effect. Use an explicit owner Node for the manager.",
		"csharp": "_tweenimator.Set(\"node\", this); // Resource effects need an owner.\nvar material = (ShaderMaterial)GetNode<Sprite2D>(\"Sprite2D\").Material;\n_tweenimator.Call(\"shader_transition\", material, \"dissolve\", 1.0f, 0.5); // Requires a default owner.\n"
	},
	"method": {
		"group": "Advanced",
		"title": "method()",
		"summary": "Animate values supplied to a Callable instead of an object property.",
		"code": "var update_score := func(value: float): $Label.text = \"Score: %d\" % roundi(value)\nvar counter := tweenimator.method(update_score, 0.0, 100.0, 1.0)\ntweenimator.store(&\"score_counter\", counter)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Needs a default owner. Returned Tween can be named, chained and awaited. stop_all() includes these callback effects.",
		"params": {
			"callback": "Valid Callable accepting an interpolated value.",
			"from": "Starting value.",
			"to": "Ending value; must be compatible with from."
		},
		"targets": [
			"Callbacks"
		],
		"target_note": "Interpolates values into your Callable; no spatial target is assumed. Supply a default owner Node.",
		"csharp": "_tweenimator.Set(\"node\", this); // Callback effects need an owner.\nvar update = Callable.From<float>(value => GetNode<Label>(\"Label\").Text = $\"Score: {Mathf.RoundToInt(value)}\");\nvar counter = (Tween)_tweenimator.Call(\"method\", update, 0.0f, 100.0f, 1.0).AsGodotObject();\n_tweenimator.Call(\"store\", new StringName(\"score_counter\"), counter);\n"
	}
}

const VISUAL := {
	"guide_visual_start": {
		"group": "Visual guides",
		"title": "Create your first clip",
		"summary": "Turn two scene poses into an animation.",
		"steps": [
			"Open a scene and select a Node2D, Node3D or Control in the Scene tree.",
			"Open Tweenimation → Timeline. Choose a property such as position; for a UI fade use modulate:a.",
			"Add track. At 0 seconds, leave Value empty and Capture key to record the current pose.",
			"Move the playhead to 1 second. Change the property in the Inspector or scene view, then Capture key again.",
			"Use Play preview, then Save the clip as an Animation .tres resource."
		],
		"notes": "Position uses Vector2 in 2D/UI and Vector3 in 3D. Container layout can override UI position and size. Preview writes into the open scene and leaves the last sampled values.",
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Uses the built-in Tweenimation timeline. No runtime helper or script required.",
		"visual_only": true,
		"params": {},
		"returns": ""
	},
	"timeline_add_track": {
		"group": "Timeline controls",
		"title": "Add a property track",
		"summary": "One track describes one property changing over time.",
		"steps": [
			"Select the scene node you want to animate.",
			"Press + Track. Pick a property from the selected node or type its path in the dialog. UI opacity is modulate:a.",
			"Choose Add track. Use the active-track selector to choose the track you are editing."
		],
		"notes": "The timeline authors value tracks. It does not author specialized skeleton tracks, callbacks or arbitrary procedural Tween chains.",
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Uses the built-in Tweenimation timeline. No runtime helper or script required.",
		"visual_only": true,
		"params": {},
		"returns": ""
	},
	"timeline_capture": {
		"group": "Timeline controls",
		"title": "Capture keyframes",
		"summary": "Save the current node value at a chosen time.",
		"steps": [
			"Choose an active track.",
			"Click and drag directly on the timeline to position the playhead. Release to stop scrubbing.",
			"Current shows the tracked node’s live value. Choose Override to edit the same X/Y/Z or scalar fields for this key without changing the node.",
			"Choose Capture. Drag the playhead directly along the timeline and repeat at another time with a different value."
		],
		"notes": "Scrub to the desired time before changing the node, because scrubbing may sample the existing animation. Capturing at the same track/time replaces that key.",
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Uses the built-in Tweenimation timeline. No runtime helper or script required.",
		"visual_only": true,
		"params": {},
		"returns": ""
	},
	"timeline_preview": {
		"group": "Timeline controls",
		"title": "Preview and rewind",
		"summary": "See the interpolated movement in the scene editor.",
		"steps": [
			"Choose Play preview.",
			"Switch to Godot’s 2D or 3D editor to watch the scene while playback continues.",
			"Return to Tweenimation to pause. Rewind stops playback and samples the start."
		],
		"notes": "There is no embedded scene viewport. Preview affects the open scene; it does not automatically restore its original property values.",
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Uses the built-in Tweenimation timeline. No runtime helper or script required.",
		"visual_only": true,
		"params": {},
		"returns": ""
	},
	"timeline_save": {
		"group": "Timeline controls",
		"title": "Save and open clips",
		"summary": "Keep a reusable Godot Animation resource.",
		"steps": [
			"Choose Save or Save As and save a .tres Animation resource.",
			"Choose Open to load a saved Animation resource.",
			"Keep a scene open with node paths that match the clip’s tracks."
		],
		"notes": "A saved clip is an Animation resource. It is separate from the runtime Tweenimator named-Tween dictionary. Non-value tracks are not edited or previewed by the value-track controls.",
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Uses the built-in Tweenimation timeline. No runtime helper or script required.",
		"visual_only": true,
		"params": {},
		"returns": ""
	},
	"guide_visual_player": {
		"group": "Visual guides",
		"title": "Play without writing code",
		"summary": "Use Godot’s AnimationPlayer to play your saved clip.",
		"steps": [
			"Add an AnimationPlayer as a child of the scene root used when authoring.",
			"In the Animation panel, create/select an AnimationLibrary and load your saved .tres Animation into it.",
			"Keep the player’s Root Node pointed at the authored scene root (the default .. for this placement).",
			"Use the Animation panel’s play control to preview it. Enable Autoplay on Load for the animation if it should run when the scene starts."
		],
		"notes": "Import your existing Animation resource rather than creating an empty replacement. Autoplay is a Godot AnimationPlayer editor feature; the runtime helper is not needed for this workflow.",
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Uses the built-in Tweenimation timeline. No runtime helper or script required.",
		"visual_only": true,
		"params": {},
		"returns": ""
	},
	"guide_visual_existing": {
		"group": "Visual guides",
		"title": "Bring an existing animation",
		"summary": "Reuse existing Animation resources in the timeline.",
		"steps": [
			"For an AnimationPlayer clip, save its Animation resource as .tres using the resource inspector.",
			"In Tweenimation, use Open to choose that resource.",
			"Select a matching scene and edit its value tracks."
		],
		"notes": "A running code-created Tween cannot be imported as a clip. Recreate its property values/timing as keys, or switch the top-right selector to a code view to learn how to manage the existing Tween.",
		"targets": [
			"2D",
			"3D",
			"UI"
		],
		"target_note": "Uses the built-in Tweenimation timeline. No runtime helper or script required.",
		"visual_only": true,
		"params": {},
		"returns": ""
	}
}
