extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Reaction=preload("res://scripts/reaction_presentation.gd")
func hit(s,c,source="virus",amount=1):
 s.record("damage",{"id":c.id,"p":c.p,"from":c.p-Vector2.RIGHT,"source_kind":source,"amount":amount})
func _initialize():
 for speed in [1,5]:
  var s=Sim.new();s.reset(42,12);s.phase="battle"
  var c=s.make_cell("wall",Vector2.ZERO);s.cells=[c]
  c.angle=PI-0.01
  var r=Reaction.new();r.update(s,0)
  # Contact follows physical movement: retain the preceding visible pose.
  c.p=Vector2(1,0);c.angle=-PI+0.01
  hit(s,c);r.update(s,0)
  var key="cell:"+str(c.id)
  assert(r.pose("cell",c.id).offset.is_equal_approx(Vector2(-1,0)))
  assert(is_equal_approx(r.contact_holds[key].angle_offset,-0.02))
  var physical=s.cells.duplicate(true)
  for i in range(4):
   r.deform_transform("cell",c.id,Transform2D(c.angle,c.p))
  assert(s.cells==physical)
  # Repeat releases both position and rotation, including multiple hits per frame.
  c.p+=Vector2(1,0);c.angle+=0.04
  hit(s,c);hit(s,c);r.update(s,0)
  assert(r.pose("cell",c.id).offset==Vector2.ZERO)
  assert(is_zero_approx(r.contact_holds[key].angle_offset))
  c.p+=Vector2(0.5,0);c.angle+=0.03;s.elapsed+=0.01;r.update(s,0)
  assert(r.pose("cell",c.id).offset.x<0)
  assert(r.contact_holds[key].angle_offset<0)
  # Catch-up follows simulation time at both speeds without pausing simulation.
  for i in range(20):
   s.elapsed+=0.01*speed;r.update(s,0)
   assert(r.pose("cell",c.id).offset.length()<=2.001)
  assert(r.contact_holds.is_empty())
  hit(s,c,"unknown");r.update(s,0);assert(r.contact_holds.is_empty())
  hit(s,c,"virus",0);r.update(s,0);assert(r.contact_holds.is_empty())
  s.record("virus_hit",{"id":901,"p":Vector2.ZERO,"from":Vector2.LEFT,"cause":"contact","amount":1})
  r.update(s,0);assert(r.contact_holds.is_empty())
  assert(r.pose("virus",901).hurt)
  assert(is_equal_approx(r.pose("virus",901).squash,0.95))
  s.record("damage",{"id":-99,"kind":"blood","p":Vector2.ZERO,"source_kind":"virus","amount":1})
  r.update(s,0);assert(r.contact_holds.is_empty())
  c.p+=Vector2(100,0);c.angle+=1.0;hit(s,c);r.update(s,0)
  assert(r.pose("cell",c.id).offset.length()<=2.001)
  assert(absf(r.contact_holds[key].angle_offset)<=deg_to_rad(5)+0.00001)
  var t=r.deform_transform("cell",c.id,Transform2D(c.angle,c.p))
  assert(t.origin==c.p)
  assert(t.x.length()>=0.94999 and t.x.length()<=1.05001)
  assert(t.y.length()>=0.94999 and t.y.length()<=1.05001)
  c.alive=false;r.update(s,0);assert(r.contact_holds.is_empty())
  s.presentation_revision+=1;r.update(s,0);assert(r.previous_cells.is_empty())
 print("PASS: cell-only contact position/rotation, repeat release, catch-up, bounds and state isolation x1/x5")
 quit()
