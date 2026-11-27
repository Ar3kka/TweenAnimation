# Tweenimation

A Godot add-on for keeping track of individual Tweens, creating intent-first effects, and authoring property animations in a visual timeline. Built on the original Tween Animator implementation.

## Install

Copy `addons/tween_animation` into your project's `addons/` folder. Enable **Tweenimation** in **Project > Project Settings > Plugins**. The Setup tab offers centered 2D, 3D and UI entry points, visual walkthroughs, and paired helper/native code snippets.

## Name your Tweens

`Tweenimator` is the runtime class. Its public `tweens` dictionary stores ordinary Godot Tween objects by StringName. You can construct it before your scene is ready, with no owner or existing Tween.

```gdscript
extends Node

var animate := Tweenimator.new()

func _ready() -> void:
    # This effect creates its own Tween, bound to the target Node.
    animate.store(&"slide", animate.move_left($Sprite2D, 100, 0.3, 0.2))
    # The dictionary and the local handle refer to the exact same Tween.
    var slide: Tween = animate.tweens[&"slide"]
    # The effect already includes its optional 0.2-second trailing interval.
    animate.pause(&"slide")
    animate.resume(&"slide")
```

Names belong to a particular Tweenimator instance. Share that instance with the scripts that should access its animations; separate instances have separate registries.

## Optional wait after an effect

All 23 animation helpers accept an optional final `interval: float = 0.0`, in seconds. It appends a wait after the **entire effect** on the same returned Tween. Existing calls keep their argument order and behavior; zero adds no extra step.

```gdscript
# target, distance, movement duration, trailing interval
var slide := animate.move_left($Sprite2D, 100, 0.4, 0.2)
slide.tween_callback(func(): print("Movement and wait complete"))
# await slide.finished also waits for both the 0.4s movement and 0.2s interval.

# Equivalent native Godot sequence:
var native := create_tween()
native.tween_property($Sprite2D, "position", $Sprite2D.position + Vector2.LEFT * 100, 0.4)
native.tween_interval(0.2)
# Use one implementation at a time on a given property.
```

`interval` must be finite and non-negative. It is not a start delay and does not stop the game. Named entries and replacement channels remain active during the wait; pause/resume affect it, and killing/replacing the Tween cancels it. For `press()` and `wiggle()`, the interval runs once after all animation stages/loops. Factory and registry methods (`create`, `store`, etc.) do not take an interval; native `tween_interval()` remains available for external Tweens and custom sequences.

Optional arguments retain their positions: `press(target, amount, duration_down, duration_up, interval)`, `wiggle(target, strength, duration, loops, interval)`, and `custom(target, property, value, duration, transition, interval)`. Pass `-1` for custom's transition to inherit the manager's curve while specifying its interval.

C# reaches the same parameter through the bridge, for example `_tweenimator.Call("move_left", target, 100.0f, 0.4, 0.2)`. Visual action templates represent the interval with an extra final hold key and extended animation length. The visual preview tutorial has an After-effect interval control to demonstrate it.

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

Tutorial examples appear helper-first, followed by regular Godot Tweens. Setup starts with only useful variables/fields; no empty ready function is required. Subsequent snippets reuse the setup variables and run inside your existing methods; function definitions belong at script/class scope. C# examples use fields inside an existing Godot Node class (with using Godot;) and GodotObject.Call() to access the same GDScript runtime. Viewing C# samples does not need a .NET engine; executing them needs Godot .NET and an SDK. C# compilation was not validated in the current standard-engine environment.

Documentation includes applicability badges and combinable target filters for 2D, 3D, UI, audio, shader resources and callbacks. Registry operations are target-independent and marked Any Tween. Main tabs are centered with icons and short labels. Reference examples use focused actions and event handlers rather than repeated whole scripts; their context is stated beside the snippet.


## Shared content view

A pinned top-right GDScript / C# / Visual Timeline selector controls both Tutorials and Documentation. It remains above scrolling content and across the three add-on tabs. Code views show the corresponding examples; C# accesses the same GDScript runtime through GodotObject.Call() and requires Godot .NET to execute. C# examples are reference content, not a separately compiled C# port.

Visual Timeline mode contains no code panels. It offers six-step 2D/3D/UI editor tutorials and visual documentation for property tracks, key capture, preview/rewind, saving/opening clips, and playing saved resources through AnimationPlayer without scripts. Its documentation filters show visual guides and timeline controls rather than pretending runtime helper functions are timeline features. Switching views does not translate or modify your project's scripts.

The page tabs and content selector share one pinned navigation bar. The content selector is a contiguous three-segment toggle with a solid accent selected state, high-contrast text and keyboard focus outline. Page selection stays synchronized with tutorial actions that open the Timeline.

C# tutorial actions and explanations use C# method names, ownership, signals and bridge calls alongside their snippets. Code panels fit their content, so short examples stay compact and longer examples expand within the scrolling page.

Visual tutorials and reference pages include interactive practice previews made from the same property, capture, scrub and key-list controls as the real Timeline. Highlighted controls identify each step; a sample Scene tree and Inspector let you practice capturing two poses and previewing the result with a sprite, projected cube or fading panel. Practice uses a private Animation and never changes your scene or saves project files. Use the Timeline page to author and save your real animation.

The Timeline tracks the selected scene node and offers a searchable Properties browser, including exported script properties, vector/color components and properties on attached resources. Manual property-path entry remains available. Action templates offer compatible movement, transform, press/wiggle, fade, resize and audio effects. Choose their destination/distance and duration to generate editable keys beginning at the playhead. Templates use linear value-track interpolation; they do not bake runtime Tween easing or change Control pivots. Registry, callback and resource-only helper operations remain runtime APIs rather than node action templates.

Visual lessons reveal only the controls needed for the current exercise. A visible outline moves from the time slider to the sample Inspector and then Capture key. Next/Back load prepared lesson states; they do not gate navigation on practice completion. The code tutorial selector is labelled Tutorial path. Documentation target badges and filters pair 2D, 3D and UI labels with Godot's node icons.

The shared key-value panel shows the active track's live property value, its accepted type and component meanings, Inspector range/enum hints when available, and clickable example literals. Blank Override captures the current value; a typed override is validated against the property's type. Use current clears the override. A separate readout shows the saved key at the exact playhead time, so a scene edit is distinguishable from recorded animation data. The real Timeline and tutorial use the same input parser and panel; vectors, colors, numbers, booleans and quoted text are supported alongside other displayed value types.
