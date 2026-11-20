extends SceneTree
const Sim=preload('res://scripts/simulation.gd')
const Motion=preload('res://scripts/tackle_motion.gd')
var errors=0
func check(ok,label):
	print(('PASS: ' if ok else 'FAIL: ')+label)
	if not ok:errors+=1
func _initialize():
	var s=Sim.new();s.reset(42,12)
	var c=s.make_cell('tackle',Vector2(400,0));s.cells=[c]
	s.begin_battle();s.spawn_queue=[]
	c.angle=0
	check(Motion.direction(s,c,4.99).x>0.99,'Outbound until five seconds')
	check(Motion.direction(s,c,0.02).x<0,'Returns toward Core after five seconds')
	var count=s.events.filter(func(e):return e.event=='cell_return').size()
	Motion.direction(s,c,1)
	check(s.events.filter(func(e):return e.event=='cell_return').size()==count,'Return event emitted only once')
	for b in s.blood:b.alive=false
	check(Motion.direction(s,c,0.1)==Vector2.ZERO,'No live Core: safely stop')
	var b=s.blood[0];b.alive=true;b.p=Vector2(700,0)
	check(Motion.direction(s,c,0.1).x>0,'Tracks current position of surviving Core')
	c.p=b.p+Vector2(s.physics.radius(c)+s.physics.radius(b)+10,0)
	check(Motion.direction(s,c,0.1)==Vector2.ZERO,'Stops outside Core instead of driving into it')
	Motion.reset(c)
	check(not c.tackle_returning and c.tackle_age==0,'Next battle resets outbound timer')
	s.blood[0].p=Vector2.ZERO;c.p=Vector2(400,0);c.angle=0
	s.phase='battle';s.spawn_queue=[{'type':'basic','lane':0,'p':Vector2(8000,0),'due':300.0}]
	c.tackle_age=4.99;s.update(1.0/30.0)
	check(c.tackle_returning,'Real simulation invokes five-second return')
	quit(errors)

