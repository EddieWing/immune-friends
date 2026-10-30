extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Replay=preload("res://scripts/battle_replay.gd")
const Save=preload("res://scripts/preparation_save.gd")
var failures=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
	var s=Sim.new();s.reset(42,12)
	var c=s.make_cell("wall",Vector2(120,0));s.cells=[c]
	var recorder=Replay.new();recorder.start(s);s.begin_battle()
	for i in range(10000):
		s.update(Replay.STEP);recorder.tick(s)
		if s.phase!="battle":break
	check(not recorder.last.is_empty(),"completed battle recorded")
	var data=JSON.parse_string(JSON.stringify(recorder.last,"",true,true))
	var result=Replay.open(data)
	check(not result.has("error"),"stored replay opens")
	if result.has("error"):quit(1);return
	var before=Save.capture(s)
	for i in range(int(data.ticks)):result.sim.update(Replay.STEP)
	check(Replay.outcome(result.sim)==data.outcome,"recorded outcome exactly reproduced")
	check(Save.capture(s)==before,"playback does not change current run or rewards")
	var invalid=data.duplicate(true);invalid.rules="old-version"
	check(Replay.open(invalid).has("error"),"different game version rejected")
	var player=preload("res://scripts/ui/replay_view.gd").new();player.data=data;root.add_child(player);await process_frame
	player.paused=true;var tick=player.ticks;player._process(1.0)
	check(player.ticks==tick,"pause holds replay")
	player.reset();player.speed=5;player._process(1.0/60.0)
	check(player.ticks>1 and player.ticks<=5,"speed advances fixed ticks")
	player.queue_free();await process_frame
	print("RESULT: battle replay, %d failures"%failures);quit(1 if failures else 0)
