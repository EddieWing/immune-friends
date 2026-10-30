extends VBoxContainer
const Replay=preload("res://scripts/battle_replay.gd")
var data={}
var sim
var paused=false
var speed=1
var ticks=0
var debt=0.0
var status:Label
var arena
var pause_button:Button
func _ready():
	var bar=HBoxContainer.new();add_child(bar)
	var pause=Button.new();pause.text="Pause";bar.add_child(pause)
	pause_button=pause
	pause.pressed.connect(func():paused=not paused;pause.text="Resume" if paused else "Pause")
	for value in [1,2,5]:
		var b=Button.new();b.text="×%d"%value;bar.add_child(b);b.pressed.connect(func():speed=value)
	var restart=Button.new();restart.text="Restart";bar.add_child(restart);restart.pressed.connect(reset)
	status=Label.new();add_child(status)
	var container=SubViewportContainer.new();container.custom_minimum_size=Vector2(960,480);add_child(container)
	var viewport=SubViewport.new();viewport.size=Vector2i(960,480);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport)
	var bg=ColorRect.new();bg.color=Color("#cfe6ef");bg.size=Vector2(960,480);viewport.add_child(bg)
	arena=preload("res://scripts/arena_view.gd").new();arena.visuals=preload("res://scripts/cell_visuals.gd").new();arena.scale=Vector2.ONE*0.5;arena.position=Vector2(480,240);viewport.add_child(arena)
	reset()
func reset():
	var result=Replay.open(data)
	if result.has("error"):
		status.text=result.error;sim=null;return
	sim=result.sim;arena.sim=sim;ticks=0;debt=0;paused=false
	pause_button.text="Pause"
	status.text="Recorded battle · viewing does not change your run"
func _process(delta):
	if sim==null or paused or ticks>=int(data.ticks):return
	debt+=maxf(0,delta)*speed
	var budget=Time.get_ticks_usec()
	while debt>=Replay.STEP and ticks<int(data.ticks):
		sim.update(Replay.STEP);ticks+=1;debt-=Replay.STEP
		if Time.get_ticks_usec()-budget>8000:break
	status.text="Recorded battle · %.1f s · ×%d"%[ticks*Replay.STEP,speed]
	if ticks==int(data.ticks):
		status.text="Replay complete · result verified" if Replay.outcome(sim)==data.outcome else "Replay mismatch: result could not be verified (for example, debug edits during the battle)."
