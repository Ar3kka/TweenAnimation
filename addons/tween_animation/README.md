# Tweenimation

Tweenimation is a Godot editor add-on for creating reusable property animations with a timeline.

Enable it in **Project > Project Settings > Plugins**, open the **Tweenimation** tab, and create an animation. Select a node in the edited scene, enter a property name such as `position` or `modulate:a`, and add a track. Scrub the timeline and capture values as keyframes, then save the result as a Godot `.tres` `Animation` resource.

The saved resource uses standard Godot animation data and can be added to an `AnimationLibrary` on an `AnimationPlayer`. The edited scene must remain open while previewing because track paths are relative to its root.

The current editor supports numeric, `Vector2`, and `Vector3` values. It does not yet support moving keys by dragging, easing-curve editing, or undo history for timeline edits.

See the repository README for installation and development notes. See the repository `LICENSE` file for the license terms.

## Preview support

The timeline toolbar groups track selection, property entry and key capture beside the timeline. It wraps onto another line in narrow editor panels.

Value tracks preview properties on Node2D, Node3D and Control nodes. Examples include position and scale (Vector2 for 2D/UI, Vector3 for 3D), rotation, and CanvasItem modulate:a. Leave the value field blank to capture the current property value. The preview applies to the open scene; the Tweenimation tab does not contain an embedded 2D or 3D viewport. Changes can be inspected in the scene editor. Saved resources are standard Animation resources, not recordings of arbitrary running Tween scripts.

The runtime helper's move/scale/rotate/wiggle shortcuts currently accept Node2D. Its custom() method can tween properties on other objects, including Node3D and Control; fade helpers accept CanvasItem (2D and UI).

## Setup guides

Tweenimation opens on a Setup tab with 2D, 3D and UI guides. Each guide explains target nodes, property types, first keyframes, scene preview, AnimationPlayer integration, and copyable runtime Tween/helper examples. Set up chooses a target type and suggested property without clearing existing tracks. Use the Timeline tab to continue editing.

Existing Animation resources can be opened as .tres files. Existing procedural Tween code must be kept as code or recreated as property keys; running Tweens cannot be imported. Non-value tracks in imported resources are not previewed or edited by the property capture controls.

The Setup tutorial also offers two code-only learning paths: native Godot Tweens and the TweenAnimation helper. Each target type includes runnable script examples for basic motion, easing, sequencing, and interrupting repeated animations. Copy example copies the current script. Adjust child node paths before running it in your scene.

Every tutorial step shows both native Godot Tween code and optional Tweenimation helper code, with separate copy controls and a comparison of the convenience gained. Tweenimation wraps Godot Tweens; it is not required for procedural animation. The guides call out the different default easing and explain when both paths share the same Tween API.
