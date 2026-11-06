extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const View=preload("res://scripts/attack_presentation.gd")
var errors=0
func check(ok,label):
 print(("PASS: " if ok else "FAIL: ")+label)
 if not ok: errors+=1
func _initialize():
 for speed in [1,5]:
  var s=Sim.new();s.reset(42,12);s.phase="battle"
  s.spawn_virus({"type":"jumper","lane":0,"p":Vector2(500,0)})
  var v=s.viruses[0];v.emerging=false;v.age=2.7;v.phase=0
  var view=View.new();view.update(s,0)
  check(view.jumper_pose(v)==0 and view.jumper_recovery(v)==0,"No fictitious age-cycle cue x"+str(speed))
  v.jump=true;v.jump_remaining=0.1
  s.elapsed+=speed/60.0
  var before=var_to_bytes(v)
  view.update(s,speed/60.0)
  check(view.jumper_pose(v)==1 and var_to_bytes(v)==before,"Real jump drives pose without mutation")
  view.update(s,1)
  check(view.jumper_pose(v)==1,"Pause does not advance physical jump pose")
  v.jump=false;s.elapsed+=speed/60.0;view.update(s,speed/60.0)
  check(view.jumper_pose(v)==0 and view.jumper_recovery(v)==1,"Landing starts only after observed real jump")
  s.elapsed+=0.21;view.update(s,0.21)
  check(view.jumper_recovery(v)==0,"Landing settles without repeating")
  v.freeze=1;v.jump=true
  check(view.jumper_pose(v)==0,"Suspend hides jump cue")
  v.alive=false;view.update(s,0)
  check(view.jumps.is_empty(),"Death clears jump state")
  s.reset(43,12);view.update(s,0)
  check(view.jumps.is_empty(),"Reset clears jump state")
 quit(errors)
