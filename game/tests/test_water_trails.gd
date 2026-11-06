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
 var mechanical_state=var_to_bytes([s.cells,s.viruses,s.blood,s.events,s.rng.state])
 s.elapsed+=5
 view.update(s,0.7)
 check(view.trails.size()==1 and view.trails[0].virus,"Friendly imprint fades before viral path on render clock at x5")
 check(var_to_bytes([s.cells,s.viruses,s.blood,s.events,s.rng.state])==mechanical_state,"Water update does not change mechanics or RNG")
 check(is_equal_approx(view.trails[0].age,0.7),"Simulation acceleration does not multiply water decay")
 virus.alive=false
 s.elapsed+=1.0/60
 view.update(s,0.1)
 check(view.trails.size()==1 and not view.previous.has(s.physics.id_of(virus)),"Death removes imprint origin but preserves its path")
 s.phase="recap"
 view.update(s,12)
 check(view.trails.is_empty(),"Residual viral path eventually clears after battle")
 s.phase="battle"
 virus.alive=true
 virus.emerging=false
 for i in range(500):
  cell.p+=Vector2(6,0)
  view.update(s,0)
 check(view.trails.size()<=420,"Heavy battle trail geometry is bounded")
 s.elapsed+=20
 view.update(s,13)
 check(view.trails.is_empty(),"Bounded water history clears on its own render clock")
 s.reset(43,12);view.update(s,0)
 check(view.previous.is_empty() and view.trails.is_empty(),"Restart cannot retain old water tracks")
 s.rules.water_trails={"friendly_seconds":0.2,"virus_seconds":2.0}
 s.presentation_revision+=1
 view.update(s,0)
 check(view.friendly_trail_seconds==0.2 and view.virus_trail_seconds==2.0,"Configured profiles load on presentation reset")
 s.phase="battle";view.update(s,0)
 view.trails=[{"a":Vector2.ZERO,"b":Vector2(10,0),"virus":true,"age":0.0,"life":2.0}]
 for frame in range(240):
  if frame%4==0:s.elapsed+=1.0/60
  view.update(s,1.0/240,1.0/240)
 check(is_equal_approx(view.trails[0].age,1.0),"240 Hz render clock ages one second despite only 60 simulation steps")
 view.update(s,5.0,0.0)
 check(is_equal_approx(view.trails[0].age,1.0),"Explicit scene pause freezes render-time history")
 quit(errors)
