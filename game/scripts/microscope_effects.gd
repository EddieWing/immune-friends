extends RefCounted
var strokes=preload("res://scripts/stroke_cache.gd").new()
var observed_sim
var revision=-1
var elapsed=0.0
var phase=""
var cursor=0
var trails=[]
var previous={}
var bursts=[]
var merges=[]
var intensity=1.0
var friendly_trail_seconds=0.6
var virus_trail_seconds=120.0
var virus_trail_head_seconds=3.0
var virus_trail_tail_weight=0.45
var launch_clear_seconds=0.2
func update(sim,delta,water_delta=-1.0):
 var fresh=observed_sim!=sim or revision!=sim.presentation_revision
 var starting_battle=sim.phase=="battle" and phase!="battle"
 if fresh:
  var profile=sim.rules.get("water_trails",{})
  friendly_trail_seconds=maxf(0.05,float(profile.get("friendly_seconds",0.6)))
  virus_trail_seconds=maxf(0.05,float(profile.get("virus_seconds",120.0)))
  virus_trail_head_seconds=maxf(0.05,float(profile.get("virus_head_seconds",3.0)))
  virus_trail_tail_weight=clampf(float(profile.get("virus_tail_weight",0.45)),0.0,1.0)
  launch_clear_seconds=maxf(0.01,float(profile.get("launch_clear_seconds",0.2)))
 if fresh or (sim.elapsed<elapsed and not starting_battle):
  trails.clear()
 elif starting_battle:
  # Preserve the old field long enough to dissolve it, without drawing a line
  # from a restored preparation position to the previous battle's endpoint.
  for segment in trails: segment["clear_age"]=0.0
 if fresh or sim.elapsed<elapsed or starting_battle:
  previous.clear()
  bursts.clear()
  merges.clear()
  if fresh: cursor=sim.event_sequence
  elapsed=sim.elapsed
 var dt=maxf(0,sim.elapsed-elapsed) if sim.phase=="battle" else delta
 observed_sim=sim
 revision=sim.presentation_revision
 elapsed=sim.elapsed
 phase=sim.phase
 # Water remembers rendered motion, not accelerated simulation time. Freeze
 # during battle pause; death/merge effects below keep their existing clock.
 # The scene supplies its pause-aware render clock: an idle fixed-step frame
 # at 120/240 Hz is not a pause. Standalone callers can infer from sim time.
 var water_dt=water_delta if water_delta>=0 else (maxf(0,delta) if sim.phase!="battle" or dt>0 else 0.0)
 for segment in trails:
  segment.age+=water_dt
  if segment.has("clear_age"):segment.clear_age+=water_dt
 trails=trails.filter(func(s): return s.age<s.life and s.get("clear_age",0.0)<launch_clear_seconds)
 var alive={}
 if sim.phase=="battle":
  for bodies in [sim.viruses,sim.cells,sim.blood]:
   for body in bodies:
    if not body.alive or body.get("emerging",false): continue
    var id=sim.physics.id_of(body)
    alive[id]=true
    if previous.has(id):
     var distance=previous[id].distance_to(body.p)
     if distance>=5 and distance<100:
      var is_virus=body.has("type")
      trails.append({"a":previous[id],"b":body.p,"age":0.0,"virus":is_virus,"life":virus_trail_seconds if is_virus else friendly_trail_seconds})
      previous[id]=body.p
     elif distance>=100: previous[id]=body.p
    else: previous[id]=body.p
 for id in previous.keys():
  if not alive.has(id): previous.erase(id)
 if trails.size()>420: trails=trails.slice(trails.size()-420)
 for b in bursts: b.age+=dt
 for m in merges: m.age+=dt
 bursts=bursts.filter(func(b): return b.age<0.7)
 merges=merges.filter(func(m): return m.age<1.0)
 for e in sim.events_since(cursor):
  if e.event in ["virus_defeated","cell_rest","blood_lost"]:
   bursts.append({"p":e.data.p,"kind":e.event,"age":0.0})
  elif e.event=="merge" and e.data.has("p"):
   merges.append({"p":e.data.p,"rank":e.data.rank,"age":0.0})
 cursor=sim.event_sequence
 if bursts.size()>32: bursts=bursts.slice(bursts.size()-32)
 if merges.size()>8: merges=merges.slice(merges.size()-8)
func trail_strength(segment):
 var remaining=maxf(0.0,1.0-segment.age/segment.life)
 var strength=remaining
 if segment.virus:
  # Original observations establish a short strong impression and a long weak
  # residue, not a universal lifetime. These are our provisional visual curves.
  var head=maxf(0.0,1.0-segment.age/minf(segment.life,virus_trail_head_seconds))
  var tail=remaining*remaining
  strength=(1.0-virus_trail_tail_weight)*head*head+virus_trail_tail_weight*tail
 if segment.has("clear_age"):
  strength*=maxf(0.0,1.0-segment.clear_age/launch_clear_seconds)
 return strength
func draw_under(canvas):
 strokes.begin()
 var density=1.0/maxf(1.0,trails.size()/150.0)
 var points=PackedVector2Array()
 var colors=PackedColorArray()
 for s in trails:
  var alpha=trail_strength(s)*0.26*density*intensity
  points.append(s.a);points.append(s.b)
  colors.append(Color(0.56,0.35,0.70,alpha) if s.virus else Color(0.74,0.94,0.97,alpha))
 if not points.is_empty():canvas.draw_multiline_colors(points,colors,4,true)
 for b in bursts:
  var t=b.age/0.7
  var core=b.kind=="blood_lost"
  var color=Color(0.9,0.3,0.46,(1-t)*0.45*intensity) if core else Color(0.64,0.46,0.72,(1-t)*0.6*intensity)
  for i in range(8 if core else 5):
   var a=i*TAU/(8 if core else 5)
   var p=b.p+Vector2.from_angle(a)*(12+t*(85 if core else 25))
   strokes.arc(canvas,p,(9 if core else 4)*(1-t)+1,a,1.3,8,color,2)
func draw_over(canvas):
 for m in merges:
  var color=Color("#e6ad39") if m.rank==3 else Color("#f3f9ff")
  color.a=1-m.age
  canvas.draw_arc(m.p,28+m.age*24,0,TAU,40,color,2,true)
  canvas.draw_string(ThemeDB.fallback_font,m.p+Vector2(-25,-30-m.age*15),str(m.rank)+"/3",HORIZONTAL_ALIGNMENT_LEFT,-1,28,color)
