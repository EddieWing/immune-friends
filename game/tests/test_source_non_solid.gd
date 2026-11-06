extends SceneTree
func _initialize():
 var s=load("res://scripts/simulation.gd").new()
 s.reset(42,12)
 s.blood.clear();s.blood_links=[];s.cells=[];s.viruses=[];s.links=[]
 var c=s.make_cell("wall",Vector2(700,0));s.cells=[c]
 s.phase="battle"
 s.infection_sources=[c.p]
 s.physics.step(s,1.0/60)
 assert(c.p.x>690,"Source/old field edge must not displace a cell in battle")
 s.spawn_virus({"type":"basic","lane":0,"p":Vector2(800,0)})
 s.physics.step(s,1.0/60)
 assert(s.viruses[0].p.x>790,"Source must not displace a virus")
 s.phase="shop"
 s.physics.step(s,1.0/60)
 assert(c.p.x<620,"Preparation bounds remain")
 print("PASS source is non-solid; battle unbounded; preparation bounded")
 quit()
