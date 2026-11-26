extends SceneTree
var failures=0
func check(ok,label):
 print(('PASS ' if ok else 'FAIL ')+label)
 if not ok:failures+=1
func _initialize():
 var sim=load('res://scripts/simulation.gd').new();sim.reset(42,12)
 sim.blood=sim.blood.slice(0,1);sim.blood[0].p=Vector2.ZERO;sim.blood_links=[];sim.cells=[];sim.links=[]
 var observer=load('res://scripts/lookat/observer.gd').new()
 var lens_seen=false
 for i in 330:
  observer.update(sim,1.0/60,{'over_field':true,'cursor':Vector2(30,0)})
  lens_seen=lens_seen or observer.output('core:'+str(sim.blood[0].id)).get('lens',0)>0
 check(lens_seen,'stationary cursor triggers Core lens gaze')
 sim.blood=[];sim.blood_links=[];sim.cells=[sim.make_cell('wall',Vector2(-40,0)),sim.make_cell('wall',Vector2(40,0))];sim.rebuild_links();sim.presentation_revision+=1
 sim.links=[{'a':sim.cells[0].id,'b':sim.cells[1].id,'rest':80.0}]
 var blush_seen=false
 for i in 210:
  observer.update(sim,1.0/60,{'over_field':false})
  for c in sim.cells:blush_seen=blush_seen or observer.output('cell:'+str(c.id)).get('emotion','')=='blush'
 check(blush_seen,'bond partners blush after mutual gaze')
 sim.cells=[sim.make_cell('kinetic_bond',Vector2.ZERO)];sim.links=[];sim.presentation_revision+=1
 var uid='cell:'+str(sim.cells[0].id);var spiral_seen=false
 for i in 360:
  observer.update(sim,1.0/60,{'over_field':false,'drag_uid':uid})
  spiral_seen=spiral_seen or observer.output(uid).get('emotion','')=='spiral'
 check(spiral_seen,'kinetic long drag actually triggers spiral in preparation')
 sim.phase='battle';sim.cells=[];sim.presentation_revision+=1
 for i in 3:sim.cells.append(sim.make_cell('turret',Vector2(-80+i*60,0)))
 sim.spawn_virus({'type':'basic','lane':0,'p':Vector2(0,60)})
 var virus=sim.viruses.back();virus.hp=10;virus.peak_hp=10;virus.emerging=false
 observer.update(sim,0.1,{'over_field':false})
 var target='virus:'+str(virus.id)
 for c in sim.cells:observer.engine.states['cell:'+str(c.id)].target=target
 observer.engine.states[target].next=0;observer.engine.states[target].choice={}
 observer.update(sim,0.2,{'over_field':false})
 check(observer.output(target).get('case',0)==179,'virus worries under gaze of three shooters')
 print('LookAt interaction failures: ',failures);quit(failures)

