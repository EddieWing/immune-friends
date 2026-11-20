extends SceneTree
func _initialize():
 var s=preload('res://scripts/simulation.gd').new();s.reset(42,12);s.phase='battle';s.blood=[];s.cells=[];s.viruses=[]
 var c=s.make_cell('turret',Vector2.ZERO);s.cells=[c]
 var v=preload('res://atlas_integration/presentation.gd').new();v.update(s,0)
 s.shoot(c,Vector2.RIGHT);s.advance_projectiles_native(1.0/60,1.0/60)
 var shots=s.events.filter(func(e):return e.event=='projectile_travel')
 assert(shots.size()==1 and shots[0].data['from']==Vector2.ZERO and shots[0].data.to==s.particles[0].p)
 s.advance_projectiles_native(1.0/60,1.0/60)
 assert(s.events.filter(func(e):return e.event=='projectile_travel').size()==1,'Only one trace event per shot')
 v.update(s,0);assert(v.shot_trails.size()==1,'Fast shot remains visible even after its simulation step')
 s.elapsed+=0.2;v.update(s,0.2);assert(v.shot_trails.is_empty(),'Trace fades rather than becoming a permanent beam')
 print('PASS: actual projectile path retained briefly, one event per shot, expires');quit()
