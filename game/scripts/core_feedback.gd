extends RefCounted
var observed_sim
var revision=-1
var cursor=0
var shake=0.0
var bleeding=0.0
var clock=0.0
func update(sim,delta):
 if observed_sim!=sim or revision!=sim.presentation_revision or cursor>sim.event_sequence:
  observed_sim=sim
  revision=sim.presentation_revision
  cursor=sim.event_sequence
  shake=0.0
  bleeding=0.0
 clock+=delta
 shake=maxf(0,shake-delta*3.6)
 bleeding=maxf(0,bleeding-delta*1.4)
 for event in sim.events_since(cursor):
  if event.event=="core_protected": shake=minf(1.0,shake+0.45)
  elif event.event=="blood_lost":
   shake=minf(1.0,shake+0.85)
   bleeding=minf(1.0,bleeding+0.8)
 cursor=sim.event_sequence
func offset():
 return Vector2(sin(clock*83),sin(clock*107+1.7))*shake*shake*3.5
