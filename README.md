# Tweenimation

A Godot add-on for authoring property animations in a dedicated **Tweenimation** timeline tab.

## Install

Copy `addons/tween_animation` into your project's `addons/` folder. Enable **Tweenimation** in **Project > Project Settings > Plugins**.

## Quick start

Create a helper for a node that owns the animation, then call an effect with the target node:

```gdscript
var animate := TweenAnimation.new(self)

func _ready() -> void:
	animate.fade_in($Sprite2D)
	animate.scale_to($Button, Vector2.ONE * 1.1, 0.2)
```

The editor tab creates standard Godot `Animation` resources. Select a node in the edited scene, enter a property such as `position` or `modulate:a`, and add a track. Scrub the timeline, then capture property values at different times as keyframes. You can also type numeric, `Vector2(...)`, or `Vector3(...)` key values. Play previews the animation on the edited scene; Save writes a reusable `.tres` resource.

To use a saved animation in a game, add it to an `AnimationLibrary` on an `AnimationPlayer` and play its animation name. The scene root must stay open while previewing because tracks use paths relative to that root.

## Included effects

- `custom(target, property, value, duration)`
- `fade_to`, `fade_in`, and `fade_out` for `CanvasItem`
- `scale_to`, `move_to`, `move_by`, and `rotate_to` for `Node2D`
- `wiggle` for `Node2D`

The timeline currently authors value tracks. It does not yet include drag-to-move keyframes, multiple selected tracks, undo integration, or a dedicated easing-curve editor.

The runtime convenience helper is available from `src/tween_animation.gd` for small one-off effects.

## Development

The add-on source is in `addons/tween_animation`. The editor tab lives in `editor/plugin.gd`; runtime helpers are in `src/tween_animation.gd`.

## Preview support

The timeline toolbar groups track selection, property entry and key capture beside the timeline. It wraps onto another line in narrow editor panels.

Value tracks preview properties on Node2D, Node3D and Control nodes. Examples include position and scale (Vector2 for 2D/UI, Vector3 for 3D), rotation, and CanvasItem modulate:a. Leave the value field blank to capture the current property value. The preview applies to the open scene; the Tweenimation tab does not contain an embedded 2D or 3D viewport. Changes can be inspected in the scene editor. Saved resources are standard Animation resources, not recordings of arbitrary running Tween scripts.

The runtime helper's move/scale/rotate/wiggle shortcuts currently accept Node2D. Its custom() method can tween properties on other objects, including Node3D and Control; fade helpers accept CanvasItem (2D and UI).
