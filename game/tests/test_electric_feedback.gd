extends SceneTree
func _initialize():
 var s=load("res://scripts/simulation.gd").new();s.reset(42,12);s.blood.clear();s.blood_links=[];s.rules.charge_range=100
 var a=s.make_cell("zapper",Vector2.ZERO);var relay=s.make_cell("wall",Vector2(90,0));s.cells=[a,relay];a.charge=1
 s.spawn_virus({"type":"seeker","lane":0,"p":Vector2(180,0)})
 var v=s.viruses[0];v.hp=3
 var view=load("res://scripts/battle_presentation.gd").new();view.update(s,0)
 for i in range(7):s.electricity.update(s)
 view.update(s,0)
 assert(view.signals.size()==1)
 var path=view.signals[0].path.duplicate()
 assert(path[0]==a.p and path.has(relay.p) and path[-1]==v.p)
 var state=s.cells.duplicate(true);var hp=v.hp
 view.update(s,0)
 assert(view.signals.size()==1 and s.cells==state and v.hp==hp)
 s.cells.clear();s.viruses.clear();view.update(s,0.1)
 assert(view.signals[0].path==path)
 for i in range(200):s.record("discharge",{"path":path})
 view.update(s,0)
 assert(view.signals.size()==64)
 view.update(s,1)
 assert(view.signals.is_empty())
 print("PASS: real routed discharge, no duplicate/recalculation, deleted endpoints, bounded overload, expiry")
 quit()
