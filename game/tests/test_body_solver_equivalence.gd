extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Legacy=preload("res://tests/legacy_body_solver.gd")
func same(a,b):
 for field in ["cells","blood","blood_velocity","viruses","particles","links","events"]:
  if a.get(field)!=b.get(field):return false
 return a.physics.states==b.physics.states and a.physics.contacts==b.physics.contacts and a.rng.state==b.rng.state
func _initialize():
 for with_core in [false,true]:
  var a=Sim.new();var b=Sim.new();b.physics=Legacy.new()
  for s in [a,b]:
   s.reset(812,12);s.gym_mode=true
   if not with_core:s.blood.clear();s.blood_links.clear()
   for i in range(16):
    var c=s.make_cell("wall" if i%3==0 else "turret",Vector2((i%4)*80-120,(i/4)*70-100));c.hp=10000;s.cells.append(c)
   s.rebuild_links();s.begin_battle();s.spawn_queue.clear()
   for i in range(60):
    s.spawn_virus({"type":"basic","lane":0});var v=s.viruses.back();v.emerging=false;v.p=Vector2((i%10)*50-225,(i/10)*45-120);v.hp=10000
  for tick in range(1500):
   for s in [a,b]:
    if tick==300:s.physics.impulse(s,s.cells[0],Vector2(100,-30),s.cells[0].p+Vector2(20,5))
    if tick==500:s.cells[2].p+=Vector2(10,15);s.cells[0].angle=0.7
    if tick==700:s.apply_tuning("wall",{"physics/restitution":0.4,"physics/density":3.0})
    if tick==1000:s.spawn_virus({"type":"jumper","lane":0})
    if tick==1200:s.cells[3].alive=false
   a.update(1.0/60);b.update(1.0/60)
   if not same(a,b):push_error("Body solver diverged at tick %d, Core %s" % [tick,with_core]);quit(1);return
  if not with_core and a.physics.settled_hits==0:push_error("Fixed-point cache never exercised");quit(1);return
 print("BODY SOLVER EXACT EQUIVALENCE PASS: 3000 ticks, stationary/moving, Core, impulse, drag, rotation, tuning, birth, death")
 quit()
