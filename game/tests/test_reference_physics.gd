extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Ref=preload("res://scripts/reference_physics.gd")
var errors=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(42,12);s.gym_mode=true
	var core=s.blood[0]
	s.spawn_virus({"type":"jumper","lane":0,"p":Vector2(500,0)})
	var virus=s.viruses[0]
	check(is_equal_approx(s.physics.radius(virus),26.0/3.5),"Reference virus radius")
	check(is_equal_approx(s.physics.mass(s,virus)/s.physics.mass(s,core),1.0/(10*1.75*1.75)),"Reference virus/Core mass ratio")
	for key in s.catalog:
		var cell=s.make_cell(key,Vector2.ZERO)
		check(s.physics.mass(s,cell)>0 and s.physics.inertia(s,cell)>0,"Valid mass and inertia: "+key)
	var wall=s.make_cell("wall",Vector2.ZERO)
	check(s.physics.half_size(wall).is_equal_approx(Vector2(128,32)/12*Ref.SCALE/2),"Wall geometry follows reference fixture")
	var seeker=s.make_cell("seeker",Vector2.ZERO)
	check(is_equal_approx(s.physics.radius(seeker),64.0/24*Ref.SCALE),"Seeker physical size")
	var impulse=Ref.impulse(250.0)
	s.physics.impulse(s,virus,Vector2(impulse,0))
	check(is_equal_approx(s.physics.velocity(virus).x,250/PI*Ref.SCALE),"Jumper impulse uses actual reference mass")
	s.physics.clear();s.apply_tuning("virus:jumper",{"physics/density":2})
	s.physics.impulse(s,virus,Vector2(impulse,0))
	check(is_equal_approx(s.physics.velocity(virus).x,125/PI*Ref.SCALE),"Doubling density halves impulse response")
	s.physics.clear();s.tuning.clear();virus.physics_diameter=2.5
	check(is_equal_approx(s.physics.mass(s,virus),PI*1.25*1.25*Ref.MASS_UNIT),"Feeding grows physical area and mass")
	s.viruses=[];s.cells=[seeker];s.blood=[];s.blood_links=[];s.phase="battle"
	s.physics.state(seeker).v=Vector2(10,0);s.physics.state(seeker).w=1
	s.physics.step(s,1.0/60)
	print("DAMP ",s.physics.velocity(seeker)," ",s.physics.angular_velocity(seeker)," ",s.rules.body_physics)
	# Measured with the actual Box2D_v2.3.1 library shipped in Demo 1.0.0.
	check(absf(s.physics.velocity(seeker).x-9.9173555374)<0.00001,"Linear damping agrees with original library probe")
	check(absf(s.physics.angular_velocity(seeker)-0.9230769277)<0.00001,"Angular damping agrees with original library probe")
	s.physics.clear();s.drive_reference_cell(seeker,Vector2.RIGHT*18*Ref.SCALE,1.0/60)
	check(is_equal_approx(s.physics.velocity(seeker).x,90*Ref.SCALE/60),"Friendly Seeker constant reference acceleration")
	for i in range(360):
		s.drive_reference_cell(seeker,Vector2.RIGHT*18*Ref.SCALE,1.0/60)
		s.physics.step(s,1.0/60)
	check(s.physics.velocity(seeker).x>18*Ref.SCALE*0.90,"Friendly Seeker reaches reference cruising speed")
	print("FRIEND ",s.physics.velocity(seeker))
	s.physics.clear();seeker.p=Vector2(30,0);seeker.hp=100
	s.start_blast(Vector2.ZERO,100,0,600)
	s.advance_blasts(1)
	var ref_mass=PI*pow(64.0/24,2)
	check(is_equal_approx(s.physics.velocity(seeker).x,600/ref_mass*Ref.SCALE),"Blast is a one-shot impulse without /60")
	check(s.rules.body_physics.contact_impulse_scale==1,"No unreferenced contact boost")
	check(s.rules.blood_elasticity.stiffness>0,"Core elastic settings retained")
	quit(errors)
