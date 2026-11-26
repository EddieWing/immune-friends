extends RefCounted
var renderer=preload('res://atlas_integration/renderer.gd').new()
var states={}
var lookat=preload("res://scripts/lookat/observer.gd").new()
var input_context={}
var shot_trails=[]
var connections=preload('res://atlas_integration/connections.gd').new(renderer)
var observed_sim
var revision=-1
var cursor=0
var elapsed=0.0
const EVENTS={
 'attack_fired':['shoot','heavyShot','doubleShot','launchBomb','burst','spray','push','dropTag','split'],
 'generator_fed':['feedMany','feed','loadFour','loadThree','absorb','recipe'],
 'protein_eaten':['feed','feedMany','loadFour','loadThree','absorb','recipe'],
 'generator_charged':['charge','generate'],'charge_generated':['generate','charge'],
 'produced':['spawn','generate'],'cell_split':['split'],'interferon_created':['dropTag','spray','trail'],
 'accelerated':['boost'],'purchase_buff':['growRing','buff','resonance'],
 'permanent_growth':['growRing'],'virus_fed':['eat'],'virus_attachment':['attach'],
 'merge':['merge','morph'],'cell_target':['sense','pursue','aim'],'cell_return':['return','turn'],
 'virus_target':['retarget','pursue'],'core_protected':['alert'],
 'discharge':['conduct','discharge','zap'],'swap':['swap']}
func key_of(body):return ('virus:' if body.has('type') else 'cell:' if body.has('key') else 'core:')+str(body.id)
func id_of(body):return 'virus_'+body.type if body.has('type') else body.get('key','core')
func trigger(state,candidates,duration=1.5):
 for mode in candidates:
  if mode in renderer.data.characters[state.id].modes:
   renderer.action(state,mode);state.age=0.0;state.hold=duration;return true
 return false
func update(sim,delta):
 lookat.update(sim,delta,input_context)
 var face_dt=0.0 if input_context.get("paused",false) else maxf(0,delta)
 var fresh=sim!=observed_sim or revision!=sim.presentation_revision or sim.elapsed<elapsed
 var previous_growth={}
 if fresh:
  for k in states:previous_growth[k]=states[k].get('radius_growth',0.0)
  states.clear();shot_trails.clear();connections.links.clear();connections.transfers.clear();cursor=sim.event_sequence
 var dt=maxf(0,sim.elapsed-elapsed) if sim.phase=='battle' else maxf(0,delta)
 observed_sim=sim;revision=sim.presentation_revision;elapsed=sim.elapsed
 connections.states=states
 var active={}
 var linked={}
 for link in sim.links:
  linked[link.a]=true;linked[link.b]=true
 for bodies in [sim.cells,sim.viruses,sim.blood]:
  for body in bodies:
   var key=key_of(body);var id=id_of(body)
   if not renderer.has_character(id):continue
   if not states.has(key):
    if not body.alive:continue
    var state=renderer.create(id)
    state.p=body.p;state.angle=body.get('angle',0.0);state.hold=0.0;state.dead=false;state.velocity=Vector2.ZERO;state.jump=false;state.charge=body.get('charge',0);state.food=body.get('food',0)
    state.idle_phase=fposmod(float(body.id)*2.399963,TAU)
    state.idle_speed=0.90+0.20*fposmod(float(body.id)*0.618034,1.0)
    state.radius_growth=previous_growth.get(key,body.get('radius_growth',0.0));state.effect_radius=sim.range_of(body) if body.has('key') else 0.0
    states[key]=state
    if not fresh:trigger(state,['placement'],0.65)
   var state=states[key]
   state.preparing=sim.phase=='shop'
   if body.alive:
    active[key]=true
    state.velocity=(body.p-state.p)/dt if dt>0 else state.velocity
    state.p=body.p;state.angle=body.get('angle',0.0)
    state.wave_progress=body.get('wave_progress',state.clock*0.5)
    state.hold=maxf(0,state.hold-dt)
    if id=='hungry_bomb':
     var capacity=maxf(1.0,sim.constant_of(body,'blastIncrement',1)*5.0)
     if float(body.get('radius_growth',0))<float(state.radius_growth):
      state.reset_fill=clampf(float(state.radius_growth)/capacity,0,1)
      trigger(state,['reset'],1.4)
     state.fill_fraction=clampf(float(body.get('radius_growth',0))/capacity,0,1)
    state.radius_growth=body.get('radius_growth',0.0)
    if body.get('jump',false)!=state.jump:
     trigger(state,['jump'] if body.get('jump',false) else ['land'],0.8)
    state.jump=body.get('jump',false)
    if body.get('charge',0)>state.charge:trigger(state,['charge','chargeHeal'],0.7)
    state.charge=body.get('charge',0)
    if body.get('food',0)>state.food:trigger(state,['feedMany','feed','loadFour','loadThree','recipe','absorb'],0.8)
    if body.get('food',0)<state.food:trigger(state,['reward','generate','spawn','split','reset'],1.0)
    state.food=body.get('food',0)
    if state.hold<=0:
     var mode='idle'
     if body.get('tag',0)>0 or body.get('freeze',0)>0:mode='tagged'
     elif body.get('visual_avoiding',false):mode='evade'
     elif body.get('host',-1)>=0 and body.has('type'):mode='attach'
     elif sim.phase=='battle' and state.velocity.length()>0.5:
      mode=first_mode(state,['wave','pursue','swim','swimSlow','orbit','move'])
     else:mode=rest_mode(state,body,linked.has(body.id),sim.phase)
     renderer.action(state,mode)
    var attention=lookat.output(key)
    var look=state.look
    if not attention.is_empty():
     look=attention.look;state.attention_emotion=attention.emotion;state.look_smoothing=attention.smoothing
     state.lens_target=attention.lens;state.attention_blink_age=attention.blink_age
     state.attention_case=attention.case
     state.attention_mix=attention.reaction_mix;state.attention_return=attention.return_emotion
    state.motion_heading=body.get('visual_heading',state.velocity)
    renderer.advance(state,dt,look,face_dt)
    if state.mode=='tagged':state.age=minf(state.age,1.8)
 connections.update(sim,dt)
 for trail in shot_trails:trail.age+=dt
 shot_trails=shot_trails.filter(func(t):return t.age<0.16)
 for event in sim.events_since(cursor):
  var d=event.data;var name=event.event
  if name=='projectile_travel':
   shot_trails.append({'a':d['from'],'b':d.to,'owner':d.owner,'age':0.0});continue
  var kind='virus:' if name.begins_with('virus_') or name in ['tagged','tag_ended','thawed'] else 'core:' if name in ['blood_lost','core_protected'] else 'cell:'
  var key=kind+str(d.get('id',d.get('source',d.get('a',-1))))
  if not states.has(key):continue
  var state=states[key]
  if name in ['damage','virus_hit','pushed']:
   state.hit_direction=(Vector2(d.get('from',state.p+Vector2.RIGHT))-state.p).normalized();state.hit_age=0.0
   if name!='pushed':trigger(state,['hurt'],0.38)
  elif name in ['cell_rest','virus_defeated','blood_lost']:
   state.dead=true;trigger(state,['explode','healDeath','deathPush','death'],2.5)
  elif EVENTS.has(name):trigger(state,EVENTS[name])
  if name in ['virus_fed','protein_eaten','generator_fed']:
   state.feed_age=0.0;state.feed_from=Vector2(d.get('from',state.p))
  if name=='heal':
   connections.heal('cell:'+str(d.get('source_id',-1)),key)
   trigger(state,['heal','healNetwork','chargeHeal'],0.8)
   var provider='cell:'+str(d.get('source_id',-1))
   if states.has(provider):trigger(states[provider],['heal','healNetwork','chargeHeal'],0.8)
 cursor=sim.event_sequence
 for key in states.keys():
  if active.has(key):continue
  var state=states[key]
  if not state.dead:states.erase(key);continue
  renderer.advance(state,dt,state.look,face_dt)
  if state.age>2.5:states.erase(key)
func first_mode(state,candidates):
 for mode in candidates:
  if mode in renderer.data.characters[state.id].modes:return mode
 return 'idle'
func draw_body(canvas,body,width):
 var key=key_of(body)
 if not states.has(key):return
 var state=states[key];state.width=width
 renderer.draw(canvas,state,body.p,width,body.get('angle',0.0))
func draw_deaths(canvas):
 for key in states:
  var state=states[key]
  if state.dead:
   if state.mode in ['healDeath','explode']:
    var progress=clampf(state.age/1.2,0,1);var radius=state.effect_radius*progress
    var color=Color(renderer.data.characters[state.id].get('color','#80bdb4')) if state.mode=='healDeath' else Color('#dc5b65')
    if state.mode=='healDeath':
     for i in range(12,0,-1):canvas.draw_circle(state.p,radius*i/12.0,Color(color,0.018*(1-progress)))
    elif radius>0:canvas.draw_arc(state.p,radius,0,TAU,48,Color(color,1-progress),2.0,true)
   renderer.draw(canvas,state,state.p,state.get('width',40.0),state.angle,1.0)

func rest_mode(state,body,linked,phase):
 var key=state.id
 if key in ['bond','kinetic_bond']:return first_mode(state,['tension','bridge','healNetwork'] if linked else ['idle'])
 if key=='radar':return 'network' if linked else 'radar'
 if key=='swapper':return 'idle' if linked else 'noPartner'
 if key in ['magnet','electromagnet']:return first_mode(state,['magnetic','fieldContact'])
 if key=='bodyguard':return 'guard' if linked else 'idle'
 if key=='bank':return 'economy'
 if key=='wildcard':return 'mergeReady' if body.get('rank',1)<3 else 'idle'
 if key=='resonant_buffer':return 'buff' if linked else 'idle'
 if key=='regen':return 'chargeHeal' if phase=='battle' else 'idle'
 if key=='tag_sprayer':return 'empty' if body.get('cool',0)>0 else 'idle'
 if key=='hungry_bomb':return 'idle'
 if key in ['generator','mint','mortar','seeker_factory','tag_splitter','accelerator']:
  if body.get('food',0)>0:return first_mode(state,['recipe','loadFour','loadThree','feedMany','feed'])
  return first_mode(state,['empty','reset','idle'])
 if body.get('cool',10)<0.3 and phase=='battle':return first_mode(state,['aim','aimFixed','caliber','preparePush','charge'])
 if body.get('charge',0)>0:return first_mode(state,['conduct','charge','chargeHeal'])
 return first_mode(state,['coreIdle','passive','bombIdle','facet','idle'])

func draw_shots(canvas):
 for trail in shot_trails:
  var axis=(trail.b-trail.a).normalized()
  var a=trail.a
  var owner=states.get('cell:'+str(trail.owner),{})
  if not owner.is_empty():a+=axis*minf(a.distance_to(trail.b)*0.4,float(owner.get('width',35))*0.4)
  var alpha=1.0-smoothstep(0.03,0.16,trail.age)
  canvas.draw_line(a,trail.b,Color('#d99263',alpha*0.35),5.0,true)
  canvas.draw_line(a,trail.b,Color('#fff0b8',alpha),1.8,true)
