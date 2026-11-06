extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var errors=0
func check(ok,label):
 print(("PASS: " if ok else "FAIL: ")+label)
 if not ok:errors+=1
func _initialize():
 for kind in ["basic","hungry","swarmer","avoider","seeker","jumper","wave"]:
  var s=Sim.new();s.reset(42,12);s.phase="battle";s.blood=[];s.cells=[]
  s.spawn_virus({"type":kind,"lane":0,"p":Vector2.ZERO})
  var v=s.viruses[0];var peak=0.0
  for i in range(360):
   s.virus_motion.tick(s,v,Vector2.RIGHT,1.0/60)
   s.physics.step(s,1.0/60)
   peak=maxf(peak,s.physics.velocity(v).length())
  print("SPEED ",kind," distance=",v.p.x," final=",s.physics.velocity(v).length()," peak=",peak)
  if kind in ["basic","hungry","swarmer","avoider","seeker"]:
   var target={"basic":15.0,"hungry":15.0,"swarmer":15.0,"avoider":20.0,"seeker":25.0}[kind]*26.0/3.5
   check(absf(s.physics.velocity(v).length()-target)<target*0.06,kind+" reference cruising speed")
  if kind=="jumper":check(peak>590 and peak<650,"Jumper reference impulse / virus mass")
  if kind=="wave":check(v.p.x>600 and peak>200,"Wave reference force / virus mass")
  s.rules.movement_multiplier=9.0
  check(is_equal_approx(s.virus_motion.multiplier(s,v),26.0/3.5),"Friendly movement multiplier does not alter "+kind)
 quit(errors)
