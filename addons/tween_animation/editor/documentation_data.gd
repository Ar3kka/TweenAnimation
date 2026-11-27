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
		"params": {}
	},
	"guide_names": {
		"group": "Start here",
		"title": "Store, name and retrieve",
		"summary": "Keep the returned Tween reference, give it a name, then choose direct or safe access.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    var slide := animator.move_left($Sprite2D, 100, 0.3)\n    animator.store(&\"slide\", slide)\n    # Same object: storing does not create a second animation.\n    var same: Tween = animator.tweens[&\"slide\"]\n    same.pause()\n    # Safe lookup when a name might have finished or been removed.\n    var found := animator.get_tween(&\"slide\")\n    if found:\n        animator.resume(&\"slide\")\n",
		"returns": "",
		"notes": "Names are local to one Tweenimator. Finished entries are removed automatically. Reusing a name kills the old Tween by default; store(name, tween, false) rejects a duplicate. Direct dictionary writes bypass validation and finished cleanup. Externally killed entries are pruned on get_tween()/list_tweens().",
		"params": {}
	},
	"guide_external": {
		"group": "Start here",
		"title": "Bring your own Tween",
		"summary": "Register a Tween made anywhere else without altering its existing owner, easing, progress, or operations.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    # This Tween predates its manager.\n    var external := create_tween()\n    external.set_trans(Tween.TRANS_LINEAR)\n    external.tween_property($Sprite2D, \"position:x\", 100.0, 1.0)\n    var animator := Tweenimator.new()\n    animator.store(&\"external\", external)\n    animator.pause(&\"external\")\n    animator.resume(&\"external\")\n    # Hand it back: release removes tracking, not playback.\n    var returned := animator.release(&\"external\")\n    returned.tween_interval(0.2)\n",
		"returns": "",
		"notes": "store() accepts a valid Godot Tween; it does not inspect property tracks or convert scripts into timeline resources. External Tweens are managed by name, not by inferred target/property replacement channels. A Tween can have aliases: release every name to fully detach it.",
		"params": {}
	},
	"guide_chains": {
		"group": "Start here",
		"title": "Chains, parallel groups and completion",
		"summary": "Build sequences or parallel groups using ordinary Godot operations on the Tween returned by Tweenimator.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    var intro := animator.create(&\"intro\", self)\n    intro.set_parallel(true)\n    intro.tween_property($Panel, \"position:x\", 100.0, 0.4)\n    intro.tween_property($Panel, \"modulate:a\", 1.0, 0.4)\n    # chain() starts the next sequential group after the parallel group.\n    intro.chain().tween_interval(0.2)\n    intro.tween_callback(func(): print(\"Intro finished\"))\n    await intro.finished\n    print(\"Continue game logic here\")\n",
		"returns": "",
		"notes": "Append operations before the next process frame. Tweens are sequential unless configured otherwise. Finished Tweens cannot be replayed; call a function that creates a fresh Tween. Killed Tweens do not emit finished. Replacing a named/helper effect cancels its whole Tween, including any appended steps.",
		"params": {}
	},
	"guide_replay": {
		"group": "Start here",
		"title": "Pause, stop and replay",
		"summary": "Pause an active animation, resume it, or call its factory function to start a new run.",
		"code": "extends Node\n\nvar animator := Tweenimator.new()\n\nfunc _ready() -> void:\n    play_intro()\n    animator.pause(&\"intro\")\n    animator.resume(&\"intro\")\n\n# Connect a button or input action to this function to replay.\nfunc play_intro() -> void:\n    var intro := animator.create(&\"intro\", self)\n    intro.tween_property($Panel, \"modulate:a\", 0.3, 0.5)\n    intro.tween_property($Panel, \"modulate:a\", 1.0, 0.5)\n\nfunc cancel_intro() -> void:\n    animator.stop_named(&\"intro\")\n",
		"returns": "",
		"notes": "pause/resume work only on live entries. A completed Tween must be recreated. create() replaces an existing name, so replaying the factory cancels a previous run automatically.",
		"params": {}
	},
	"guide_settings": {
		"group": "Configuration",
		"title": "Properties and defaults",
		"summary": "Configuration is shared by newly created helper Tweens. Existing external Tweens are not modified by store().",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.transition_type = Tween.TRANS_BACK\n    animator.ease_type = Tween.EASE_OUT\n    # Preserve an intentionally placed Control pivot.\n    animator.auto_center_pivot = false\n    animator.scale_to($Panel, 1.1, 0.2)\n    print(animator.list_tweens())\n",
		"returns": "",
		"notes": "Public fields: node: Node (optional default owner); tweens: Dictionary[StringName, Tween] (named handles); transition_type: Tween.TransitionType (Sine); ease_type: Tween.EaseType (In-Out); auto_center_pivot: bool (true); random: RandomNumberGenerator (available for your own randomized effects; built-in effects are deterministic).",
		"params": {}
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
		}
	},
	"create": {
		"group": "Named registry",
		"title": "create()",
		"summary": "Create and store a named Tween, ready for any Godot Tween operations.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    var intro := animator.create(&\"intro\", self)\n    intro.tween_property($Panel, \"modulate:a\", 0.0, 0.5)\n    intro.tween_interval(0.2)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Replaces and kills an existing Tween using that name. Append operations immediately; an empty Tween cannot stay active indefinitely. Explicit owner takes precedence over the default owner.",
		"params": {}
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
		}
	},
	"get_tween": {
		"group": "Named registry",
		"title": "get_tween()",
		"summary": "Safely retrieve a named live Tween, pruning an invalid entry.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.store(&\"slide\", animator.move_left($Sprite2D, 100))\n    var slide := animator.get_tween(&\"slide\")\n    if slide:\n        slide.pause()\n",
		"returns": "The stored Tween, or null when missing, completed/invalid or externally killed.",
		"notes": "",
		"params": {}
	},
	"has_tween": {
		"group": "Named registry",
		"title": "has_tween()",
		"summary": "Check whether a valid stored Tween exists, including a paused Tween.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.store(&\"slide\", animator.move_left($Sprite2D, 100))\n    if animator.has_tween(&\"slide\"):\n        animator.pause(&\"slide\")\n",
		"returns": "bool: true for a valid entry; false otherwise.",
		"notes": "",
		"params": {}
	},
	"list_tweens": {
		"group": "Named registry",
		"title": "list_tweens()",
		"summary": "Get names of valid entries and remove invalid ones.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.store(&\"slide\", animator.move_left($Sprite2D, 100))\n    for name in animator.list_tweens():\n        print(name)\n",
		"returns": "Array[StringName].",
		"notes": "",
		"params": {}
	},
	"pause": {
		"group": "Playback",
		"title": "pause()",
		"summary": "Pause one live named Tween.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.store(&\"slide\", animator.move_left($Sprite2D, 100))\n    animator.pause(&\"slide\")\n",
		"returns": "void.",
		"notes": "Missing names are harmless. pause() preserves progress; resume() does not replay a completed Tween. stop_named() kills the whole Tween and does not restore prior property values.",
		"params": {}
	},
	"resume": {
		"group": "Playback",
		"title": "resume()",
		"summary": "Resume one paused named Tween.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.store(&\"slide\", animator.move_left($Sprite2D, 100))\n    animator.resume(&\"slide\")\n",
		"returns": "void.",
		"notes": "Missing names are harmless. pause() preserves progress; resume() does not replay a completed Tween. stop_named() kills the whole Tween and does not restore prior property values.",
		"params": {}
	},
	"stop_named": {
		"group": "Playback",
		"title": "stop_named()",
		"summary": "Kill a named Tween and remove its registry/replacement tracking.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.store(&\"slide\", animator.move_left($Sprite2D, 100))\n    animator.stop_named(&\"slide\")\n",
		"returns": "void.",
		"notes": "Missing names are harmless. pause() preserves progress; resume() does not replay a completed Tween. stop_named() kills the whole Tween and does not restore prior property values.",
		"params": {}
	},
	"release": {
		"group": "Named registry",
		"title": "release()",
		"summary": "Remove a name and helper replacement tracking without killing the Tween.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.store(&\"slide\", animator.move_left($Sprite2D, 100))\n    var slide := animator.release(&\"slide\")\n    if slide:\n        slide.tween_interval(0.2)\n",
		"returns": "The detached Tween, or null if no valid entry exists.",
		"notes": "Other code may continue using the returned object. If the same Tween has other names, those aliases remain managed.",
		"params": {}
	},
	"clear": {
		"group": "Playback",
		"title": "clear()",
		"summary": "Remove all named entries, optionally killing them.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.store(&\"slide\", animator.move_left($Sprite2D, 100))\n    animator.clear(false) # Release all names, let them keep running.\n",
		"returns": "void.",
		"notes": "clear() defaults to killing all named entries. Unnamed helper effects are unaffected; use stop_all() for both.",
		"params": {
			"kill_tweens": "true (default) kills entries; false releases names and replacement tracking without killing them."
		}
	},
	"stop": {
		"group": "Playback",
		"title": "stop()",
		"summary": "Stop helper-created effects for a target, optionally on one property.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.move_left($Sprite2D, 100)\n    animator.fade_out($Sprite2D)\n    animator.stop($Sprite2D, ^\"position\") # Fade can continue.\n",
		"returns": "void.",
		"notes": "Omit property to stop every helper effect for this target. This does not infer properties inside adopted external Tweens; use stop_named() for those.",
		"params": {
			"property": "Optional property channel, such as ^\"position\". Empty NodePath stops all helper channels for the target."
		}
	},
	"stop_all": {
		"group": "Playback",
		"title": "stop_all()",
		"summary": "Kill all named entries and all other effects made by this manager.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.move_left($Sprite2D, 100)\n    animator.store(&\"fade\", animator.fade_out($Panel))\n    animator.stop_all()\n",
		"returns": "void.",
		"notes": "Released Tweens are no longer managed and keep running. Property values remain where they were sampled.",
		"params": {}
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
		}
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
		}
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
		}
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
		}
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
		}
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
		}
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
		}
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
		}
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
		}
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
		}
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
		}
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
		}
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
		}
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
		}
	},
	"press": {
		"group": "Effects",
		"title": "press()",
		"summary": "Shrink and return to the captured starting scale as a two-phase effect.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.press($Button, 0.05, 0.1, 0.2)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Supports Node2D, Node3D and Control. Repeated presses preserve the initial rest scale. UI pivots are centered unless opted out.",
		"params": {
			"amount": "Shrink fraction, clamped to 0-1. Default 0.05 (5 percent).",
			"duration_down": "Shrink duration in seconds; default 0.1.",
			"duration_up": "Return duration in seconds; default 0.2."
		}
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
		}
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
		}
	},
	"fade_in": {
		"group": "Effects",
		"title": "fade_in()",
		"summary": "Fade toward alpha 1 from the current value.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    animator.fade_in($Panel, 0.5)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "CanvasItem only: 2D and UI, not arbitrary Node3D transparency. Uses the modulate:a replacement channel.",
		"params": {
			"alpha": "Destination alpha, clamped to 0-1."
		}
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
		}
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
		}
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
		}
	},
	"shader_transition": {
		"group": "Advanced",
		"title": "shader_transition()",
		"summary": "Tween a ShaderMaterial uniform.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    var shader := Shader.new()\n    shader.code = \"shader_type canvas_item; uniform float amount = 0.0;\"\n    var material := ShaderMaterial.new()\n    material.shader = shader\n    material.set_shader_parameter(\"amount\", 0.0)\n    animator.shader_transition(material, \"amount\", 1.0, 0.5)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "The manager needs a default owner (e.g. new(self)); ShaderMaterial is not a Node. Uniform type must support Tween interpolation.",
		"params": {
			"material": "ShaderMaterial with the parameter defined in its shader.",
			"parameter": "Uniform name without the shader_parameter/ prefix.",
			"value": "Destination matching the uniform type."
		}
	},
	"method": {
		"group": "Advanced",
		"title": "method()",
		"summary": "Animate values supplied to a Callable instead of an object property.",
		"code": "extends Node\n\nfunc _ready() -> void:\n    var animator := Tweenimator.new(self)\n    var update := func(value: float): print(value)\n    var tween := animator.method(update, 0.0, 1.0, 0.5)\n    animator.store(&\"counter\", tween)\n",
		"returns": "Tween, or null if the target/owner/arguments are invalid.",
		"notes": "Needs a default owner. Returned Tween can be named, chained and awaited. stop_all() includes these callback effects.",
		"params": {
			"callback": "Valid Callable accepting an interpolated value.",
			"from": "Starting value.",
			"to": "Ending value; must be compatible with from."
		}
	}
}
