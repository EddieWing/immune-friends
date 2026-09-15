extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize():
 var sim=load("res://scripts/simulation.gd").new()
 sim.reset(42,12)
 sim.gym_mode=true
 sim.begin_battle()
 sim.spawn_queue=[]
 var layer=load("res://scripts/attention_presentation.gd").new()
 var faces=load("res://scripts/blood_faces.gd").new()
 layer.update(sim,0,faces)
 sim.record("virus_defeated",{"p":Vector2(200,0),"key_threat":true})
 sim.record("blood_lost",{"id":sim.blood[0].id,"p":sim.blood[0].p})
 layer.update(sim,0,faces)
 check(layer.active.kind=="loss","Simultaneous Core loss takes priority over success")
 var age=layer.active.age
 layer.update(sim,1,faces)
 check(layer.active.age==age,"Priority accent freezes on pause")
 sim.elapsed+=1.1
 layer.update(sim,1.1,faces)
 check(layer.active.is_empty(),"Accent expires without an unbounded event queue")
 sim.viruses=[{"id":999,"type":"basic","alive":true,"p":sim.blood[0].p+Vector2(30,0)}]
 sim.record("virus_defeated",{"p":Vector2(200,0),"key_threat":true})
 layer.update(sim,0,faces)
 check(layer.active.kind=="danger","Immediate danger takes priority over cleared threat")
 sim.elapsed+=1.1
 sim.record("virus_defeated",{"p":Vector2(200,0),"key_threat":true})
 layer.update(sim,1.1,faces)
 check(layer.active.is_empty(),"Success cannot replace a continuing danger during warning cooldown")
 sim.viruses=[]
 var a=sim.make_cell("wall",Vector2(200,0))
 var b=sim.make_cell("bond",Vector2(240,0))
 sim.cells=[a,b]
 sim.links=[{"a":a.id,"b":b.id,"rest":40,"owner":b.id}]
 layer.update(sim,0,faces)
 a.alive=false
 layer.update(sim,0,faces)
 check(layer.active.kind=="link","Breaking a real bond receives a bounded accent")
 print("RESULT: attention presentation, %d failures" % failures)
 quit(1 if failures else 0)
