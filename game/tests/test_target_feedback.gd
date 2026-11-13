extends SceneTree
func _initialize():
 var s=load("res://scripts/simulation.gd").new();s.reset(42,12);s.gym_mode=true
 s.catalog.seeker.range=200
 var c=s.make_cell("seeker",Vector2(1000,0));s.cells=[c];s.begin_battle();s.spawn_queue=[]
 var view=load("res://scripts/support_presentation.gd").new();view.update(s,0)
 s.update(0.01);view.update(s,0.01)
 assert(not view.effects.any(func(e):return e.kind=="cell_target"))
 s.spawn_virus({"type":"basic","lane":0,"p":Vector2(1150,0)})
 var v=s.viruses.back();s.update(0.01);view.update(s,0.01)
 var cues=view.effects.filter(func(e):return e.kind=="cell_target")
 assert(cues.size()==1 and cues[0].target_id==v.id)
 s.update(0.01);view.update(s,0.01)
 assert(view.effects.filter(func(e):return e.kind=="cell_target").size()==1)
 s.spawn_virus({"type":"basic","lane":0,"p":c.p+Vector2(100,0)})
 s.update(0.01);view.update(s,0.01)
 assert(view.effects.filter(func(e):return e.kind=="cell_target").size()==1,"Switch A to B without target loss is not a new acquisition")
 s.viruses.back().alive=false
 v.alive=false;s.update(0.01);view.update(s,0.01)
 cues=view.effects.filter(func(e):return e.kind=="cell_target")
 assert(cues.size()==2 and cues.back().target_id==-1)
 s.spawn_virus({"type":"basic","lane":0,"p":c.p+Vector2(150,0)})
 s.update(0.01);view.update(s,0.01)
 assert(view.effects.filter(func(e):return e.kind=="cell_target").size()==3)
 print("PASS: real Seeker acquisition, stable tracking, loss and reacquisition; loss cue is not an early return cue")
 quit()
