extends SceneTree
var failures=0
func check(ok,label):
 print(('PASS ' if ok else 'FAIL ')+label)
 if not ok:failures+=1
func _initialize():
 var observer=load('res://scripts/lookat/observer.gd').new()
 var catalog=observer.engine.catalog;var count=0;var cases={};var emotions={}
 for key in catalog:
  count+=catalog[key].size()
  for row in catalog[key]:
   cases[int(row.case)]=true
   if key=='core':emotions[row.emotion]=true
 check(count==1794 and cases.size()==198,'all 1794 mappings / 198 cases are loaded')
 check(emotions.size()==18,'Core has all 18 gameplay expressions')
 for key in ['kinetic_bond','kinetic_generator']:
  for row in catalog[key]:
   if int(row.case) in [37,40]:check(row.phases==['shop'],'long dragging belongs to preparation: '+key)
 var sim=load('res://scripts/simulation.gd').new();sim.reset(42,12)
 var wall=sim.make_cell('wall',Vector2.ZERO);sim.cells=[wall];sim.blood=[];sim.blood_links=[];sim.links=[]
 observer.update(sim,0.1,{'over_field':false})
 var before=var_to_bytes([sim.cells,sim.events,sim.rng.state,sim.blood,sim.particles])
 for i in 120:observer.update(sim,1.0/60,{'over_field':false})
 check(before==var_to_bytes([sim.cells,sim.events,sim.rng.state,sim.blood,sim.particles]),'observer never writes sim bodies/events/RNG')
 var clock=observer.engine.now
 observer.update(sim,1,{'paused':true})
 check(clock==observer.engine.now,'pause freezes attention time')
 observer.update(sim,0.1,{'speed':5})
 check(is_equal_approx(observer.engine.now-clock,0.1),'x5 does not accelerate expression clock')
 # Hit arbitration and source identity use real events.
 sim.phase='battle'
 sim.damage_cell(wall,0.1,false,{'kind':'virus','id':999,'p':Vector2(90,0)})
 observer.update(sim,0.2,{})
 var output=observer.output('cell:'+str(wall.id))
 check(output.get('emotion','')=='hurt','actual damage selects hurt')
 check(output.get('target','')=='virus:999','attacker metadata survives selection')
 # Purchase/sell cursor state is kept separate from simulation state.
 sim.phase='shop'
 for i in 80:observer.update(sim,1.0/60,{'selected_uid':'cell:'+str(wall.id),'sell_hover':true,'over_field':false})
 check(observer.output('cell:'+str(wall.id)).get('emotion','')=='worried','selected cell anticipates sale')
 print('LookAt failures: ',failures)
 quit(failures)

