extends SceneTree
func _initialize():
 var s=load("res://scripts/simulation.gd").new();s.reset(42,12)
 var m=load("res://scripts/motion_presentation.gd").new()
 var b=s.blood[0];var id=s.physics.id_of(b)
 m.update(s,0.1)
 assert(m.cilia[b.id]==0)
 s.physics.states[id]={"v":Vector2(140,0)}
 var snapshot=s.blood.duplicate(true)
 m.update(s,0.01)
 assert(m.cilia[b.id]>0 and m.cilia[b.id]<0.1)
 for i in range(30):m.update(s,0.1)
 assert(m.cilia[b.id]>0.99)
 var fast=m.cilia_tint(b.id,Vector2.RIGHT,0)
 s.physics.states[id].v=Vector2.ZERO
 for i in range(30):m.update(s,0.1)
 assert(m.cilia[b.id]<0.01 and fast!=m.cilia_tint(b.id,Vector2.RIGHT,0))
 assert(s.blood==snapshot)
 b.alive=false;m.update(s,0.1)
 assert(not m.cilia.has(b.id))
 var tips=PackedVector2Array()
 for i in range(30):tips.append(Vector2.from_angle(i*TAU/30.0)*13.0)
 var comparisons=0
 for strength in [0.0,0.001,0.17,0.5,0.999,1.0]:
  m.cilia[b.id]=strength
  for tick in range(24):
   var time=tick*0.173
   var colors=m.cilia_tints(b.id,tips,time)
   assert(colors.size()==tips.size())
   for i in range(tips.size()):
    assert(colors[i]==m.cilia_tint(b.id,tips[i]/13.0,time))
    comparisons+=1
 assert(m.cilia_tints(b.id,PackedVector2Array(),0.0).is_empty())
 m.cilia.erase(b.id)
 assert(m.cilia_tints(b.id,tips,0.0)[0]==m.cilia_tint(b.id,tips[0]/13.0,0.0))
 assert(not m.cilia.has(b.id))
 print("PASS: ",comparisons," exact batched cilia colors, empty input and absent Core state")
 print("PASS: cilia smoothing, rest, motion, light, immutable shape, cleanup")
 quit()
