extends RefCounted
const Sim=preload("res://scripts/simulation.gd")
const Current=preload("res://scripts/virus_behavior_presentation.gd")
const Legacy=preload("res://tests/fixtures/legacy_virus_behavior.gd")
func snapshot(layer):
 return [layer.feeding,layer.looks,layer.effects,layer.attachments,layer.suspended,layer.tagged,layer.cursor,layer.elapsed,layer.phase_seen,layer.round_seen,layer.revision_seen,layer.motion.samples,layer.motion.modes,layer.motion.wakes,layer.motion.cilia,layer.motion.previous_time,layer.motion.revision]
func run():
 var sim=Sim.new()
 var current=Current.new();var legacy=Legacy.new()
 var rng=RandomNumberGenerator.new();rng.seed=829433
 var new_us=0;var old_us=0
 for frame in range(2400):
  if frame%300==0:
   sim.reset(frame+42,12)
   for i in range(24):sim.cells.append(sim.make_cell("wall" if i%3==0 else "seeker",Vector2(i*12,15)))
   for i in range(80):sim.spawn_virus({"type":["basic","wave","hungry","swarmer","seeker","jumper","avoider"][i%7],"lane":0,"p":Vector2(i*5,-60)})
   current.update(sim,0);legacy.update(sim,0)
  sim.phase=["battle","battle","battle","shop","recap"][int(frame/31)%5]
  var dt=[0.0,1.0/240,1.0/60,5.0/60,0.4][frame%5]
  sim.elapsed+=dt
  for bodies in [sim.blood,sim.cells,sim.viruses]:
   for body in bodies:
    body.alive=(int(body.id)+frame)%13!=0
    body.p+=Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))
    var speed=[0.0,2.9999,3.0,3.0001,30.0,140.0,250.0][(int(body.id)+frame)%7]
    var velocity=Vector2.from_angle(rng.randf_range(-PI,PI))*speed
    var id=sim.physics.id_of(body)
    if (int(body.id)+frame)%17==0:sim.physics.states.erase(id)
    else:sim.physics.states[id]={"v":velocity,"w":0.0}
    if body.has("type"):
     body.freeze=0.5 if (frame+int(body.id))%19==0 else 0.0
     body.tag=1.0 if (frame+int(body.id))%7==0 else 0.0
     body.emerging=(frame+int(body.id))%23==0
     body.exit=body.p+Vector2(21,18)
     body.visual_heading=velocity.normalized()
     body.wave_direction=Vector2.from_angle(frame*0.03)
  sim.links=[{"a":sim.viruses[0].id,"b":sim.viruses[1].id,"swarm":true}]
  if frame%37==0:sim.record("virus_fed",{"id":sim.viruses[0].id,"p":Vector2(10,20),"from":Vector2(-10,0)})
  if frame%43==0:sim.record("virus_target",{"id":sim.viruses[2].id,"p":Vector2(0,20),"target":Vector2.ZERO})
  if frame%181==0:sim.presentation_revision+=1
  var before_state=var_to_bytes([sim.blood,sim.cells,sim.viruses,sim.physics.states,sim.events,sim.rng.state])
  var start=Time.get_ticks_usec()
  if frame%2==0:
   current.update(sim,dt);new_us+=Time.get_ticks_usec()-start
   start=Time.get_ticks_usec();legacy.update(sim,dt);old_us+=Time.get_ticks_usec()-start
  else:
   legacy.update(sim,dt);old_us+=Time.get_ticks_usec()-start
   start=Time.get_ticks_usec();current.update(sim,dt);new_us+=Time.get_ticks_usec()-start
  if snapshot(current)!=snapshot(legacy):return {"passed":false,"frame":frame,"reason":"visual state mismatch"}
  if before_state!=var_to_bytes([sim.blood,sim.cells,sim.viruses,sim.physics.states,sim.events,sim.rng.state]):return {"passed":false,"frame":frame,"reason":"simulation mutation"}
 return {"passed":true,"frames":2400,"new_ms":new_us/2400000.0,"old_ms":old_us/2400000.0}
