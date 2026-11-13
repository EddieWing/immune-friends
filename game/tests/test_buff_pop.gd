extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok:failures+=1
func _initialize():
 var sim=load("res://scripts/simulation.gd").new()
 sim.reset(42,12)
 var layer=load("res://scripts/support_presentation.gd").new()
 layer.update(sim,0)
 sim.offers=["wall"]
 sim.money=10
 check(sim.purchase(0,Vector2(100,0)),"Ordinary purchase succeeds")
 layer.update(sim,0)
 check(layer.effects.is_empty(),"No false buff/pop on ordinary purchase")
 var wall=sim.cells.back()
 sim.offers=["wall"]
 check(sim.purchase(0,wall.p),"Direct merge succeeds")
 layer.update(sim,0)
 var merges=layer.effects.filter(func(e):return e.kind=="merge")
 check(merges.size()==1 and merges[0].id==wall.id,"Merge pop belongs to surviving cell")
 layer.update(sim,0)
 check(layer.effects.size()==1,"No duplicate event consumption")
 var snapshot=sim.cells.duplicate(true)
 layer.update(sim,1)
 check(layer.effects.is_empty() and sim.cells==snapshot,"Pop expires without changing cells")
 print("RESULT: buff pop, %d failures"%failures)
 quit(1 if failures else 0)
