extends SceneTree
class MeterSim extends "res://scripts/simulation.gd":
	var queries=0
	func nearest_virus(p:Vector2,reach:float=10000.0)->Dictionary:
		queries+=1
		return super.nearest_virus(p,reach)
var checks=0
var failures=0
func check(ok,label):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func fixture(key):
	var s=MeterSim.new();s.reset(42,12);s.gym_mode=true
	var c=s.make_cell(key,Vector2(1000,0));s.cells=[c]
	s.begin_battle();s.spawn_queue=[]
	s.spawn_virus({"type":"basic","lane":0,"p":Vector2(1150,0)})
	s.viruses.back().hp=100
	c.cool=1.0
	return s
func _initialize():
	# These abilities must still run their own directional/area logic, but do
	# not consume a nearest-virus result in either cooldown state.
	for key in ["wall","tackle","orbiter","regen","pusher","sniper","bond","tag_sprayer"]:
		var s=fixture(key)
		s.update(0.01)
		check(s.queries==0,key+": no unused query during cooldown")
		s.cells[0].cool=0;s.update(0.01)
		check(s.queries==0,key+": own ability does not query nearest virus")
	var shooter=fixture("cannon")
	shooter.update(0.01)
	check(shooter.queries==0,"cooling shooter skips target scan")
	check(not shooter.events.any(func(e):return e.event=="attack_fired"),"cooling shooter does not fire")
	# A target moving during cooldown must be aimed at when firing, not use a
	# cached direction from the previous step.
	shooter.viruses[0].p=shooter.cells[0].p+Vector2(0,80)
	shooter.cells[0].cool=0;shooter.update(0.01)
	var shots=shooter.events.filter(func(e):return e.event=="attack_fired")
	check(shooter.queries==1 and shots.size()==1,"ready shooter queries and fires once")
	check(not shots.is_empty() and shots[0].data.direction==Vector2.DOWN,"shot uses latest target position")
	for key in ["seeker","tag_splitter","tag_proof"]:
		var s=fixture(key);s.catalog[key].range=200.0/float(s.rules.scale)
		s.update(0.01)
		check(s.queries==1,key+": pursuit scans during cooldown")
		check(s.cells[0].get("presentation_target",-1)==s.viruses[0].id,key+": acquisition remains immediate")
		# Tagged detection at twice range remains available.
		s.viruses[0].p=s.cells[0].p+Vector2(300,0);s.viruses[0].tag=1
		s.update(0.01)
		check(s.cells[0].get("presentation_target",-1)==s.viruses[0].id,key+": tagged target remains detectable")
	print("Target queries: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
