extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize():
 var sim=load("res://scripts/simulation.gd").new()
 var stage=load("res://scripts/attack_presentation.gd").new()
 sim.reset(42,12)
 sim.gym_mode=true
 var cannon=sim.make_cell("cannon",Vector2(200,0))
 var sniper=sim.make_cell("sniper",Vector2(200,100))
 var pusher=sim.make_cell("pusher",Vector2(200,-100))
 sim.cells=[cannon,sniper,pusher]
 sim.begin_battle()
 sim.spawn_queue=[]
 stage.update(sim,0.01)
 cannon.cool=0.15
 sniper.cool=0.15
 pusher.cool=0.15
 stage.update(sim,0.01)
 check(stage.poses[cannon.id].windup==0 and stage.poses[pusher.id].windup>0,"Targeted attacks wait for a real target; radial push follows its timer")
 sim.spawn_virus({"type":"basic","lane":0})
 var virus=sim.viruses.back()
 virus.p=cannon.p+Vector2(40,0)
 virus.emerging=false
 stage.update(sim,0.01)
 check(stage.poses[cannon.id].windup>0,"Cannon anticipates inside the existing cooldown")
 virus.p=sniper.p+Vector2(0,40)
 stage.update(sim,0.01)
 check(stage.poses[sniper.id].windup==0,"Sniper does not promise a shot outside its firing cone")
 virus.p=sniper.p+Vector2(40,0)
 stage.update(sim,0.01)
 check(stage.poses[sniper.id].windup>0,"Sniper anticipates a target inside its actual firing cone")
 var before=sim.cells.duplicate(true)
 var random_state=sim.rng.state
 sim.shoot(cannon,Vector2.RIGHT)
 stage.update(sim,0.01)
 check(stage.poses[cannon.id].kick==1,"Only an actual shot triggers recoil")
 stage.update(sim,1.0)
 check(stage.poses[cannon.id].kick==1,"Pause freezes attack recovery")
 sim.elapsed+=0.4
 stage.update(sim,0.4)
 check(stage.poses[cannon.id].kick==0,"Recovery finishes on the simulation clock")
 check(sim.cells==before and sim.rng.state==random_state,"Presentation leaves combat state and randomness unchanged")
 var jumper={"type":"jumper","age":2.65,"phase":0.0,"emerging":false,"freeze":0.0}
 check(stage.jumper_pose(jumper)>0,"Jumper crouches before its existing leap boundary")
 jumper.freeze=1.0
 check(stage.jumper_pose(jumper)==0,"Frozen jumper does not advertise a moving leap")
 virus.type="hungry"
 virus.hp=1
 virus.peak_hp=4
 virus.p=Vector2(500,0)
 sim.damage_virus(virus,1)
 stage.update(sim,0.01)
 check(not stage.focus.is_empty(),"Grown hungry virus receives a selective death accent even after losing HP")
 stage.focus={}
 sim.record("virus_defeated",{"id":999,"p":Vector2.ZERO,"type":"basic"})
 stage.update(sim,0.01)
 check(stage.focus.is_empty(),"Core collision death is not presented as a cleared threat")
 print("RESULT: attack presentation, %d failures" % failures)
 quit(1 if failures else 0)
