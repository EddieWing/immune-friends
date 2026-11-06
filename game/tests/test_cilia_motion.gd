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
 print("PASS: cilia smoothing, rest, motion, light, immutable shape, cleanup")
 quit()
