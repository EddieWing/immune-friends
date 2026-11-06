extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const View=preload("res://scripts/microscope_effects.gd")
var errors=0
func check(ok,label):
 print(("PASS: " if ok else "FAIL: ")+label)
 if not ok: errors+=1
func _initialize():
 var s=Sim.new()
 s.reset(42,12);s.phase="battle"
 var cell=s.make_cell("wall",Vector2(80,0))
 s.cells=[cell]
 s.spawn_virus({"type":"basic","lane":0,"p":Vector2(300,0)})
 var virus=s.viruses[0]
 virus.emerging=false
 var view=View.new()
 view.update(s,0)
 var start=cell.p
 cell.p+=Vector2(7,3);virus.p+=Vector2(-7,3)
 s.blood[0].p+=Vector2(0,7)
 s.elapsed+=1.0/60
 view.update(s,0)
 check(view.trails.size()==3,"Core immune and virus movement leave separate water traces")
 check(view.trails.any(func(t):return t.a==start and t.b==cell.p and not t.virus),"Trace endpoints remain in world coordinates")
 var saved=var_to_bytes(view.trails)
 view.update(s,1)
 check(var_to_bytes(view.trails)==saved,"Pause adds no segments and freezes decay")
 cell.p+=Vector2(500,0)
 view.update(s,0)
 check(view.trails.size()==3,"Teleport does not draw a long streak")
 virus.emerging=true;virus.p+=Vector2(10,0)
 view.update(s,0)
 check(view.trails.size()==3,"Hidden emerging virus leaves no premature trace")
 virus.emerging=false
 for i in range(500):
  cell.p+=Vector2(6,0)
  view.update(s,0)
 check(view.trails.size()<=420,"Heavy battle trail geometry is bounded")
 s.elapsed+=2
 view.update(s,0)
 check(view.trails.is_empty(),"Water clears on simulation clock")
 s.reset(43,12);view.update(s,0)
 check(view.previous.is_empty() and view.trails.is_empty(),"Restart cannot retain old water tracks")
 quit(errors)
