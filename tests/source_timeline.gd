extends SceneTree
const MODEL = preload("res://addons/tween_animation/editor/tween_source.gd")
const WRITER = preload("res://addons/tween_animation/editor/tween_source_writer.gd")
var failures := 0
func check(value: bool, message: String) -> void:
 if not value:
  failures += 1
  push_error(message)
func _initialize() -> void:
 _run.call_deferred()
func _run() -> void:
 await process_frame
 var owner := Node2D.new()
 root.add_child(owner)
 var sprite := Sprite2D.new()
 sprite.name = "Actor"
 owner.add_child(sprite)
 var source := """extends Node2D
@onready var actor = $Actor
func animate(distance: float = 100.0) -> void:
 var tween := create_tween()
 tween.tween_property(actor, "position", actor.position + Vector2(distance, 0), 0.5)
 tween.parallel().tween_property(actor, "rotation", 1.0, 0.3)
 tween.chain().tween_interval(0.2)
 tween.tween_property(actor, "position:x", 0.0, 0.4)
func helper() -> void:
 var animator := Tweenimator.new(self)
 var slide := animator.move_left($Actor, 100.0, 0.4)
 await slide.finished
 animator.fade_out($Actor, 0.2)
func dynamic(seconds: float) -> void:
 var tween := create_tween()
 tween.tween_property($Actor, "position", Vector2.ZERO, seconds)
 tween.tween_property($Actor, "rotation", 0.0, 0.3)
"""
 var doc := MODEL.analyze(source, "res://actor.gd", owner, sprite)
 print("METHODS ", doc.methods.size(), " OPS ", doc.operations.size())
 for op in doc.operations:
  print(op.method.name, " ",op.api," ",op.start," ",op.duration," ",op.target_expression," ",op.relevant)
 check(doc.methods.size() == 3, "Methods indexed")
 check(doc.operations.size() == 8, "All native/helper operations discovered")
 check(doc.operations[0].relevant, "Alias resolves selected node")
 check(doc.operations[0].start == 0.0, "First operation starts at zero")
 check(doc.operations[1].start == 0.0, "Parallel shares prior step")
 check(is_equal_approx(doc.operations[2].start, 0.5), "Chain waits for longest parallel step")
 check(is_equal_approx(doc.operations[3].start, 0.7), "Interval shifts next operation")
 check(doc.operations[4].verified, "Helper receiver validated")
 check(is_equal_approx(doc.operations[5].start, 0.4), "Awaited helper advances method clock")
 check(doc.operations[6].duration == null and doc.operations[7].start == null, "Computed duration stays unknown")
 var edit := WRITER.patch_arguments(source, doc.operations[0], {"duration": "0.8"})
 check(edit.ok and "actor.position + Vector2(distance, 0), 0.8" in edit.source, "Only selected argument patched")
 check(WRITER.validate(edit.source,"gd").ok, "Patched source compiles")
 var relative := {"mode":"relative", "value":Vector2(-40,0)}
 var duration := {"mode":"constant", "value":0.3}
 var interval := {"mode":"constant", "value":0.1}
 var insert := WRITER.insert_property(source, doc.methods[0], {"kind":"end"}, sprite, "position", relative, duration, interval)
 check(insert.ok and "get_indexed" in insert.source, "Relative visual insertion preserves runtime values")
 check(WRITER.validate(insert.source,"gd").ok, "Inserted source compiles")
 for kind in ["start", "before", "after"]:
  var anchor := {"kind":kind, "start":doc.methods[0].statements[1].start}
  var placed := WRITER.insert_property(source, doc.methods[0], anchor, sprite,"position",relative,duration,interval,"own")
  check(placed.ok and WRITER.validate(placed.source,"gd").ok,"Placement compiles: " + kind)
 var bound := WRITER.binding({"mode":"relative", "value":Vector2(4,0), "property":"scale"},owner,sprite,"position",doc.methods[0],"gd")
 check('get_indexed(^"position")' in bound.text,"Relative binding uses the animated property, not an unrelated picker value")
 var parameters := WRITER.binding({"mode":"parameter","name":"distance","value":0.0},owner,sprite,"position",doc.methods[0],"gd")
 check(parameters.ok and parameters.text=="distance","Method parameter binding")
 var moved := WRITER.move_statement(source,doc.operations[3],doc.methods[0],{"kind":"before","start":doc.operations[1].statement.start})
 check(moved.ok and WRITER.validate(moved.source,"gd").ok,"Existing statement reposition compiles")
 var bad_move := WRITER.move_statement(source,doc.operations[0],doc.methods[0],{"kind":"start"})
 check(not bad_move.ok,"Use cannot move before its Tween declaration")
 var branch := source + "\nfunc branch() -> void:\n if visible:\n  create_tween().tween_property($Actor, \"rotation\", 0.5, 0.2)\n"
 var branch_doc := MODEL.analyze(branch,"res://actor.gd",owner,sprite)
 check(branch_doc.operations[-1].conditional and branch_doc.operations[-1].start==null,"Branch timing labelled runtime")
 var registered := "extends Node2D\nvar animator := Tweenimator.new()\nfunc motion() -> void:\n var named := animator.create(&\"intro\", self)\n named.tween_property($Actor, \"rotation\", 1.0, 0.2)\n var existing := animator.get_tween(&\"intro\")\n existing.tween_interval(0.3)\n"
 var registry_doc := MODEL.analyze(registered,"res://actor.gd",owner,sprite)
 check(registry_doc.operations[0].verified and registry_doc.operations[0].start==0.0,"Manager-created native Tween recognized")
 check(registry_doc.operations[1].verified and registry_doc.operations[1].start==null,"Registry lookup timing remains runtime")
 var spoof := MODEL.analyze("extends Node2D\nfunc unrelated():\n var something = Object.new()\n something.tween_property($Actor, \"rotation\", 1.0, 0.2)\n", "res://spoof.gd", owner,sprite)
 check(not spoof.operations[0].verified,"Unknown receiver cannot be visually rewritten")
 var stale := WRITER.patch_arguments(source + "#changed", doc.operations[0], {"duration":"1.0"})
 check(not stale.ok,"Stale source rejected")
 var helper_edit := WRITER.patch_arguments(source,doc.operations[4],{"interval":"0.5"})
 check(helper_edit.ok and WRITER.validate(helper_edit.source,"gd").ok,"Optional helper args filled correctly")
 var csharp := """using Godot;
public partial class Actor : Node2D {
 private Sprite2D actor => GetNode<Sprite2D>("Actor");
 public void Animate(float seconds) {
  var tween = CreateTween();
  tween.TweenProperty(actor, "position", new Vector2(40, 0), 0.5f);
  tween.TweenInterval(0.2f);
  tween.TweenProperty(actor, "rotation", 1.0f, seconds);
 }
}
"""
 var cs := MODEL.analyze(csharp,"res://Actor.cs",owner,sprite)
 check(cs.methods.size()==1 and cs.operations.size()==3,"C# methods/calls indexed")
 check(cs.operations[0].relevant and is_equal_approx(cs.operations[1].start,0.5),"C# aliases and schedule resolved")
 var cs_insert := WRITER.insert_property(csharp,cs.methods[0],{"kind":"end"},sprite,"position",relative,duration,interval)
 check(cs_insert.ok and ".AsVector2() + new Godot.Vector2" in cs_insert.source,"C# typed dynamic position generated")
 for probe in [Node2D.new(), Node3D.new(), Control.new()]:
  root.add_child(probe)
  var base: String = "extends " + probe.get_class() + "\nfunc animate() -> void:\n pass\n"
  var probe_doc := MODEL.analyze(base,"res://probe.gd",probe,probe)
  var offset: Variant = Vector3(1,0,0) if probe is Node3D else Vector2(40,0)
  var generated := WRITER.insert_property(base,probe_doc.methods[0],{"kind":"end"},probe,"position",{"mode":"relative","value":offset},duration,{"mode":"constant","value":0.0})
  var script := GDScript.new()
  script.source_code = generated.source
  check(script.reload()==OK,"Generated " + probe.get_class() + " source compiles")
  probe.set_script(script)
  var zero: Variant = Vector3.ZERO if probe is Node3D else Vector2.ZERO
  probe.set("position",zero)
  probe.call("animate")
  get_processed_tweens()[-1].custom_step(1.0)
  check(probe.get("position")==offset,"Relative " + probe.get_class() + " offset executes")
  probe.call("animate")
  get_processed_tweens()[-1].custom_step(1.0)
  check(probe.get("position")==offset*2,"Relative " + probe.get_class() + " offset reevaluates current position")
  probe.free()
 var file := FileAccess.open("res://write_test.gd",FileAccess.WRITE)
 file.store_string(source)
 file.close()
 var saved := WRITER.write("res://write_test.gd",source.sha256_text(),edit.source)
 check(saved.ok and FileAccess.get_file_as_string("res://write_test.gd")==edit.source,"Validated atomic write")
 var conflict := WRITER.write("res://write_test.gd",source.sha256_text(),source)
 check(not conflict.ok,"Concurrent write rejected")
 DirAccess.remove_absolute("res://write_test.gd")
 owner.free()
 print("SOURCE_CHECK_FAILURES=",failures)
 quit(failures)
