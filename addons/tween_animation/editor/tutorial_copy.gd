@tool
extends RefCounted

const CSHARP := {
	"Your animation toolbox": [
		"Add these fields to your existing Godot C# Node class.",
		"Use [b]using Godot;[/b]. The _target property resolves the sample child, and _tweenimator loads the add-on runtime once. No Tween runs just from creating the manager.\n\nThe helper is written in GDScript, so C# reaches it through [b]GodotObject.Call()[/b]. Use Godot .NET to run these examples."
	],
	"Make your first move": [
		"Call PlayExample() from _Ready() or a button handler.",
		"The C# helper example calls [b]move_left[/b] through _tweenimator.Call(). It creates its own Tween and uses the target Node as owner.\n\nTry changing the method string to move_right. Distance is in scene units for 3D and normally pixels for 2D/UI."
	],
	"Keep the Tween you just made": [
		"Call the async PlaySlide() method.",
		"Keep the returned [b]Tween[/b] in slide, register it with Call(\"store\", ...), then append an interval. Both variables refer to the same object.\n\nC# waits for completion with [b]await ToSignal(slide, Tween.SignalName.Finished)[/b]. Do not use GDScript signal-await syntax here."
	],
	"Build a named animation": [
		"Connect a button or input action to PlayIntro().",
		"Call(\"create\", name, this) creates and names the Tween; this supplies the owner Node. Add ordinary C# TweenProperty() operations to the returned object.\n\nCall PlayIntro() again to create a new run. A completed Tween cannot be restarted; replacing the name cancels any previous live run."
	],
	"Bring a Tween from anywhere": [
		"Pass an existing Tween to RegisterExternal(external).",
		"The Tween can come from CreateTween() in any other C# script. Call(\"store\", ...) registers the existing object without changing its owner, easing or animation steps.\n\nThe native version keeps a field directly. The helper version can address it later by its StringName."
	],
	"Find it by name": [
		"Run PlayExample() to compare direct and safe lookup.",
		"Get(\"tweens\").AsGodotDictionary() exposes the named registry from C#. Use the StringName key only when the entry is known to exist.\n\nCall(\"get_tween\", ...) is the safe option; convert its result to a Tween and test for null before using it. Pause()/Play() operate on the returned handle, while the helper can control the same object by name."
	],
	"Hand it back to your own code": [
		"Run PlayExample() and append another step to the returned handle.",
		"Call(\"release\", ...) removes registry/replacement tracking without killing the Tween. Convert the result back to Tween and use TweenInterval(), TweenCallback(), or other normal C# APIs.\n\nUse Call(\"stop_named\", name) when you mean to cancel instead."
	],
	"Give it a property to play with": [
		"Call PlayPropertyTour() from your existing class.",
		"The examples use C# Vector2/Vector3 values and the target selected in setup. The native path adds TweenProperty() operations. The helper calls named methods through Call().\n\nThese runtime examples animate properties directly; they do not add editor timeline tracks."
	],
	"See what each property does": [
		"Call PlayPropertyTour() to move, resize/scale and rotate the target.",
		"Use [b]new Vector2(...)[/b] for 2D/UI and [b]new Vector3(...)[/b] for 3D. C# uses Mathf.Pi for radians and numeric degrees for rotate_degrees.\n\nThe helper tour awaits each returned Tween with ToSignal(). UI Containers may override position or size."
	],
	"Plant the first key": [
		"Run PlayExample() to set a start value and animate to the end.",
		"The C# method sets the target Position or Modulate first, then creates the animation. Use new Vector2/new Vector3 and the C# property names shown.\n\nFor an actual editor keyframe, select Visual Timeline in the top bar. This code example demonstrates the equivalent runtime change."
	],
	"Choose the destination": [
		"Change the destination value in PlayExample(), then run it again.",
		"The native C# path passes the destination to TweenProperty(). The helper uses Call(\"custom\", ...) with a NodePath and matching destination type.\n\nPosition uses Vector2 in 2D/UI and Vector3 in 3D; UI alpha is a float from 0 to 1."
	],
	"Bring it to life": [
		"Call PlaySavedClip() after saving a timeline clip.",
		"Replace the .tres path and add an AnimationPlayer child. The C# method loads an Animation into an AnimationLibrary and calls Play().\n\nFor editor-only preview and key capture, switch the top selector to Visual Timeline."
	],
	"Let your game press Play": [
		"Call PlaySavedClip() from _Ready() or an input event.",
		"Load the saved Animation resource, add it to an AnimationLibrary, then play its library/name key. Keep the player root pointed at the authored scene root.\n\nThis is the same AnimationPlayer API for either workflow; the runtime helper is not required to play a saved .tres clip."
	],
	"Bring your existing work along": [
		"Use PlaySavedClip() for a saved Animation resource.",
		"An existing AnimationPlayer clip can be saved as .tres and loaded from C#. A procedural Tween stays a Tween: register it through Call(\"store\", name, tween) when you want named management.\n\nProcedural Tween scripts are not imported into timeline tracks automatically."
	],
	"A press that returns to its starting size": [
		"Call PlayExample() from a button press or other event.",
		"The native C# example captures Scale and builds two TweenProperty() stages. The helper calls press through Call() to do that work.\n\nFor Control targets, the helper centers PivotOffset by default. Use _tweenimator.Set(\"auto_center_pivot\", false) if you already set a custom pivot."
	],
	"Give the movement a feel": [
		"Change the C# easing settings, then call PlayExample().",
		"Native C# uses SetTrans(Tween.TransitionType.Back) and SetEase(Tween.EaseType.Out) before adding a property. The helper sets transition_type/ease_type through Set() using the enum integers.\n\nSettings affect newly created helper Tweens; storing an external Tween does not change its easing."
	],
	"Make one thing follow another": [
		"Call PlayExample() and watch the callback run after the motion.",
		"Tween operations run sequentially by default. TweenInterval() adds a delay, and TweenCallback(Callable.From(...)) runs the final action.\n\nThe helper returns a normal Godot Tween, so these C# operations work on either implementation."
	]
}

static func for_csharp(title: String) -> Dictionary:
	var values: Array = CSHARP.get(title, ["Use the C# method shown below.", "Add the method inside your existing Godot Node class and call it from _Ready() or an input handler."])
	return {"action": values[0], "body": values[1]}
