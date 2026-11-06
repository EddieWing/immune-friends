extends RefCounted
const Sim=preload("res://scripts/simulation.gd")
const Old=preload("res://tests/fixtures/legacy_endpoint_lookup.gd")
func fixture(old):
 var s=Old.new() if old else Sim.new()
 s.reset(731,12);s.gym_mode=true;s.experimental=true;s.cells.clear();s.viruses.clear()
 var keys=["wall","cannon","regen","pusher","tag_sprayer","zapper","generator","radar","bond","seeker","orbiter","bomb","sniper","tag_splitter","tag_proof","seeker_factory","tackle","tag_dropper","bodyguard","accelerator","mortar","swapper","electric_wall","kinetic_bond"]
 for i in range(keys.size()):
  if not s.catalog.has(keys[i]):continue
  var c=s.make_cell(keys[i],Vector2.from_angle(i*TAU/keys.size())*180)
  c.hp=10000;c.max_hp=10000;c.angle=i*0.13;s.cells.append(c)
 s.begin_battle();s.spawn_queue.clear()
 for i in range(80):
  s.spawn_virus({"type":["basic","wave","jumper","hungry","swarmer","seeker","avoider"][i%7],"lane":0,"p":Vector2.from_angle(i*TAU/80)*320})
  s.viruses.back().hp=300;s.viruses.back().peak_hp=300
 return s
func same(a,b):
 return a.cells==b.cells and a.viruses==b.viruses and a.blood==b.blood and a.physics.states==b.physics.states and a.physics.contacts==b.physics.contacts and a.events==b.events and a.rng.state==b.rng.state and a.particles==b.particles and a.effects==b.effects and a.pending_cells==b.pending_cells and a.links==b.links and a.electricity.currents==b.electricity.currents and a.blood_velocity==b.blood_velocity and a.round_losses==b.round_losses and a.phase==b.phase and a.money==b.money and a.elapsed==b.elapsed
func mutate(s,tick):
 if tick%13==0:
  for c in s.cells:c.cool=0.0
 if tick%17==0:
  for v in s.viruses:v.tag=3.0
 if tick%37==0:
  s.spawn_virus({"type":"swarmer","lane":0,"p":Vector2(100,50)})
 if tick==45:
  for c in s.cells:
   if c.key=="tag_splitter":s.particles.append({"kind":"tag","p":c.p+Vector2(5,0),"v":Vector2.ZERO,"life":10.0,"r":5.0,"owner":c.id})
 if tick==60:
  for c in s.cells:
   if c.key in ["seeker_factory","mortar"]:
    c.food=100;c.bullet_food=100;c.recipe_pending=true;c.recipe_cool=0
 if tick==90:
  for c in s.cells:c.friendly_stun=0.5
 if tick==100:
  # Old JSON numeric IDs mixed with newly spawned integer IDs.
  for c in s.cells:c.id=float(c.id)
  for v in s.viruses:v.id=float(v.id)
 if tick==110:
  s.cells.reverse();s.viruses.reverse();s.blood.reverse()
 if tick==120:s.experimental=false
 if tick==150:s.experimental=true
 if tick==180:
  for c in s.cells:s.apply_tuning(c.key,{"range":0.0})
 if tick==200:
  s.cells.pop_back();s.viruses.pop_back()
 if tick==220:
  s.cells[0]=s.make_cell("wall",Vector2(40,10))
func run():
 var a=fixture(false);var b=fixture(true)
 var new_us=0;var old_us=0
 for tick in range(240):
  for s in [a,b]:mutate(s,tick)
  var first=a if tick%2 else b;var second=b if tick%2 else a
  var before=Time.get_ticks_usec();first.update(1.0/60);var used=Time.get_ticks_usec()-before
  if first==a:new_us+=used
  else:old_us+=used
  before=Time.get_ticks_usec();second.update(1.0/60);used=Time.get_ticks_usec()-before
  if second==a:new_us+=used
  else:old_us+=used
  if not same(a,b):return {"passed":false,"tick":tick}
  if a.step_lookups_active or not a.cell_lookup.is_empty() or not a.virus_lookup.is_empty() or not a.core_lookup.is_empty():return {"passed":false,"tick":tick,"reason":"cache escaped update"}
 return {"passed":true,"steps":240,"new_ms":new_us/240000.0,"old_ms":old_us/240000.0}
