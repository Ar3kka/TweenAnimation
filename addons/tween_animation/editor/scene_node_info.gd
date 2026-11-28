@tool
extends RefCounted
## Human-readable paths stay inside the edited scene, never the editor tree.
static func path_in_scene(node: Node, scene_root: Node) -> String:
	if not is_instance_valid(node) or not is_instance_valid(scene_root):
		return ""
	if node == scene_root:
		return "Scene root"
	if not scene_root.is_ancestor_of(node):
		return ""
	return str(scene_root.get_path_to(node))
