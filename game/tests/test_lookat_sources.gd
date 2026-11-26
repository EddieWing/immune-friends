extends SceneTree
var failures=0
func check(ok,label):
 print(('PASS ' if ok else 'FAIL ')+label)
 if not ok:failures+=1
func _initialize():
 var sim=preload('res://scripts/simulation.gd').new();sim.reset(42,12)
 var shooter=sim.make_cell('gatling',Vector2.ZERO);sim.cells=[shooter]
 sim.spawn_virus({'type':'basic','lane':0,'p':Vector2(80,0)})
 var virus=sim.viruses.back();virus.hp=1;virus.jump=false
 var before=sim.rng.state
 sim.damage_virus(virus,1,{'cause':'contact','presentation_owner':shooter.id,'p':shooter.p})
 var event=sim.events.back()
 check(event.event=='virus_defeated' and event.data.owner==shooter.id,'contact kill retains presentation source')
 check(shooter.get('kills',0)==0,'presentation ownership does not grant Gatling projectile bonus')
 check(before==sim.rng.state,'source metadata consumes no gameplay randomness')
 sim.shoot(shooter,Vector2.RIGHT,Vector2.INF,false,virus.id)
 event=sim.events.back()
 check(event.event=='attack_fired' and event.data.target_id==virus.id,'shot event identifies intended target')
 var wall=sim.make_cell('wall',Vector2(90,0));sim.cells.append(wall)
 sim.push_object(wall,Vector2(1,0),'cell',shooter.p,shooter.id)
 event=sim.events.back()
 check(event.event=='pushed' and event.data.source_id==shooter.id,'push identifies source without changing impulse API defaults')
 sim.reset(42,12);sim.blood=sim.blood.slice(0,1);sim.blood_links=[]
 var core=sim.blood[0];core.p=Vector2.ZERO;core.hp=1
 var guard=sim.make_cell('bodyguard',Vector2(30,0));sim.cells=[guard];sim.rebuild_links();sim.phase='battle'
 var observer=load('res://scripts/lookat/observer.gd').new();observer.update(sim,0.2,{})
 sim.intercept_damage(sim.core_endpoint(core),1,{'kind':'virus','id':900,'p':Vector2(40,0)})
 observer.update(sim,0.2,{})
 var transfer={}
 for event_item in sim.events:
  if event_item.event=='transfer':transfer=event_item.data
 check(transfer.get('lethal_prevented',false),'Core lethal interception is attributed using endpoint HP')
 var trigger=observer.engine.states['cell:'+str(guard.id)].triggers.get(60,{})
 check(trigger.get('target','')=='core:'+str(core.id),'Bodyguard looks at protected Core ID, not path coordinates')
 quit(failures)
