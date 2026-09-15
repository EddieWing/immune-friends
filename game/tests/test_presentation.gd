extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize():
 var sim=load("res://scripts/simulation.gd").new()
 sim.reset(42,12)
 var view=load("res://scripts/battle_presentation.gd").new()
 var wall=sim.make_cell("wall",Vector2.ZERO)
 var bond=sim.make_cell("bond",Vector2(35,0))
 var guard=sim.make_cell("bodyguard",Vector2(70,0))
 sim.cells=[wall,bond,guard]
 sim.rebuild_links()
 sim.links=[{"a":wall.id,"b":bond.id,"rest":35,"owner":bond.id},{"a":bond.id,"b":guard.id,"rest":35,"owner":bond.id}]
 var before=sim.cells.duplicate(true)
 view.update(sim,0.1)
 var arms=view.bonds.values().filter(func(b): return b.kind=="immune")
 check(arms.size()==2 and arms.all(func(b): return b.progress>0 and b.progress<1),"real bonds extend their arms over time")
 check(sim.cells==before,"presentation does not mutate cell positions or stats")
 view.update(sim,0.2)
 check(arms.all(func(b): return b.progress==1),"hands clasp after extension")
 sim.damage_cell(wall,1,false,{"kind":"virus","id":900,"p":Vector2(-20,0)})
 view.update(sim,0.01)
 check(not view.signals.is_empty() and view.signals[0].path==[wall.p,bond.p,guard.p],"Bodyguard pulse follows the actual bond chain")
 check(view.hits.back().kind=="virus" and view.hits.back()["from"]==Vector2(-20,0),"redirected damage retains the attacker provenance")
 guard.alive=false
 view.update(sim,0.1)
 check(view.bonds.values().any(func(b): return b.kind=="immune" and not b.connected and b.progress>0),"dead partner releases hands before retraction ends")
 sim.cells=[]
 view.update(sim,0.4)
 check(not view.bonds.values().any(func(b): return b.kind=="immune"),"broken immune hands disappear after retraction")
 var bomb=sim.make_cell("bomb",Vector2.ZERO)
 wall=sim.make_cell("wall",Vector2(40,0))
 sim.cells=[bomb,wall]
 sim.links=[]
 sim.damage_cell(bomb,999,false,{"kind":"virus","id":901,"p":Vector2(-20,0)})
 view.update(sim,0.01)
 check(view.hits.any(func(h): return h.kind=="cell" and h.p==wall.p),"Bomb friendly fire has a distinct source kind")
 sim.cells=[]
 sim.particles=[]
 var zapper=sim.make_cell("zapper",Vector2.ZERO)
 var bridge=sim.make_cell("wall",Vector2(40,0))
 sim.cells=[zapper,bridge]
 sim.viruses=[{"id":999,"p":Vector2(85,0),"alive":true,"jump":false,"hp":1,"type":"basic"}]
 sim.conduct(zapper)
 view.update(sim,0.01)
 check(view.signals.any(func(p): return p.kind=="discharge" and p.path==[Vector2.ZERO,Vector2(40,0),Vector2(85,0)]),"electric pulse follows the successful conduction route")
 print("RESULT: presentation checks, %d failures" % failures)
 quit(1 if failures else 0)
