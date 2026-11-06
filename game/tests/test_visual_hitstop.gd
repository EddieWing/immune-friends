extends SceneTree
func _initialize():
 for speed in [1,5]:
  var s=load("res://scripts/simulation.gd").new();s.reset(42,12);s.phase="battle"
  var c=s.make_cell("wall",Vector2.ZERO);s.cells=[c]
  var r=load("res://scripts/reaction_presentation.gd").new();r.update(s,0)
  s.record("damage",{"id":c.id,"p":c.p,"from":Vector2(-1,0),"source_kind":"virus","amount":1})
  r.update(s,0)
  var key="cell:"+str(c.id)
  c.p=Vector2(1,0);s.elapsed+=0.02;r.update(s,0)
  assert(r.contact_holds[key].offset==Vector2(-1,0))
  var before=s.cells.duplicate(true)
  for i in range(10):
   s.elapsed+=0.01*speed
   s.record("damage",{"id":c.id,"p":c.p,"from":Vector2(-1,0),"source_kind":"virus","amount":1})
   r.update(s,0)
   assert(r.pose("cell",c.id).offset.length()<=2.001)
  assert(s.cells==before)
  s.elapsed+=0.3;r.update(s,0)
  assert(r.contact_holds.is_empty())
  s.record("damage",{"id":c.id,"p":c.p,"from":Vector2(-1,0),"source_kind":"unknown","amount":1})
  r.update(s,0);assert(r.contact_holds.is_empty())
  s.record("damage",{"id":c.id,"p":c.p,"from":Vector2(-1,0),"source_kind":"virus","amount":0})
  r.update(s,0);assert(r.contact_holds.is_empty())
 print("PASS: local contact hold/catchup, bounded repeats, no simulation pause, x1/x5")
 quit()
