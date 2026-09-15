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
 sim.spawn_virus({"type":"seeker","lane":0})
 var v=sim.viruses[0]
 v.p=Vector2(300,0)
 v.emerging=false
 var layer=load("res://scripts/reaction_presentation.gd").new()
 layer.update(sim,0)
 sim.damage_virus(v,0.5,{"p":Vector2(320,0),"cause":"bullet"})
 layer.update(sim,0)
 check(layer.pose("virus",v.id).hurt,"Real damage produces a hurt pose")
 check(sim.events.back().data.cause=="bullet","Virus hit retains attack cause")
 var pos=v.p
 sim.push_object(v,Vector2(10,0),"virus",Vector2(200,0))
 layer.update(sim,0)
 check(not layer.pose("virus",v.id).hurt and layer.pose("virus",v.id).squash>1,"Push has a distinct pose")
 check(v.p==pos+Vector2(10,0),"Push distance is unchanged")
 var pose=layer.pose("virus",v.id)
 layer.update(sim,1)
 check(layer.pose("virus",v.id)==pose,"Pause retains reaction")
 v.tag=0.01
 v.freeze=0.01
 sim.update(0.02)
 layer.update(sim,0.02)
 check(layer.bursts.any(func(b): return b.kind=="thawed") and layer.bursts.any(func(b): return b.kind=="tag_ended"),"Actual status expiry releases its visual signs")
 var before=sim.viruses.duplicate(true)
 layer.update(sim,0.1)
 check(sim.viruses==before,"Reactions are cosmetic only")
 sim.elapsed+=1
 layer.update(sim,1)
 check(layer.reactions.is_empty() and layer.bursts.is_empty(),"Reactions expire without accumulating")
 print("RESULT: reactions, %d failures" % failures)
 quit(1 if failures else 0)
