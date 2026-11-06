extends "res://scripts/simulation.gd"
# Synthetic load only: refill timing must not depend on rendered frames.
const CELL_KEYS=["wall","cannon","regen","pusher","tag_sprayer","zapper","generator","radar","bond","seeker","orbiter","bomb"]
const VIRUS_KEYS=["basic","wave","jumper","hungry","swarmer","seeker","avoider"]
const REFILL_TICKS=30
const VIRUS_COUNT=80
var stress_ticks=0
var refill_ticks=[]
var checkpoint_tick=0
var checkpoint_hash=""
var checkpoint_us=0

func setup():
	event_sequence=0
	reset(4242,12)
	gym_mode=true
	experimental=true
	cells.clear();viruses.clear();wave.clear();source_emitters.clear();offers.clear()
	for i in range(24):
		var c=make_cell(CELL_KEYS[i%CELL_KEYS.size()],Vector2.from_angle(i*TAU/24)*200)
		c.hp=1000;c.max_hp=1000
		cells.append(c)
	rebuild_links()
	begin_battle()
	spawn_queue.clear()
	for b in blood:b.hp=100000
	stress_ticks=0;refill_ticks.clear();checkpoint_hash="";checkpoint_us=0
	refill()

func refill():
	var count=0
	for v in viruses:
		if v.alive:count+=1
	for i in range(maxi(0,VIRUS_COUNT-count)):
		var angle=(i+int(elapsed)*7)*TAU/VIRUS_COUNT
		spawn_virus({"type":VIRUS_KEYS[i%VIRUS_KEYS.size()],"lane":0,"p":Vector2.from_angle(angle)*400})
		viruses.back().hp=30;viruses.back().peak_hp=30
	viruses=viruses.filter(func(v):return v.alive)
	refill_ticks.append(stress_ticks)

func update(delta:float):
	# This fixture is driven exclusively by the production 1/60-second tick.
	if stress_ticks>0 and stress_ticks%REFILL_TICKS==0:refill()
	super(delta)
	stress_ticks+=1
	if checkpoint_tick>0 and stress_ticks==checkpoint_tick:
		checkpoint_us=Time.get_ticks_usec()
		checkpoint_hash=fingerprint()

func fingerprint():
	# A compact trace for repeated runs of the same build/platform, not a
	# tolerance-based equivalence assertion between independent engines.
	return var_to_bytes([cells,viruses,blood,physics.states,physics.contacts,events,rng.state,particles,effects,pending_cells,links,electricity.currents,blood_velocity,round_losses,phase,money,elapsed,blasts,stress_ticks,refill_ticks]).hex_encode().sha256_text()
