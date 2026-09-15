extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func scenario():
 var sim=load("res://scripts/simulation.gd").new()
 sim.reset(42,12)
 sim.gym_mode=true
 for key in ["cannon","pusher","generator","regen","radar","swapper","bullet_wall","tag_dropper","bodyguard"]:
  sim.cells.append(sim.make_cell(key,Vector2(90+sim.cells.size()*25,40)))
 sim.begin_battle()
 sim.spawn_queue=[]
 for kind in ["hungry","swarmer","seeker","avoider","jumper","basic","wave"]:
  sim.spawn_virus({"type":kind,"lane":0})
  sim.viruses.back().p=Vector2(200+sim.viruses.size()*15,0)
  sim.viruses.back().emerging=false
 return sim
func layers():
 var result=[]
 for key in ["battle_presentation","attack_presentation","reaction_presentation","virus_behavior_presentation","support_presentation"]:
  result.append(load("res://scripts/"+key+".gd").new())
 return result
func snapshot(sim):
 return {"cells":sim.cells.duplicate(true),"blood":sim.blood.duplicate(true),"viruses":sim.viruses.duplicate(true),"particles":sim.particles.duplicate(true),"rng":sim.rng.state,"losses":sim.round_losses.duplicate()}
func _initialize():
 for speed in [1,2,5]:
  var plain=scenario()
  var shown=scenario()
  var visuals=layers()
  for layer in visuals: layer.update(shown,0)
  for frame in range(120):
   for step in range(speed):
    plain.update(1.0/60)
    shown.update(1.0/60)
   for layer in visuals: layer.update(shown,1.0/60)
  check(snapshot(plain)==snapshot(shown),"Presentation preserves combat state at x%d" % speed)
  var sim=shown
  var reaction=visuals[2]
  var virus={"id":9999,"p":Vector2(300,0),"alive":true,"jump":false,"hp":20.0,"type":"basic"}
  sim.viruses.append(virus)
  sim.damage_virus(virus,1)
  reaction.update(sim,0)
  var pose=reaction.pose("virus",virus.id)
  reaction.update(sim,1)
  check(reaction.pose("virus",virus.id)==pose,"Reaction freezes at x%d pause" % speed)
 var sim=scenario()
 var visuals=layers()
 for layer in visuals: layer.update(sim,0)
 var c=sim.cells[0]
 sim.shoot(c,Vector2.RIGHT)
 for layer in visuals: layer.update(sim,0)
 check(not visuals[1].recoil.is_empty(),"Attack registered before transition")
 sim.phase="recap"
 sim.next_round()
 for layer in visuals: layer.update(sim,0.1)
 sim.begin_battle()
 for layer in visuals: layer.update(sim,0)
 check(visuals[1].recoil.is_empty(),"Previous round attacks do not replay at infection start")
 for i in range(12010): sim.record("overflow_probe")
 var virus={"id":12345,"p":Vector2(300,0),"alive":true,"jump":false,"hp":10.0,"type":"basic"}
 sim.damage_virus(virus,1)
 visuals[2].update(sim,0)
 check(sim.events.size()==12000 and visuals[2].pose("virus",virus.id).hurt,"New reactions survive bounded journal overflow")
 sim.reset(42,12)
 for layer in visuals: layer.update(sim,0)
 check(visuals[2].reactions.is_empty() and visuals[1].recoil.is_empty() and visuals[4].effects.is_empty(),"Same-seed restart clears previous visual states")
 print("RESULT: staging lifecycle, %d failures" % failures)
 quit(1 if failures else 0)
