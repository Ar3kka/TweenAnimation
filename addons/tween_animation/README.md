# Tween Animation

Tween Animation is a Godot editor add-on for creating reusable property animations with a timeline.

Enable it in **Project > Project Settings > Plugins**, open the **Tween Animation** tab, and create an animation. Select a node in the edited scene, enter a property name such as `position` or `modulate:a`, and add a track. Scrub the timeline and capture values as keyframes, then save the result as a Godot `.tres` `Animation` resource.

The saved resource uses standard Godot animation data and can be added to an `AnimationLibrary` on an `AnimationPlayer`. The edited scene must remain open while previewing because track paths are relative to its root.

The current editor supports numeric, `Vector2`, and `Vector3` values. It does not yet support moving keys by dragging, easing-curve editing, or undo history for timeline edits.

See the repository README for installation and development notes. See the repository `LICENSE` file for the license terms.
