extends RefCounted
const Sim=preload("res://scripts/simulation.gd")
const Faces=preload("res://scripts/blood_faces.gd")
const Current=preload("res://scripts/attention_presentation.gd")
const Legacy=preload("res://tests/fixtures/legacy_attention.gd")
func snapshot(layer):
 return [layer.active,layer.links,layer.cooldowns,layer.clock,layer.cursor,layer.elapsed,layer.phase_seen,layer.revision_seen]
func run():
 var sim=Sim.new();sim.reset(42,12)
 var current=Current.new();var legacy=Legacy.new();var faces=Faces.new()
 var random=RandomNumberGenerator.new();random.seed=78321
 var current_us=0;var legacy_us=0
 for frame in range(2400):
  if frame%400==0:
   sim.reset(frame+42,12)
   sim.cells=[sim.make_cell("wall",Vector2(-60,20)),sim.make_cell("wall",Vector2(50,-30)),sim.make_cell("bond",Vector2(80,0))]
   sim.links=[{"a":sim.cells[0].id,"b":sim.cells[2].id}]
  sim.phase="battle" if frame%240<220 else "recap"
  var dt=[0.0,1.0/60,5.0/60,0.4][frame%4]
  sim.elapsed+=dt
  for core in sim.blood:
   core.alive=frame%200<180 or core.id%3!=0
  for cell in sim.cells:
   cell.alive=frame%170<130
   cell.angle=frame*0.023+cell.id
  sim.viruses=[]
  for i in range(80):
   var extent=70 if frame%150<100 else 600
   sim.viruses.append({"id":i+200,"type":"basic","alive":i%11!=frame%11,"p":Vector2(random.randf_range(-extent,extent),random.randf_range(-extent,extent))})
  if frame%73==0:sim.record("blood_lost",{"id":sim.blood[0].id,"p":Vector2(12,34)})
  if frame%31==0:sim.record("virus_defeated",{"id":200,"p":Vector2(56,78),"key_threat":true})
  if frame%191==0:sim.presentation_revision+=1
  if frame%101==0:sim.links=[]
  var before=Time.get_ticks_usec()
  if frame%2==0:
   current.update(sim,dt,faces);current_us+=Time.get_ticks_usec()-before
   before=Time.get_ticks_usec();legacy.update(sim,dt,faces);legacy_us+=Time.get_ticks_usec()-before
  else:
   legacy.update(sim,dt,faces);legacy_us+=Time.get_ticks_usec()-before
   before=Time.get_ticks_usec();current.update(sim,dt,faces);current_us+=Time.get_ticks_usec()-before
  if snapshot(current)!=snapshot(legacy):return {"passed":false,"frame":frame,"current":snapshot(current),"legacy":snapshot(legacy)}
 return {"passed":true,"frames":2400,"new_ms":current_us/2400000.0,"old_ms":legacy_us/2400000.0}
