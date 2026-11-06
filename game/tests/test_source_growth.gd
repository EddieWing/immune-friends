extends SceneTree
var failures=0
class CanvasProbe:
 extends RefCounted
 var arcs=[]
 var lines=[]
 var labels=[]
 func draw_arc(p,r,_a,_b,_n,c,_w,_aa): arcs.append({"p":p,"r":r,"color":c})
 func draw_line(a,b,c,_w,_aa): lines.append({"a":a,"b":b,"color":c})
 func draw_string(_font,p,t,_align,_width,_size,_color): labels.append({"p":p,"text":t})
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize():
 var sim=load("res://scripts/simulation.gd").new()
 sim.reset(42,12)
 var layer=load("res://scripts/source_presentation.gd").new()
 layer.update(sim,sim.wave,sim.infection_sources,"",2)
 var empty=CanvasProbe.new()
 layer.draw_growth(empty,0)
 check(empty.arcs.is_empty() and empty.labels.is_empty(),"Initial Source has no false growth cue")
 var wave=sim.wave.duplicate(true)
 wave[0].count+=3
 layer.update(sim,wave,sim.infection_sources,"warning",0.1)
 var snapshot=layer.states.duplicate(true)
 var early=CanvasProbe.new()
 layer.draw_growth(early,0)
 check(early.arcs.size()==3 and early.lines.size()==8 and early.labels.size()==1,"Growth renders inward rings, streaks and one label")
 check(layer.states==snapshot,"Rendering does not change Source state")
 layer.update(sim,wave,sim.infection_sources,"warning",0.3)
 var late=CanvasProbe.new()
 layer.draw_growth(late,0)
 check(late.arcs[0].r<early.arcs[0].r and late.arcs[0].color.a<early.arcs[0].color.a,"Growth contracts and fades instead of mimicking outward release")
 check(late.lines[0].a.distance_to(layer.states[0].p)<early.lines[0].a.distance_to(layer.states[0].p),"Streaks converge on the moving Source center")
 layer.update(sim,wave,sim.infection_sources,"",2)
 var ended=CanvasProbe.new()
 layer.draw_growth(ended,0)
 layer.draw_growth(ended,999)
 check(ended.arcs.is_empty() and ended.labels.is_empty(),"Finished and absent Sources do not draw growth")
 print("RESULT: source growth, %d failures"%failures)
 quit(1 if failures else 0)
