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
 var layer=load("res://scripts/virus_behavior_presentation.gd").new()
 layer.update(sim,0)
 for kind in ["hungry","swarmer","seeker","avoider"]:
  sim.spawn_virus({"type":kind,"lane":0})
  var v=sim.viruses.back()
  v.p=Vector2(280+sim.viruses.size()*5,0)
  v.emerging=false
 var hungry=sim.viruses[0]
 var swarmer=sim.viruses[1]
 sim.particles=[{"kind":"food","p":hungry.p,"life":10.0,"r":4.0,"v":Vector2.ZERO,"owner":-1}]
 sim.update(0.01)
 layer.update(sim,0.01)
 check(hungry.hp==2 and layer.feeding.has(hungry.id),"Hungry visual starts only after real food consumption and HP gain")
 check(swarmer.host==hungry.id and layer.attachments.size()==1,"Swarmer clamps only to its actual live host")
 check(layer.effects.any(func(e): return e.kind=="virus_target"),"Seeker announces actual target choice")
 var before=sim.viruses.duplicate(true)
 layer.update(sim,0.1)
 check(sim.viruses==before,"Visual behavior never changes AI")
 hungry.alive=false
 sim.viruses=[hungry,swarmer]
 sim.update(0.01)
 layer.update(sim,0.01)
 check(layer.attachments.is_empty() and swarmer.host==-1,"Attachment disappears when the host dies")
 check(layer.effects.any(func(e): return e.kind=="virus_attachment" and e.host==-1),"Detachment receives its own release effect")
 sim.elapsed+=1
 layer.update(sim,1)
 check(layer.effects.is_empty() and layer.feeding.is_empty(),"Feeding and choice accents expire")
 print("RESULT: virus behavior presentation, %d failures" % failures)
 quit(1 if failures else 0)
