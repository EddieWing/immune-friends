extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize():
 var sim=load("res://scripts/simulation.gd").new()
 sim.reset(42,12)
 var source=load("res://scripts/source_presentation.gd").new()
 source.update(sim,sim.wave,sim.infection_sources,"",2.0)
 var origin=source.states[0].p
 var future=sim.infection_sources.duplicate()
 future[0]+=Vector2(-120,80)
 var wave=sim.wave.duplicate(true)
 wave[0].count+=3
 source.update(sim,wave,future,"warning",0.1)
 check(source.states[0].p!=origin and source.states[0].p!=future[0],"Source travels instead of teleporting when forecast opens")
 check(source.states[0].surge>0,"Increasing a source threat triggers a surge")
 var intermediate=source.states[0].p
 sim.round_no+=1
 sim.wave=wave
 sim.infection_sources=future
 source.update(sim,sim.wave,sim.infection_sources,"",0.1)
 check(source.states[0].p!=future[0] and source.states[0].p.distance_to(future[0])<intermediate.distance_to(future[0]),"Immediate OK continues the same movement in preparation")
 source.update(sim,sim.wave,sim.infection_sources,"",1.0)
 check(source.states[0].p==future[0] and source.states[0].surge==0,"Source settles exactly at the real spawn position; surge ends")
 source.update(sim,sim.wave,sim.infection_sources,"",0.1)
 check(source.states[0].surge==0,"Unchanged threat does not retrigger its effect")
 var changed=wave.duplicate(true)
 changed[0].type="seeker"
 source.update(sim,changed,future,"warning",0.1)
 check(source.states[0].surge>0,"A new virus type is emphasized even with unchanged total count")
 sim.begin_battle()
 var snapshot=sim.infection_sources.duplicate()
 source.update(sim,sim.wave,sim.infection_sources,"launch",0.65)
 check(source.states[0].opening==1 and sim.viruses.is_empty(),"Miasma opens during launch before viruses arrive")
 sim.spawn_queue=[]
 sim.spawn_virus({"type":"basic","lane":0})
 check(sim.viruses[0].p==source.states[0].p,"Virus is born inside the visible source")
 source.update(sim,sim.wave,sim.infection_sources,"",0.5)
 check(source.states[0].opening==1,"Source stays open while its last virus is emerging")
 sim.viruses[0].emerging=false
 source.update(sim,sim.wave,sim.infection_sources,"",0.7)
 check(source.states[0].opening==0,"Source settles after emission ends")
 check(sim.infection_sources==snapshot,"Presentation never changes the simulation spawn positions")
 source.update(sim,[],sim.infection_sources,"",0.1)
 check(not source.states.is_empty() and not source.states[0].active,"Removed sources fade instead of vanishing")
 source.update(sim,[],sim.infection_sources,"",1.0)
 check(source.states.is_empty(),"Retired sources are cleaned up")
 print("RESULT: source presentation, %d failures" % failures)
 quit(1 if failures else 0)
