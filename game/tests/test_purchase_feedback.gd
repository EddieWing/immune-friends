extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok:failures+=1
func _initialize():
 var sim=load("res://scripts/simulation.gd").new()
 sim.reset(42,12);sim.experimental=true;sim.money=100;sim.tier=5
 var wall=sim.make_cell("resonant_wall",Vector2.ZERO)
 var buffer=sim.make_cell("resonant_buffer",Vector2(200,0))
 sim.cells=[wall,buffer]
 var layer=load("res://scripts/support_presentation.gd").new()
 layer.update(sim,0)
 var before=sim.cells.duplicate(true)
 var routes=layer.purchase_preview(sim,"wall",Vector2(400,0))
 check(routes.size()==2 and sim.cells==before,"Preview reads both real bonuses without mutation")
 check(layer.purchase_preview(sim,"wall",Vector2.INF).is_empty(),"Cancel removes preview")
 sim.rewards=["wall"]
 check(sim.purchase(0,Vector2(400,0),true),"Reward purchase succeeds")
 layer.update(sim,0)
 var effects=layer.effects.filter(func(e):return e.kind=="purchase_buff")
 var bought=sim.cells.back()
 check(effects.size()==2,"Only actual buffs emit cues")
 check(effects[0].id==wall.id and effects[0].source_id==bought.id,"Resonant Wall receives trigger from purchased B")
 check(effects[1].source_id==buffer.id and effects[1].id==bought.id,"Buffer targets actual new cell")
 sim.rewards=["wall"]
 sim.purchase(0,bought.p,true)
 layer.update(sim,1)
 effects=layer.effects.filter(func(e):return e.kind=="purchase_buff")
 check(effects.size()==2 and effects[1].id==bought.id,"Direct merge remaps effect to survivor")
 sim.money=0;sim.offers=["wall"]
 var seq=sim.event_sequence
 check(layer.purchase_preview(sim,"wall",Vector2.ZERO).is_empty(),"Unaffordable offer has no bonus preview")
 check(not sim.purchase(0,Vector2.ZERO) and seq==sim.event_sequence,"Refused purchase emits no buff")
 check(not layer.purchase_preview(sim,"wall",Vector2(400,0),true).is_empty(),"Free reward remains previewable without money")
 sim.money=100
 while sim.cells.size()<sim.capacity():sim.cells.append(sim.make_cell("wall",Vector2(900,0)))
 check(layer.purchase_preview(sim,"bandage",Vector2.ZERO).is_empty(),"Full capacity rejects incompatible preview")
 routes=layer.purchase_preview(sim,"wall",Vector2(2000,0))
 check(routes.size()==2 and routes[1].to!=Vector2(2000,0),"Full capacity directs bonus to merge survivor")
 print("RESULT: purchase feedback, %d failures"%failures)
 quit(1 if failures else 0)
