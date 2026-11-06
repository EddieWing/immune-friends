extends SceneTree
func _initialize():
 var s=load("res://scripts/simulation.gd").new();s.reset(42,12);s.gym_mode=true;s.experimental=true
 var c=s.make_cell("tag_drag",Vector2(200,0));s.cells=[c]
 var view=load("res://scripts/support_presentation.gd").new();view.update(s,0)
 s.proteins.drag(s,c,Vector2(350,0));view.update(s,0)
 var created=view.effects.filter(func(e):return e.kind=="interferon_created")
 assert(created.size()==s.particles.size() and not created.is_empty())
 var before=s.particles.duplicate(true)
 view.update(s,0);assert(before==s.particles and view.effects.size()==created.size())
 s.cells=[s.make_cell("tag_sprayer",Vector2.ZERO)];s.begin_battle();s.spawn_queue=[]
 s.cells[0].cool=0;view.update(s,0)
 var seq=s.event_sequence
 s.update(0.01);view.update(s,0)
 assert(s.events_since(seq).any(func(e):return e.event=="interferon_created"))
 assert(view.effects.any(func(e):return e.kind=="interferon_created"))
 print("PASS: preparation drag and combat spray emit real Interferon birth once without mutation")
 quit()
