extends RefCounted
# Portable attention engine. Input actors are read-only; output is renderer-neutral.
var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://data/lookat.json'))
var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://data/lookat_cases.json')).characters
var rules=preload('res://scripts/lookat/emotion_rules.gd').new(config,catalog)
var detectors=preload('res://scripts/lookat/detectors.gd').new()
var states: Dictionary={}
var actors: Dictionary={}
var grid: Dictionary={}
var groups: Dictionary={'cell':[],'core':[],'virus':[]}
var links: Dictionary={}
var contacts: Dictionary={}
var particles=[]
var rng=RandomNumberGenerator.new()
var now=0.0
var sim_elapsed=0.0
var phase='shop'
var ui: Dictionary={}
var frame: Dictionary={}
var cursor_last=Vector2.INF
var cursor_still=0.0
var cursor_jump_at=-INF
var last_action=0.0
var rare_origin=''
var first_virus=false
var dead_viruses=[]
var inbound: Dictionary={}
var phase_at=0.0
var previous_money=0
var ui_previous={}
var event_seq=0
var facts_us=0
var rules_us=0
var phase_cases: Dictionary={}
var duels: Dictionary={}
var jump_origins: Dictionary={}
func _init():
 for key in catalog:
  phase_cases[key]={}
  for row in catalog[key]:
   for label in row.phases:
    if not phase_cases[key].has(label):phase_cases[key][label]={}
    phase_cases[key][label][int(row.case)]=true
func reset(seed_value,round_number):
 duels.clear();jump_origins.clear()
 states.clear();actors.clear();grid.clear();inbound.clear();links.clear();contacts.clear();dead_viruses.clear()
 now=0;sim_elapsed=0;first_virus=false;cursor_last=Vector2.INF;cursor_still=0;cursor_jump_at=-INF;last_action=0;phase_at=0;phase="shop";previous_money=0;ui={};frame={}
 rng.seed=seed_value*1000003+round_number*9176
 rules.rare_until=0;rules.serial=0;event_seq=0;ui_previous={}
func sample(list,new_links,new_contacts,new_particles):
 actors={};grid={};groups={'cell':[],'core':[],'virus':[]};links=new_links;contacts=new_contacts;particles=new_particles
 for actor in list:
  actor.is_virus=actor.group=='virus';actor.is_wall=actor.behavior=='wall';actor.is_shooter=actor.behavior in ['shoot','sniper','mortar'];actor.injured=actor.body.get('hp',1)<=actor.body.get('max_hp',1)*config.heal_low_hp;actor.critical_bomb=actor.key in ['bomb','hungry_bomb','survivor_bomb'] and actor.body.get('hp',INF)<=config.critical_hp
  var uid=actor.uid;actors[uid]=actor;groups[actor.group].append(uid)
  var tile=Vector2i(floori(actor.body.p.x/config.grid_size),floori(actor.body.p.y/config.grid_size))
  if not grid.has(tile):grid[tile]=[]
  grid[tile].append(uid)
  if not states.has(uid):
   states[uid]={'choice':{},'cooldowns':{},'seen':{},'triggers':{},'until':0.0,'chosen_at':-INF,'choice_fact_time':-INF,'target':'','targets':[],'points':[],'point':actor.body.p,'next':now+float(abs(uid.hash())%1000)/1000.0/config.hz,'look':Vector2.RIGHT,'lens':0.0,'serial':0,'born':now,'prev':{},'conditions':{},'contact_times':[],'push_times':[],'pair_since':now,'pair':'','last_p':actor.body.p,'velocity':Vector2.ZERO,'blink_at':-INF,'phase_seed':rng.randf()*TAU,'wander':actor.body.p,'wander_until':0.0,'rotation_total':0.0,'drag_since':now,'grief_at':-INF,'grief_point':actor.body.p,'orbit_total':0.0,'no_target_since':now,'last_sample':now,'previous_contacts':[],'caught':false,'contagion_at':INF,'contagion_target':'','contagion_point':actor.body.p,'counted_laugh':-1,'event_target':'','event_point':actor.body.p,'event_at':-INF,'last_shooter':'','children':{},'last_hit':-INF}
   states[uid].registered=rules.index.get(actor.key,{})
   states[uid].allowed={}
   for row in catalog.get(actor.key,[]):states[uid].allowed[int(row.case)]=true
   if actor.group=='virus':
    emit(uid,165,{'point':actor.body.p})
    if not first_virus:
     first_virus=true
     for other in near(actor.body.p,config.event_radius):
      if actors[other].group!='virus':emit(other,140 if actors[other].group=='core' else 56,{'target':uid,'point':actor.body.p})
 for uid in states.keys():
  if not actors.has(uid) and now-states[uid].get('last_seen',now)>config.event_fresh:states.erase(uid)
 for uid in actors:states[uid].last_seen=now
func near(point: Vector2,radius: float) -> Array:
 var result: Array=[];var radius_squared: float=radius*radius;var low=Vector2i(floori((point.x-radius)/config.grid_size),floori((point.y-radius)/config.grid_size));var high=Vector2i(floori((point.x+radius)/config.grid_size),floori((point.y+radius)/config.grid_size))
 for y in range(low.y,high.y+1):
  for x in range(low.x,high.x+1):
   for uid in grid.get(Vector2i(x,y),[]):
    var position: Vector2=actors[uid].body.p
    if position.distance_squared_to(point)<=radius_squared:result.append(uid)
 return result
func closest(ids: Array,point: Vector2) -> String:
 var result: String='';var best: float=INF
 for uid in ids:
  if not actors.has(uid):continue
  var position: Vector2=actors[uid].body.p
  var d: float=position.distance_squared_to(point)
  if d<best:best=d;result=uid
 return result
func emit(uid,code,detail={}):
 if not states.has(uid) or not states[uid].registered.has(code):return
 var fact=detail.duplicate();fact.time=now;fact.token=event_seq
 states[uid].triggers[code]=fact
 if detail.has('target'):states[uid].event_target=detail.target
 if detail.has('point'):states[uid].event_point=detail.point
 states[uid].event_at=now
func has_actor(uid):return actors.has(uid)
func point(uid: String,fallback: Vector2=Vector2.ZERO) -> Vector2:return actors[uid].body.p if actors.has(uid) else fallback
func actor_id(id,kind='cell'):
 if kind=='core':return 'core:'+str(id)
 if int(id)<-1:return 'core:'+str(-2-int(id))
 var uid='cell:'+str(id)
 return uid if actors.has(uid) else 'virus:'+str(id)
func update(dt,input,events,snapshot):
 if dt<=0:return
 now+=dt;ui=input;frame=snapshot;sim_elapsed=snapshot.elapsed
 var next_phase=snapshot.phase
 if snapshot.staging=='launch':next_phase='launch'
 elif snapshot.staging in ['aftermath','warning'] or next_phase=='recap':next_phase='aftermath'
 if next_phase!=phase:phase=next_phase;phase_at=now
 update_cursor(dt)
 if phase=='shop' and int(frame.money)<previous_money:
  for uid in actors:
   if actors[uid].key=='greed_wall':emit(uid,120)
 var clicked=ui.get('clicked_uid','')
 if states.has(clicked):emit(clicked,171);states[clicked].next=now
 for event in events:
  event_seq=int(event.get('seq',event_seq+1));detectors.event(self,event)
 inbound.clear()
 for uid in actors:
  var s=states[uid]
  if actors.has(s.target):
   if not inbound.has(s.target):inbound[s.target]=[]
   inbound[s.target].append(uid)
 for uid in actors:
  var s=states[uid]
  if now<s.next:continue
  s.next=now+1.0/config.hz;s.output_next=0.0
  var a=actors[uid]
  var step=maxf(config.position_epsilon,now-s.last_sample)
  s.velocity=(a.body.p-s.last_p)/step;s.last_p=a.body.p;s.last_sample=now
  var stamp=Time.get_ticks_usec()
  s.allowed=phase_cases.get(a.key,{}).get(phase,{})
  var facts=detectors.facts(self,a,s)
  if s.has('duel_pending') and now>=s.duel_pending.after and (s.choice.get('emotion','')!='hurt' or now>=s.until):
   var pending=s.duel_pending;s.erase('duel_pending')
   emit(uid,pending.code,{'target':pending.target,'point':pending.point})
  facts_us+=Time.get_ticks_usec()-stamp
  for code in s.triggers.keys():
   var fact=s.triggers[code]
   if now-fact.time<=(config.durations.hurt if code in [81,142,193] else config.event_fresh):facts[code]=fact
   else:s.triggers.erase(code)
  var old=s.target;var oldlook=s.look
  stamp=Time.get_ticks_usec()
  var chosen=rules.choose(a,s,facts,phase,float(ui.get('speed',1)),now,rng)
  rules_us+=Time.get_ticks_usec()-stamp
  if chosen.is_empty():s.choice={};default_target(a,s)
  elif int(chosen.case) in [102,103,116,147,163,169,180]:default_target(a,s)
  if old!=s.target:
   var direction=point(s.target,s.point)-a.body.p
   if direction.length_squared()>config.position_epsilon and absf(oldlook.angle_to(direction))>config.saccade_angle:s.blink_at=now
  s.prev={'hp':a.body.get('hp',config.missing_hp_default),'charge':a.body.get('charge',0),'jump':a.body.get('jump',false),'host':a.body.get('host',-1),'avoiding':a.body.get('visual_avoiding',false),'food':a.body.get('food',0),'tags':a.body.get('tags',0),'angle':a.body.get('angle',0.0),'sale':a.body.get('sale',0),'position':a.body.p,'orbit':a.body.get('orbit',0.0)}
 ui_previous=ui.duplicate();previous_money=int(frame.money)
func update_cursor(dt):
 var p=ui.get('cursor',Vector2.INF)
 if not ui.get('over_field',false) or p==Vector2.INF:cursor_still=0;cursor_last=p;return
 var distance=p.distance_to(cursor_last) if cursor_last!=Vector2.INF else INF
 if distance<=config.cursor_slop:cursor_still+=dt
 else:
  if distance/dt>config.cursor_jolt and cursor_still>=config.cursor_still:cursor_jump_at=now
  cursor_still=0;last_action=now
 cursor_last=p
 if ui.get('drag_uid','')!='' or ui.get('rotating_uid','')!='' or ui.get('offer_key','')!='':last_action=now
func default_target(a,s):
 if now<s.wander_until and (s.get('default_target','')=='' or actors.has(s.default_target)):
  s.target=s.get('default_target','');s.point=s.get('default_point',a.body.p);s.targets=[];return
 s.wander_until=now+rng.randf_range(config.hold_min,config.hold_max)
 var candidates=[]
 for uid in s.get('nearby',[]):
  if uid==a.uid:continue
  var other=actors[uid]
  if other.group=='virus' and a.group!='virus':candidates.append({'target':uid,'point':other.body.p,'weight':config.weights.threat})
 var work=s.get('work','')
 if actors.has(work):candidates.append({'target':work,'point':point(work),'weight':config.weights.work})
 if now-s.event_at<config.event_fresh:candidates.append({'target':s.event_target,'point':s.event_point,'weight':config.weights.event})
 for link in links.get(a.uid,[]):
  if actors.has(link.uid):candidates.append({'target':link.uid,'point':point(link.uid),'weight':config.weights.bond})
 if phase=='shop' and ui.get('over_field',false) and cursor_still>=config.cursor_still:candidates.append({'target':'','point':ui.cursor,'weight':config.weights.cursor})
 var best=config.weights.wander;var target='';var pos=a.body.p+Vector2.from_angle(rng.randf()*TAU)*config.wander_radius
 for candidate in candidates:
  var score=candidate.weight/(1+a.body.p.distance_to(candidate.point)/config.distance_scale)
  if candidate.target!='' and candidate.target==s.get('default_target',''):score*=1+config.hold_bonus
  if score>best:best=score;target=candidate.target;pos=candidate.point
 s.default_target=target;s.default_point=pos;s.target=target;s.point=pos;s.targets=[]
func output(uid):
 if not states.has(uid) or not actors.has(uid):return {}
 var s: Dictionary=states[uid]
 var direction=int(s.choice.get('direction',0))
 if now>=s.get('output_next',0.0) or direction in [3,10,14,19]:
  s.output_cache=compute_output(uid);s.output_next=now+1.0/config.hz
 var result: Dictionary=s.output_cache
 result.age=now-s.chosen_at;result.blink_age=now-s.blink_at
 if config.reactions.has(result.emotion):
  var times=config.reactions[result.emotion];var age=result.age
  result.reaction_mix=smoothstep(0,times[0],age)*(1-smoothstep(times[0]+times[1],times[0]+times[1]+times[2],age))
 return result
func compute_output(uid):
 if not states.has(uid) or not actors.has(uid):return {}
 var s=states[uid];var a=actors[uid];var choice=s.choice
 var direction=0 if int(choice.get('case',0)) in [102,103,116,147,163,169,180] else int(choice.get('direction',0));var emotion=choice.get('emotion','calm');var smoothing=config.default_smoothing
 var target=s.target;var p=s.point
 if not s.targets.is_empty():
  var interval=config.target_switch_min+fposmod(s.phase_seed,config.target_switch_max-config.target_switch_min)
  var index=mini(1,int((now-s.chosen_at)/interval)) if direction==1 else int((now-s.chosen_at)/interval)%s.targets.size()
  target=s.targets[mini(index,s.targets.size()-1)]
 if direction in [2,18]:
  if not s.points.is_empty():p=s.points[int((now-s.chosen_at)/config.target_switch_min)%s.points.size()]
 else:p=point(target,p)
 var look=p-a.body.p;var lens=0.0
 match direction:
  3:smoothing=config.tracking_smoothing
  4:look=s.velocity if s.velocity.length()>=config.velocity_min else s.look;smoothing=config.velocity_smoothing
  5:smoothing=config.social_smoothing
  6:lens=1.0;smoothing=config.social_smoothing
  7:look=a.body.p-ui.get('cursor',a.body.p);smoothing=config.tracking_smoothing
  8:look=s.look if now-s.chosen_at<config.durations.hurt else look;smoothing=config.tracking_smoothing
  9:look=Vector2(-1 if abs(uid.hash())%2 else 1,-1);smoothing=config.slow_smoothing
  10:look=ui.get('cursor',a.body.p)-a.body.p;smoothing=config.cursor_smoothing
  12:look=s.look
  13,18:smoothing=config.cursor_smoothing
  14:look=Vector2.RIGHT.rotated(a.body.get('angle',0.0)+sin(now*TAU/config.arc_period+s.phase_seed)*config.arc_angle);smoothing=config.slow_smoothing
  15:look=Vector2.RIGHT.rotated(a.body.get('angle',0.0))
  16,17,23:look=Vector2.DOWN;smoothing=config.social_smoothing
  19:look=Vector2.from_angle(s.phase_seed+sin(now*config.wander_speed)*config.arc_angle);smoothing=config.wander_smoothing
  21:look=(-look).rotated(config.avoid_angle*(-1 if abs(uid.hash())%2 else 1))
  22:look=s.velocity*config.path_lookahead;smoothing=config.cursor_smoothing
 if look.length_squared()>config.position_epsilon:s.look=look.normalized()
 var reaction_mix=1.0;var return_emotion=s.get('return_emotion','calm')
 if config.reactions.has(emotion):
  var times=config.reactions[emotion];var age=now-s.chosen_at
  reaction_mix=smoothstep(0,times[0],age)*(1-smoothstep(times[0]+times[1],times[0]+times[1]+times[2],age))
 return {'reaction_mix':reaction_mix,'return_emotion':return_emotion,'look':s.look,'lens':lens,'smoothing':smoothing,'emotion':emotion,'serial':s.serial,'case':int(choice.get('case',0)),'age':now-s.chosen_at,'blink_age':now-s.blink_at,'target':target}
