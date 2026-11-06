extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var failures=0
var checks=0
func check(ok,message):
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():
 var s=Sim.new();s.reset(42,12)
 var random=RandomNumberGenerator.new();random.seed=392
 for scene in range(80):
  s.cells.clear();s.viruses.clear()
  for i in range(30):
   var p=Vector2(random.randf_range(-700,700),random.randf_range(-400,400))
   if i%3==0:
    var c=s.make_cell("wall" if i%2 else "tag_splitter",p)
    c.angle=random.randf_range(-PI,PI);s.cells.append(c)
   else:s.spawn_virus({"type":"basic","lane":0,"p":p})
  s._prepare_projectile_grid()
  for attempt in range(25):
   var from=Vector2(random.randf_range(-750,750),random.randf_range(-450,450))
   var to=from+Vector2(random.randf_range(-200,200),random.randf_range(-200,200))
   var radius=random.randf_range(0,40)
   if attempt==0:from=s.cells[0].p;to=from
   if attempt==1:from=Vector2(-5000,-5000);to=Vector2(5000,5000)
   var candidates=s.projectile_candidates(from,to,radius)
   var previous=-1
   for body in candidates:
    var index=(s.cells+s.viruses).find(body)
    check(index>previous,"Candidate order changed or duplicate returned")
    previous=index
   for body in s.cells+s.viruses:
    if s.projectile_fraction(body,from,to,radius)<INF:
     check(candidates.has(body),"Broad phase omitted a real circle/rotated-box hit")
  s._clear_projectile_grid()
  var moved=s.cells[0];moved.p=Vector2(5000,5000)
  check(s.projectile_candidates(moved.p,moved.p,0).has(moved),"Outside step lookup must see debug movement")
 check(not s._projectile_grid_active and s._projectile_grid.is_empty() and s._projectile_bodies.is_empty(),"Step index releases all temporary references")
 s.cells=[];s.viruses=[];s.particles=[]
 var wall=s.make_cell("bullet_wall",Vector2(50,0));wall.angle=PI/4
 s.cells=[wall]
 s.spawn_virus({"type":"basic","lane":0,"p":Vector2(50,0)})
 s._prepare_projectile_grid()
 check(s.projectile_candidates(Vector2.ZERO,Vector2(100,0),5)==s.cells+s.viruses,"Coincident bodies retain cells-before-viruses order")
 s._clear_projectile_grid()
 s.begin_battle();s.gym_mode=true;s.spawn_queue=[]
 s.update(1.0/60)
 check(not s._projectile_grid_active,"Battle update always releases index")
 print("RESULT: %d projectile candidate checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
