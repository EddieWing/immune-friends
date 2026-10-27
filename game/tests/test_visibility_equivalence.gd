extends SceneTree
func _initialize():
 var s=preload("res://scripts/simulation.gd").new();s.reset(811,12)
 var faces=preload("res://scripts/blood_faces.gd").new()
 var rng=RandomNumberGenerator.new();rng.seed=9918
 for i in range(16):
  var c=s.make_cell("wall",Vector2(rng.randf_range(-300,300),rng.randf_range(-250,250)));c.angle=rng.randf_range(-PI,PI);s.cells.append(c)
 for i in range(5000):
  var a=Vector2(rng.randf_range(-400,400),rng.randf_range(-300,300))
  var b=Vector2(rng.randf_range(-400,400),rng.randf_range(-300,300))
  if faces.visible(s,a,b)!=original_visible(s,a,b):push_error("Visibility changed at ray "+str(i));quit(1);return
 print("VISIBILITY EQUIVALENCE PASS: 5000 rays / 16 rotated walls")
 quit()
func original_visible(sim,origin,target):
 for c in sim.cells:
  if not c.alive or sim.catalog[c.key].behavior!="wall": continue
  var a=(origin-c.p).rotated(-c.angle)
  var b=(target-c.p).rotated(-c.angle)
  var corners=[Vector2(-43,-13),Vector2(43,-13),Vector2(43,13),Vector2(-43,13)]
  if Rect2(-43,-13,86,26).has_point(a): continue
  for i in range(4):
   if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])!=null: return false
 return true
