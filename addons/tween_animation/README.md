# Tweenimation

A Godot add-on for keeping track of individual Tweens, creating intent-first effects, and authoring property animations in a visual timeline. Built on the original Tween Animator implementation.

## Install

Copy `addons/tween_animation` into your project's `addons/` folder. Enable **Tweenimation** in **Project > Project Settings > Plugins**. The Setup tab offers centered 2D, 3D and UI entry points, visual walkthroughs, and paired native/helper code examples.

## Name your Tweens

`Tweenimator` is the runtime class. Its public `tweens` dictionary stores ordinary Godot Tween objects by StringName. You can construct it before your scene is ready, with no owner or existing Tween.

```gdscript
extends Node

var animate := Tweenimator.new()

func _ready() -> void:
    # This effect creates its own Tween, bound to the target Node.
    animate.store(&"slide", animate.move_left($Sprite2D, 100, 0.3))
    # The dictionary and the local handle refer to the exact same Tween.
    var slide: Tween = animate.tweens[&"slide"]
    slide.tween_interval(0.2)
    animate.pause(&"slide")
    animate.resume(&"slide")
```

Names belong to a particular Tweenimator instance. Share that instance with the scripts that should access its animations; separate instances have separate registries.

## Create here or bring an existing Tween

```gdscript
# Create a named animation with an explicit owner, then use any Godot operations.
var intro := animate.create(&"intro", self)
intro.set_parallel(true)
intro.tween_property($Panel, "position:x", 100.0, 0.4)
intro.tween_property($Panel, "modulate:a", 1.0, 0.4)
intro.chain().tween_callback(func(): print("Intro finished"))

# A Tween may be created before the manager or anywhere else in your code.
var external := create_tween()
external.tween_property($Panel, "scale", Vector2.ONE * 1.1, 0.2)
animate.store(&"hover", external)

# Release the handle to outside code without killing or resetting it.
var handed_back := animate.release(&"hover")
handed_back.tween_interval(0.1)
```

`store()` does not recreate operations, change easing, or rebind an existing Tween. Anything a valid Godot Tween can do remains available through the returned object. You can append properties, methods, callbacks and intervals yourself. It does not reconstruct arbitrary Tween scripts as editor tracks.

| Operation | Behavior |
| --- | --- |
| `create(name, owner = null)` | Create and store a configured Tween. Uses the supplied owner or the manager's default owner. Append operations before the next process frame. |
| `store(name, tween, replace = true)` | Register any valid Tween. Reusing a name kills its previous Tween; pass false to reject a duplicate without killing either. |
| `tweens[&"name"]` | Direct access to the actual Tween. Only index a name you know exists. |
| `get_tween(name)` / `has_tween(name)` | Safe lookup, including cleanup of a killed/invalid entry. |
| `list_tweens()` | List valid stored names and prune invalid entries. |
| `pause(name)` / `resume(name)` | Control one named Tween. |
| `stop_named(name)` | Kill the named Tween and remove its tracking. |
| `release(name)` | Remove its name and helper replacement tracking while allowing it to continue. |
| `clear(false)` | Release all named entries without killing them. |
| `clear()` | Kill and remove all named entries. |
| `stop(target, property)` | Cancel helper effects on a target/property; omit property to stop all helper effects for that target. |
| `stop_all()` | Kill named entries and other effects created by this instance. |

Finished names are removed automatically, so the dictionary is a live registry rather than an animation archive. A completed Tween must be recreated to play again. External `kill()` calls are cleaned up lazily by `get_tween()` or `list_tweens()`. Direct dictionary writes are possible, but bypass `store()` validation, name replacement and automatic finished cleanup. Register through `store()` and read through the dictionary or safe lookup methods.

Multiple names can refer to the same Tween. Killing it affects every handle to that object. To completely hand it back, release all its names. Clearing the registry is separate from freeing an owner: Node-bound Tweens follow Godot's lifetime rules.

## Effects that create their own Tweens

```gdscript
var animate := Tweenimator.new()

func feedback() -> void:
    animate.move_left($MeshInstance3D, 2.0, 0.3)
    animate.press($Button)
    animate.store(&"fade", animate.fade_out($Panel))
```

No external Tween is required. Node-target effects infer their owner from the target when no default owner is supplied. `Tweenimator.new(self)` chooses a shared controller owner instead. The selected owner must be inside the scene tree when an effect starts. Resource-only effects (`shader_transition`) and callback-only effects (`method`) need a default owner because there is no Node target to infer. `create(name, owner)` can choose a different owner for a particular animation.

| Effects | Targets and values |
| --- | --- |
| `move_left/right/up/down(target, distance, duration)` | Node2D, Node3D and Control; calculates the relative destination. |
| `move_forward/back(target, distance, duration)` | Node3D; forward is -Z, back is +Z. |
| `move_to(target, value, duration)` / `move_by(target, offset, duration)` | Vector2 for 2D/UI, Vector3 for 3D. |
| `scale_to(target, value, duration)` | A uniform number, Vector2 or Vector3. |
| `scale_up/down(target, amount, duration)` | Multiply the current scale by 1 +/- amount. |
| `rotate_to(target, radians, duration)` / `rotate_degrees(target, degrees, duration)` | Absolute angle: number for 2D/UI, Vector3 for 3D. |
| `press(target)` | Shrink and return to the captured rest scale; repeated presses preserve it. |
| `wiggle(target, strength, duration, loops)` | Oscillate and restore the original rotation; Y axis in 3D. |
| `fade_to/in/out` | CanvasItem (2D and UI), alpha clamped to 0-1. |
| `resize_to(target, size, duration)` | Control. Container/minimum-size rules still apply. |
| `set_volume(target, decibels, duration)` | AudioStreamPlayer, AudioStreamPlayer2D or AudioStreamPlayer3D. |
| `shader_transition(material, parameter, value, duration)` | ShaderMaterial uniform. |
| `method(callable, from, to, duration)` | Callback-driven values. |
| `custom(target, property, value, duration, transition)` | Any writable Tween-compatible property. Creates its own Tween. |

Direction helpers use the parent's coordinate axes, not the camera or the target's rotated axes. Up/down use -/+Y in 2D/UI and +/-Y in 3D. Relative destinations are sampled when called. Containers can override UI position/size.

Reuse the helper so a new effect replaces its active effect on the same target/property. Other properties can continue together, such as movement and fading. An adopted external Tween has no inferred property channel; its name is what manages it. Replacing an effect cancels its entire returned Tween, including any appended steps. A canceled Tween does not emit finished.

UI scale/rotation effects center `pivot_offset` automatically; set `auto_center_pivot = false` to preserve your pivot. Changing a pivot may shift an already transformed Control. Set `transition_type` and `ease_type` once to share easing; Sine / In-Out is the default. Stop operations leave properties at the current sampled value.

## Native API and helper API

Godot's Tween API is sufficient on its own. Tweenimator adds names, lookup, cleanup, directional calculations, effect sequences, pivot setup and replacement bookkeeping. Returned and stored values are regular Godot Tweens and work inside or outside the class. `custom()` is a property entry point, not a replacement for every Tween operation; use the returned Tween for advanced operations.

The Setup tutorials pair both implementations on every step, explain owner choice and default easing, and include embedded copy icons. The visual, native-code and helper-code paths all cover the named registry.

## Timeline resources

The editor creates standard Godot Animation resources, independently of the runtime registry. Select a scene node, add a property track, and capture keys at different times. Save as `.tres`; play it through an AnimationLibrary on AnimationPlayer with paths rooted at the same scene root.

The timeline previews value tracks for Node2D, Node3D and Control. It writes properties into the open scene; switch to the 2D/3D editor to observe playback. There is no embedded scene viewport, and preview leaves the last sampled values on the nodes. Existing Animation resources can be opened as `.tres`; non-value tracks are not edited or previewed by the value-track controls.

The timeline does not yet provide key dragging, multi-track selection, undo integration, or an easing-curve editor. It does not import running Tweens or automatically reproduce procedural chains/easing. Runtime named Tween storage and Animation resources serve different workflows.

## Compatibility

`TweenAnimation` remains as a compatibility subclass of `Tweenimator`. Existing `TweenAnimation.new(self, transition)` calls continue to work. New code should use `Tweenimator`. Runtime source: `src/tweenimator.gd`; editor setup and timeline: `editor/`.

## Start here

The default Setup guide is a seven-step quick start: create the manager; run an effect without supplying a Tween; keep its returned handle; build a named animation function; register an external Tween; look up/control names; and release a handle back to outside code. Each step has a large action headline, a small diagram, and runnable native/helper examples. Additional timeline and effects paths build on that same setup flow. Next/Back navigate the guide rather than modifying your scene.

## In-editor documentation

Open Tweenimation > Documentation for a searchable, category-filtered reference to all 36 public runtime functions. Each function has its current signature and defaults, parameter explanations, return values, behavior notes and a copyable example. Signatures are read from the runtime source. Start-here pages cover owner choices, named storage, existing external Tweens, chains/parallel groups, completion, playback/replay and public configuration fields.

Tutorial examples appear helper-first, followed by regular Godot Tweens. Setup is shown once; subsequent GDScript snippets use the target/tweenimator variables established there. C# examples use a complete TweenExample.cs setup and subsequent methods inside that class. The language picker requires no .NET runtime to view examples, but executing C# requires Godot .NET and an SDK. C# helper examples use GodotObject.Call() to access the existing GDScript Tweenimator, rather than a separate C# implementation. The examples follow Godot's cross-language API; C# compilation was not validated in the current standard-engine environment.
