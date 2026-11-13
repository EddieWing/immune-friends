extends SceneTree
const Fixture=preload("res://tests/fixtures/heavy_battle.gd")
var failures=0
func check(condition,label):
	print(("PASS: " if condition else "FAIL: ")+label)
	if not condition:failures+=1
func _initialize():
	var a=Fixture.new();var b=Fixture.new()
	a.setup();b.setup()
	check(a.cells.size()==24 and a.blood.size()==20 and a.viruses.size()==80,"heavy fixture starts at required population")
	check(a.fingerprint()==b.fingerprint(),"fresh fixture is repeatable")
	# Model different numbers of fixed ticks per rendered frame. No refill
	# occurs in the frame driver: simulation state must be identical.
	for tick in range(180):a.update(1.0/60)
	var remaining=180;var frame=0
	while remaining>0:
		var count=mini(remaining,[1,5,17,3][frame%4])
		for tick in range(count):b.update(1.0/60)
		remaining-=count;frame+=1
	check(a.fingerprint()==b.fingerprint(),"frame grouping cannot change refill or game state")
	check(a.refill_ticks==[0,30,60,90,120,150],"refill follows exact simulation ticks")
	b.setup()
	var fresh=Fixture.new();fresh.setup()
	check(b.fingerprint()==fresh.fingerprint(),"restart restores identical initial fixture")
	quit(1 if failures else 0)
