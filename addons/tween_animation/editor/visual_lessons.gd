@tool
extends RefCounted

static func lessons(mode: int) -> Array[Dictionary]:
	var target: String = ["Node2D", "Node3D", "Control"][mode]
	var property := "modulate:a" if mode == 2 else "position"
	var change := "set modulate → alpha to a different value" if mode == 2 else "move the selected node to a new position"
	var steps: Array[Dictionary] = [
		{"title": "Pick your scene actor", "action": "Select a " + target + " in the Scene tree.", "body": "Open the scene you want to animate. Then use Open timeline above to work in the built-in editor. No Tweenimator object or script is required.", "visual": "SCENE  →  SELECT NODE"},
		{"title": "Give it a timeline lane", "action": "Add a track for " + property + ".", "body": "In Timeline, keep your scene node selected. Enter [b]" + property + "[/b] in Node property and choose [b]Add track[/b]. The active-track selector now names the property you are editing.", "visual": "SELECT NODE  →  ADD TRACK"},
		{"title": "Save the opening pose", "action": "At 0 seconds, choose Capture key.", "body": "Set the node's starting value in the Inspector. Leave the timeline's Value field empty so [b]Capture key[/b] records that value. A marker appears on the track.", "visual": "0 s  →  FIRST KEY"},
		{"title": "Choose where it ends", "action": "Scrub to 1 second, " + change + ", then Capture key.", "body": "Move the playhead first. Change the property in the Inspector or scene view, then return to Timeline and capture it. Now two keys describe a change over time. Scrubbing between them samples the animation.", "visual": "FIRST POSE  →  SECOND POSE"},
		{"title": "Watch it move", "action": "Play preview, then view the scene in Godot's " + ("3D" if mode == 1 else "2D") + " editor.", "body": "Playback continues while you look at the scene. Return to Tweenimation to pause, or use Rewind to sample its beginning. Preview leaves sampled values on the open scene's nodes. UI Containers may override position/size; fading avoids that layout conflict.", "visual": "KEYS  →  PLAYBACK"},
		{"title": "Keep your clip", "action": "Save the Animation as a .tres resource.", "body": "Use Save or Save As. To play without code, add an AnimationPlayer under the authored scene root, load this Animation into its library, and enable Autoplay on Load when appropriate. Documentation in Visual Timeline mode explains that workflow and opening existing clips.", "visual": "SAVE  →  REUSE"}
	]
	return steps
