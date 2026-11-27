# Tweenimation

Tweenimation is a Godot editor add-on for creating reusable property animations with a timeline.

Enable it in **Project > Project Settings > Plugins**, open the **Tweenimation** tab, and create an animation. Select a node in the edited scene, enter a property name such as `position` or `modulate:a`, and add a track. Scrub the timeline and capture values as keyframes, then save the result as a Godot `.tres` `Animation` resource.

The saved resource uses standard Godot animation data and can be added to an `AnimationLibrary` on an `AnimationPlayer`. The edited scene must remain open while previewing because track paths are relative to its root.

The current editor supports numeric, `Vector2`, and `Vector3` values. It does not yet support moving keys by dragging, easing-curve editing, or undo history for timeline edits.

See the repository README for installation and development notes. See the repository `LICENSE` file for the license terms.

## Preview support

The timeline toolbar groups track selection, property entry and key capture beside the timeline. It wraps onto another line in narrow editor panels.

Value tracks preview properties on Node2D, Node3D and Control nodes. Examples include position and scale (Vector2 for 2D/UI, Vector3 for 3D), rotation, and CanvasItem modulate:a. Leave the value field blank to capture the current property value. The preview applies to the open scene; the Tweenimation tab does not contain an embedded 2D or 3D viewport. Changes can be inspected in the scene editor. Saved resources are standard Animation resources, not recordings of arbitrary running Tween scripts.

Runtime movement, scaling, rotation, press and wiggle helpers support Node2D, Node3D and Control. Fade helpers accept CanvasItem (2D and UI); use custom() for properties with no named effect.

## Setup guides

Tweenimation opens on a Setup tab with 2D, 3D and UI guides. Each guide explains target nodes, property types, first keyframes, scene preview, AnimationPlayer integration, and copyable runtime Tween/helper examples. Set up chooses a target type and suggested property without clearing existing tracks. Use the Timeline tab to continue editing.

Existing Animation resources can be opened as .tres files. Existing procedural Tween code must be kept as code or recreated as property keys; running Tweens cannot be imported. Non-value tracks in imported resources are not previewed or edited by the property capture controls.

The Setup tutorial also offers two code-only learning paths: native Godot Tweens and the TweenAnimation helper. Each target type includes runnable script examples for basic motion, easing, sequencing, and interrupting repeated animations. Copy example copies the current script. Adjust child node paths before running it in your scene.

Every tutorial step shows both native Godot Tween code and optional Tweenimation helper code, with separate copy controls and a comparison of the convenience gained. Tweenimation wraps Godot Tweens; it is not required for procedural animation. The guides call out the different default easing and explain when both paths share the same Tween API.


## Intent-first runtime effects

The helper is based on the original Tween Animator implementation's named effects, shared easing, UI pivot handling, and replacement behavior.

```gdscript
@onready var animate := TweenAnimation.new(self)

func slide_left() -> void:
    animate.move_left($MeshInstance3D, 2.0, 0.3)

func button_feedback() -> void:
    animate.press($Button) # shrink and return to its starting scale

func stop_movement() -> void:
    animate.stop($MeshInstance3D, ^"position")
```

Reuse one helper per owner. A new effect cancels an active effect from that helper on the same target/property, so repeated movement calls do not compete. Different properties can animate together (for example position and opacity). The returned Tween supports ordinary Godot chaining and awaiting. Starting another effect cancels the previous Tween, including any steps appended to it. Canceled Tweens do not emit finished.

Direction helpers use position in the parent's coordinates. Left/right use X; up/down use -/+Y in 2D and UI, +/−Y in 3D. Forward/back use −/+Z in 3D. They do not follow camera orientation or the target's rotated axes. Relative moves sample the current position when called. Container layout may override a Control's position or size.

scale_to(target, 1.2) selects Vector2 or Vector3 automatically. scale_up/down multiply the current scale; press restores its captured rest scale, including when retriggered midway through a press. wiggle restores its original angle and uses the Y axis in 3D. UI scale/rotation effects center pivot_offset; set animate.auto_center_pivot = false to retain a custom pivot. Changing the pivot can shift an already transformed Control.

Set animate.transition_type and animate.ease_type once to share easing between calls. Sine / In-Out is the default. stop() and stop_all() leave properties at their current sampled values. stop_all() also cancels method() effects. custom() remains available for advanced properties; it is not needed for ordinary directional movement or named effects.

The editor still saves Animation resources independently of the runtime helper. Godot's Tween API remains available and sufficient on its own; the helper removes repeated coordinate calculations, effect sequences, pivot setup, easing configuration and replacement bookkeeping.
