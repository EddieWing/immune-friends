extends RefCounted
const Sim=preload("res://scripts/workers/worker_simulation.gd")
const Snapshot=preload("res://scripts/workers/snapshot.gd")
const VIEW_FIELDS=["cells","viruses","blood","blood_links","blood_velocity","particles","effects","blasts","links","source_emitters","infection_sources","wave","spawn_queue","round_losses"]
const SCALARS=["elapsed","phase","round_no","seed_value","presentation_revision","event_sequence","experimental","money","xp","tier","max_funds"]
var worker=Thread.new();var guard=Mutex.new();var credit=0.0;var pending={};var queued_events=[];var published_seq=0;var stopping=false;var suspended=false;var stopped=false;var final_state={};var tick_count=0
func start(s,initial_credit=0.0):
	published_seq=s.event_sequence;credit=initial_credit
	var initial=Snapshot.snapshot(s)
	return worker.start(run.bind(initial))
func add_time(delta):
	guard.lock();credit+=maxf(delta,0);guard.unlock()
func set_paused(value):
	guard.lock();suspended=value;guard.unlock()
func debt():
	guard.lock();var v=credit;guard.unlock();return v
func read():
	guard.lock();var snapshot=pending;pending={};var events=queued_events;queued_events=[];var done=stopped;var final=final_state;guard.unlock()
	return {"view":snapshot,"events":events,"done":done,"final":final}
func stop():
	guard.lock();stopping=true;guard.unlock()
func finish():
	if worker.is_started():worker.wait_to_finish()
func publish(s,done=false):
	var snap={}
	for k in VIEW_FIELDS:snap[k]=s.get(k).duplicate(true)
	for k in SCALARS:snap[k]=s.get(k)
	snap.physics_states=s.physics.states.duplicate(true)
	var events=s.events_since(published_seq).duplicate(true);published_seq=s.event_sequence
	var final=Snapshot.snapshot(s) if done else {}
	if done:final["ticks"]=tick_count
	# The display owns the retained journal; the worker only holds unpublished events.
	s.events.clear()
	guard.lock()
	if done:final["credit"]=credit
	pending=snap;queued_events.append_array(events);stopped=done;final_state=final
	guard.unlock()
func run(initial):
	var s=Sim.new();Snapshot.restore(s,initial);s.physics.web_materials_dirty=true;var last_publish=0;var was_paused=false
	while true:
		guard.lock();var halt=stopping;var paused=suspended;var has_tick=not halt and not paused and credit+0.000000001>=1.0/60.0
		if has_tick:credit-=1.0/60.0
		guard.unlock()
		if halt:break
		if paused and not was_paused:publish(s)
		was_paused=paused
		if not has_tick:OS.delay_usec(500);continue
		if tick_count>0 and tick_count%30==0:after_ticks(s)
		s.update(1.0/60.0);tick_count+=1
		if tick_count>=last_publish+10:
			publish(s);last_publish=tick_count
		if s.phase!="battle":break
	publish(s,true)

# Test subclasses can add a deterministic workload without changing game rules.
func after_ticks(_sim):
	pass
