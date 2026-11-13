extends Node
# Run this scene in an active browser tab. Uses dedicated QA paths; no admin import.
const Fixture=preload("res://tests/fixtures/heavy_battle.gd")
const TARGET_TICKS=3600
const WARMUP_SECONDS=1.0
var game
var label:Label
var running=false
var started_us=0
var frame_times=[]
var initial_hash=""

func _ready():
	game=load("res://main.tscn").instantiate()
	game.settings_path="user://heavy_battle_qa_settings.cfg"
	game.save_path="user://heavy_battle_qa_save.json"
	add_child(game)
	game.main_menu.hide();game.menu_open=false;game.modal.hide()
	game.enter_gym()
	var layer=CanvasLayer.new();layer.layer=50;add_child(layer)
	var panel=PanelContainer.new();panel.position=Vector2(500,85);layer.add_child(panel)
	var column=VBoxContainer.new();panel.add_child(column)
	label=Label.new();label.add_theme_font_size_override("font_size",17);column.add_child(label)
	var start=Button.new();start.text="Start fresh deterministic x5 test";column.add_child(start)
	start.pressed.connect(start_test)
	var stop=Button.new();stop.text="Stop measurement";column.add_child(stop)
	stop.pressed.connect(func():
		if running:finish(false))
	reset_fixture()
	label.text="LOCAL QA · 24 cells / 20 Core / up to 80 viruses\nRefill every 30 simulation ticks; boosted test HP\nTarget: 60 simulation seconds in 12 real seconds\nLeave this browser tab active. Press Start."

func reset_fixture():
	game.paused=true
	game.sim=Fixture.new();game.sim.setup();game.view.sim=game.sim
	game.sim.checkpoint_tick=TARGET_TICKS
	game.clock_accum=0;game.clock_sim=null
	game.set_playback_speed(5)
	game.paused=true
	game.lab_tools.debug_panel.show()
	game.refresh()
	initial_hash=game.sim.fingerprint()

func start_test():
	reset_fixture()
	frame_times.clear()
	started_us=Time.get_ticks_usec()
	running=true;game.paused=false
	# Bound the endpoint without truncating a gameplay tick. The benchmark's
	# own process runs after Main; any final-frame extra ticks are reported.
	label.text="MEASURING · deterministic refill · x5"

func _process(delta):
	if not running:return
	var wall=(Time.get_ticks_usec()-started_us)/1000000.0
	if wall>WARMUP_SECONDS:frame_times.append(delta)
	label.text="MEASURING x5 · %.2f real s / %.2f sim s\nTick %d / %d · debt %.2f sim s"%[wall,game.sim.elapsed,game.sim.stress_ticks,TARGET_TICKS,game.clock_accum]
	if game.sim.stress_ticks>=TARGET_TICKS:finish(true)
	elif wall>=60:finish(false)

func finish(completed):
	var wall=(Time.get_ticks_usec()-started_us)/1000000.0
	game.paused=true;running=false
	var total=0.0
	for value in frame_times:total+=value
	var sorted=frame_times.duplicate();sorted.sort()
	var fps=frame_times.size()/total if total>0 else 0.0
	var p95=sorted[mini(sorted.size()-1,int(sorted.size()*0.95))]*1000 if not sorted.is_empty() else 0.0
	var ratio=game.sim.elapsed/wall if wall>0 else 0.0
	var result={"completed":completed,"wall_seconds":wall,"sim_seconds":game.sim.elapsed,"simulation_ratio":ratio,"ticks":game.sim.stress_ticks,"debt_seconds":game.clock_accum,"fps":fps,"p95_ms":p95,"frames":frame_times.size(),"initial_hash":initial_hash,"final_hash":game.sim.fingerprint(),"checkpoint_tick":TARGET_TICKS,"checkpoint_hash":game.sim.checkpoint_hash,"checkpoint_wall_seconds":(game.sim.checkpoint_us-started_us)/1000000.0 if game.sim.checkpoint_us>0 else -1.0,"refill_ticks":game.sim.refill_ticks,"frame_times":frame_times}
	print("HEAVY_BATTLE_RESULT ",JSON.stringify(result))
	label.text="%s · %.2f real s / %.2f sim s\n%.1f FPS · p95 %.2f ms · actual speed x%.2f\nDebt %.2f sim s · ticks %d · reset for every run"%["FINISHED" if completed else "INCOMPLETE",wall,game.sim.elapsed,fps,p95,ratio,game.clock_accum,game.sim.stress_ticks]
