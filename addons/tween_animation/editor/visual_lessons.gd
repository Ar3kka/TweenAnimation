@tool
extends RefCounted

static func lessons(mode: int) -> Array[Dictionary]:
	var target: String = ["Node2D", "Node3D", "Control"][mode]
	var sample: String = ["Sprite2D", "MeshInstance3D", "Panel"][mode]
	var property := "modulate:a" if mode == 2 else "position"
	var change := "set modulate → alpha to a different value" if mode == 2 else "move the selected node to a new position"
	var steps: Array[Dictionary] = [
		{"title": "The selected node is your animation target", "action": "Select the tutorial's " + sample + " below to choose what to animate.", "body": "[b]Why select a node?[/b] When you press [b]Add track[/b], the timeline uses the currently selected node as that track's target. Selecting a " + target + " tells it whose position, scale or other property you want to animate.\n\n[b]In this tutorial:[/b] the tree below contains a sample " + sample + ". Select it to practice choosing an animation target. Selection has a real purpose in the workflow; it is not a requirement for unlocking the next lesson.\n\n[b]In your project:[/b] select your own node in [b]Godot's Scene tree[/b], then open Tweenimation's [b]Timeline[/b] and add a property track. Existing tracks keep their original targets when your selection changes.", "visual": "SELECTED NODE  →  NEW TRACK TARGET"},
		{"title": "Give it a timeline lane", "action": "Add a " + property + " track for the selected " + sample + ".", "body": "[b]Try here:[/b] the tutorial node is selected for this example. Enter [b]" + property + "[/b] in the Property field and choose [b]Add track[/b]. The new track names both the node and the property it will animate.\n\n[b]In your project:[/b] Add track uses the node selected in Godot's Scene tree. Each track stores that node's path, so you can add tracks for different nodes to the same animation.", "visual": "SELECT NODE  →  ADD TRACK"},
		{"title": "Save the opening pose", "action": "At 0 seconds, choose Capture key.", "body": "Set the node's starting value in the Inspector. Leave the timeline's Value field empty so [b]Capture key[/b] records that value. A marker appears on the track.", "visual": "0 s  →  FIRST KEY"},
		{"title": "Choose where it ends", "action": "Scrub to 1 second, " + change + ", then Capture key.", "body": "Move the playhead first. Change the property in the Inspector or scene view, then return to Timeline and capture it. Now two keys describe a change over time. Scrubbing between them samples the animation.", "visual": "FIRST POSE  →  SECOND POSE"},
		{"title": "Watch it move", "action": "Play preview, then view the scene in Godot's " + ("3D" if mode == 1 else "2D") + " editor.", "body": "Playback continues while you look at the scene. Return to Tweenimation to pause, or use Rewind to sample its beginning. Preview leaves sampled values on the open scene's nodes. UI Containers may override position/size; fading avoids that layout conflict.", "visual": "KEYS  →  PLAYBACK"},
		{"title": "Keep your clip", "action": "Save the Animation as a .tres resource.", "body": "Use Save or Save As. To play without code, add an AnimationPlayer under the authored scene root, load this Animation into its library, and enable Autoplay on Load when appropriate. Documentation in Visual Timeline mode explains that workflow and opening existing clips.", "visual": "SAVE  →  REUSE"}
	]
	return steps
