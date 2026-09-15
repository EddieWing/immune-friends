extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize():
 var sim=load("res://scripts/simulation.gd").new()
 sim.reset(42,12)
 sim.gym_mode=true
 var layer=load("res://scripts/support_presentation.gd").new()
 layer.update(sim,0)
 var wall=sim.make_cell("wall",Vector2(100,0))
 var regen=sim.make_cell("regen",Vector2(200,0))
 sim.cells=[wall,regen]
 sim.heal(wall,2,regen)
 layer.update(sim,0)
 check(layer.effects.back().kind=="heal" and layer.effects.back()["from"]==regen.p and layer.effects.back().amount==2,"Healing identifies the real source, recipient and amount")
 var generator=sim.make_cell("generator",Vector2(300,0))
 sim.cells=[generator]
 sim.begin_battle()
 sim.spawn_queue=[]
 for i in range(8): sim.particles.append({"kind":"food","p":generator.p,"life":8.0,"v":Vector2.ZERO,"r":4.0,"owner":-1})
 sim.update(0.01)
 layer.update(sim,0.01)
 check(generator.charge==8 and generator.food==0 and layer.effects.any(func(e): return e.kind=="generator_charged"),"Eight consumed proteins create a real charge cue")
 var radar=sim.make_cell("radar",Vector2(50,0))
 sim.cells=[radar,wall]
 sim.links=[{"a":radar.id,"b":wall.id,"rest":50,"owner":radar.id}]
 sim.update(0.01)
 layer.update(sim,0.01)
 check(layer.buffs[wall.id].range>1 and layer.effects.any(func(e): return e.kind=="buff" and e.path.size()==2),"Radar effect follows the actual network")
 radar.alive=false
 sim.update(0.01)
 layer.update(sim,0.01)
 check(layer.buffs[wall.id].range==1,"Lost provider removes the range badge")
 var swapper=sim.make_cell("swapper",Vector2.ZERO)
 wall.max_hp=9
 sim.cells=[swapper,wall]
 sim.links=[{"a":swapper.id,"b":wall.id,"rest":40,"owner":swapper.id}]
 var original=swapper.max_hp
 sim.phase="recap"
 sim.next_round()
 layer.update(sim,0.1)
 check(layer.effects.any(func(e): return e.kind=="swap" and e.before_a==original and e.after_a==9 and e.after_b==original),"Both actual HP changes survive the round transition")
 var before=sim.cells.duplicate(true)
 layer.update(sim,0.1)
 check(sim.cells==before,"Support visualizations do not change statistics")
 print("RESULT: support presentation, %d failures" % failures)
 quit(1 if failures else 0)
