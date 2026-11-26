extends RefCounted
const EVENTS={'damage':true,'virus_hit':true,'core_hit':true,'heal':true,'transfer':true,'pushed':true,'attack_fired':true,'cell_target':true,'cell_return':true,'bullet_split':true,'cell_split':true,'accelerated':true,'charge_generated':true,'generator_charged':true,'discharge':true,'charge_kill':true,'tagged':true,'protein_eaten':true,'generator_fed':true,'virus_fed':true,'produced':true,'blast_started':true,'cell_rest':true,'blood_lost':true,'core_protected':true,'virus_defeated':true,'virus_target':true,'virus_attachment':true,'merge':true,'purchase':true,'purchase_buff':true,'sell':true,'swap':true,'permanent_growth':true}
# Detectors read actor snapshots and normalized events; all memory is in engine states.
func add(e,s,f,code,ok,target='',point=Vector2.INF,targets=[],points=[]):
 if not s.allowed.has(code):return
 if not ok:s.conditions.erase(code);return
 if not s.conditions.has(code):s.conditions[code]=e.now
 f[code]={'time':s.conditions[code],'target':target,'targets':targets,'points':points,'point':e.point(target,s.last_p) if point==Vector2.INF else point}
func facts(e,a: Dictionary,s: Dictionary) -> Dictionary:
 var c: Dictionary=e.config;var b: Dictionary=a.body;var p: Vector2=b.p;var uid: String=a.uid;var f: Dictionary={}
 var actors: Dictionary=e.actors;var states: Dictionary=e.states
 var nearby=e.near(p,maxf(c.near,a.range));var enemies=[];var friends=[];var walls=[];var shooters=[];var injured=[];var bombs=[]
 var enemy='';var friend='';var enemy_d=INF;var friend_d=INF
 var need_injured=s.allowed.has(12);var need_bombs=s.allowed.has(5)
 for other in nearby:
  if other==uid:continue
  var n: Dictionary=actors[other];var q: Vector2=n.body.p;var distance: float=p.distance_squared_to(q)
  if n.is_virus:
   enemies.append(other)
   if distance<enemy_d:enemy_d=distance;enemy=other
  else:
   friends.append(other)
   if distance<friend_d:friend_d=distance;friend=other
   if n.is_wall:walls.append(other)
   if n.is_shooter:shooters.append(other)
   if need_injured and n.injured:injured.append(other)
   if need_bombs and n.critical_bomb and distance<=n.range*n.range:bombs.append(other)
 var core=b.get('visual_target','') if a.group=='virus' else ''
 if not core.begins_with('core:'):core=''
 if core=='' and (a.group=='virus' or s.allowed.has(15) or s.allowed.has(54)):core=e.closest(e.groups.core,p)
 var close_core=e.point(core,p+Vector2.ONE*c.near).distance_to(p)
 var linked=[];var stretched=''
 for link in e.links.get(uid,[]):
  linked.append(link.uid)
  if p.distance_to(e.point(link.uid,p))>link.rest*c.link_stretch:stretched=link.uid
 var mortar_child=''
 if s.allowed.has(78):
  for other in friends:
   if actors[other].key=='bomb' and actors[other].body.get('creator',-1)>=0:mortar_child=other;break
 var partner=e.closest(linked,p);var touched=e.contacts.get(uid,[]);var enemy_touch='';var friendly_touch=''
 for id in touched:
  if not actors.has(id):continue
  if actors[id].group=='virus':enemy_touch=id
  else:friendly_touch=id
  if id not in s.previous_contacts and actors[id].group!='virus' and a.group!='virus':s.contact_times.append(e.now)
 s.previous_contacts=touched.duplicate();s.contact_times=s.contact_times.filter(func(t):return e.now-t<=c.collision_window)
 var speed=s.velocity.length();var hp=b.get('hp',c.missing_hp_default);var hp_ratio=float(hp)/maxf(c.position_epsilon,b.get('max_hp',b.get('peak_hp',c.missing_hp_default)))
 var cursor=e.ui.get('cursor',Vector2.INF);var over=bool(e.ui.get('over_field',false));var hovered=e.ui.get('hover_uid','')==uid and over
 if not hovered:s.hover_since=e.now
 elif not s.has('hover_since'):s.hover_since=e.now
 var dwell=e.now-s.get('hover_since',e.now)
 var dragged=e.ui.get('drag_uid','')==uid
 if not dragged:s.drag_since=e.now
 var rotating=e.ui.get('rotating_uid','')==uid
 if rotating:s.rotation_total+=absf(wrapf(float(b.get('angle',0))-s.prev.get('angle',b.get('angle',0)),-PI,PI))
 else:s.rotation_total=0.0
 var incoming=e.inbound.get(uid,[]);var watching_shooters=[];var worried_watchers=[]
 for viewer in incoming:
  if not actors.has(viewer):continue
  if actors[viewer].behavior in ['shoot','sniper','mortar']:watching_shooters.append(viewer)
  if states[viewer].choice.get('emotion','')=='worried':worried_watchers.append(viewer)
 var pair=s.target if actors.has(s.target) and states[s.target].target==uid and a.key!='virus_avoider' and actors[s.target].key!='virus_avoider' else ''
 if pair!=s.pair:s.pair=pair;s.pair_since=e.now
 var pair_age=e.now-s.pair_since if pair!='' else 0.0
 var threat=(enemy!='' and a.group!='virus' and p.distance_to(e.point(enemy))<c.threat_radius) or (a.group=='virus' and core!='' and close_core<c.virus_threat_radius)
 f.threat=threat
 var food='';var food_point=p;var best=INF;var tag_point=p;var has_tag=false
 if a.key in ['hungry_bomb','generator','mint','accelerator','mortar','seeker_factory','tag_splitter','virus_hungry']:
  for particle in e.particles:
   if particle.get('life',0)<=0:continue
   var d=p.distance_squared_to(particle.p)
   if d<=maxf(a.range,c.near)*maxf(a.range,c.near):
    if particle.kind=='food' and d<best:best=d;food='food';food_point=particle.p
    if particle.kind=='tag':has_tag=true;tag_point=particle.p
 s.food_point=food_point if food!='' else Vector2.INF
 var work=''
 if b.has('presentation_target'):work=e.actor_id(int(b.presentation_target),'cell')
 if a.group=='virus':work=b.get('visual_target',core)
 elif a.is_shooter and e.now-s.get('shot_at',-INF)<c.event_fresh:work=s.get('shot_target','')
 if not actors.has(work):work=enemy if a.group!='virus' else core
 if a.is_shooter and actors.has(work):enemy=work
 if work=='':
  if not s.has('empty_since'):s.empty_since=e.now
 else:s.empty_since=e.now
 s.work=work;s.nearby=nearby
 var no_target_age=e.now-s.get('empty_since',e.now)
 var axis=Vector2.RIGHT.rotated(b.get('angle',0.0));var on_line=''
 if s.allowed.has(20) or s.allowed.has(21) or s.allowed.has(27):
  for id in enemies:
   var delta=e.point(id)-p
   if delta.dot(axis)>0 and absf(delta.cross(axis))<c.line_width:on_line=id;break
 if on_line!='':s.line_empty_since=e.now
 elif not s.has('line_empty_since'):s.line_empty_since=e.now
 var baseline=147 if a.group=='core' else 180 if a.group=='virus' else 102
 add(e,s,f,baseline,true,core if a.group=='virus' else partner,p,linked)
 if f.has(baseline):f[baseline].time=-INF
 if a.key=='orbiter':
  if not touched.is_empty():s.orbit_total=0.0
  else:s.orbit_total+=absf(wrapf(float(b.get('orbit',0))-s.prev.get('orbit',b.get('orbit',0)),-PI,PI))
 var same=[]
 if s.allowed.has(107):
  for other in friends:
   if actors[other].key==a.key and p.distance_to(e.point(other))<c.merge_radius:same.append(other)
 var catch_player=over and cursor.distance_to(p)<c.cursor_near and e.cursor_still>=c.cursor_still+fposmod(s.phase_seed,c.contagion_max)
 if catch_player:s.caught=true
 if e.now-e.cursor_jump_at>=c.caught_decay and e.cursor_still<c.cursor_still:s.caught=false
 var blocked=false
 if s.allowed.has(178) and core!='':
  for other in friends:
   if other==core:continue
   if Geometry2D.get_closest_point_to_segment(e.point(other),p,e.point(core)).distance_to(e.point(other))<actors[other].radius:blocked=true;break
 var previous_enemy=s.get('previous_enemy','')
 if previous_enemy!='' and enemy=='':add(e,s,f,98,true,previous_enemy,s.get('previous_enemy_p',p))
 s.previous_enemy=enemy;s.previous_enemy_p=e.point(enemy,p)
 var previous_shooters=s.get('previous_shooters',[])
 if s.allowed.has(167):add(e,s,f,167,not previous_shooters.is_empty() and shooters.is_empty(),e.closest(previous_shooters,p));s.previous_shooters=shooters.duplicate()
 if a.behavior=='wall':
  for other in enemies:
   var relative=(e.point(other)-p).rotated(-b.get('angle',0.0))
   var old=s.get('wall_sides',{}).get(other,relative)
   if old.y*relative.y<0 and absf(relative.x)<a.radius+c.near:add(e,s,f,23,true,other)
   if not s.has('wall_sides'):s.wall_sides={}
   s.wall_sides[other]=relative
  var prior=s.get('wall_touches',[])
  for other in prior:
   if other not in touched and actors.has(other) and e.point(other).distance_to(p)>s.get('wall_distances',{}).get(other,INF) and hp>=s.prev.get('hp',hp):add(e,s,f,26,true,other)
  s.wall_touches=touched.duplicate();s.wall_distances={}
  for other in touched:s.wall_distances[other]=e.point(other).distance_to(p)
 if s.allowed.has(192):
  for wall in walls:
   var old=s.prev.get('position',p)-e.point(wall)
   var current=p-e.point(wall)
   if old.dot(current)<0:add(e,s,f,192,true,wall)
 if a.group=='cell':
  if s.allowed.has(78):add(e,s,f,78,mortar_child!='',mortar_child)
  if s.allowed.has(103):add(e,s,f,103,not linked.is_empty(),partner,p,linked)
  if s.allowed.has(1):add(e,s,f,1,e.phase=='aftermath' and int(e.frame.losses.get('cells',0))+int(e.frame.losses.get('core',0))>0)
  if s.allowed.has(2):add(e,s,f,2,e.phase=='aftermath' and b.get('sale',1)>1)
  if s.allowed.has(3):add(e,s,f,3,e.phase=='aftermath' and b.get('radius_growth',0)>0)
  if s.allowed.has(5):add(e,s,f,5,not bombs.is_empty(),e.closest(bombs,p))
  if s.allowed.has(6):add(e,s,f,6,hp<=c.critical_hp and enemy_touch!='',enemy_touch)
  if s.allowed.has(7):add(e,s,f,7,hp_ratio<=c.low_hp and e.sim_elapsed>c.long_battle)
  if s.allowed.has(9):add(e,s,f,9,food!='','',food_point)
  if s.allowed.has(10):add(e,s,f,10,food!='','',food_point)
  if s.allowed.has(11):add(e,s,f,11,enemies.size()>=c.bomb_targets,enemy,p,enemies)
  if s.allowed.has(12):add(e,s,f,12,not injured.is_empty(),e.closest(injured,p))
  if s.allowed.has(14):add(e,s,f,14,enemy!='' and p.distance_to(e.point(enemy))<=a.radius*2,enemy)
  if s.allowed.has(15):add(e,s,f,15,enemy!='' and p.distance_to(e.point(enemy))<=a.radius*2,enemy,p,[enemy,core] if core!='' else [enemy])
  if s.allowed.has(16):add(e,s,f,16,enemy_touch!='',enemy_touch)
  if s.allowed.has(17):add(e,s,f,17,enemy!='' and p.distance_to(e.point(enemy))<=a.range,enemy)
  if s.allowed.has(18):add(e,s,f,18,enemy!='' and p.distance_to(e.point(enemy))<=a.range,enemy)
  if s.allowed.has(19):add(e,s,f,19,enemy!='' and p.distance_to(e.point(enemy))<=a.range,enemy)
  if s.allowed.has(20):add(e,s,f,20,on_line!='',on_line)
  if s.allowed.has(21):add(e,s,f,21,on_line!='',on_line)
  if s.allowed.has(24):add(e,s,f,24,enemy!='' and absf(e.point(enemy).length()-p.length())<c.orbit_crossing,enemy)
  if s.allowed.has(25):add(e,s,f,25,enemy!='' and b.get('charge',0)<=0,enemy)
  if s.allowed.has(27):add(e,s,f,27,enemy!='' and on_line=='' and e.now-s.line_empty_since>c.no_line_delay,enemy)
  if s.allowed.has(32):add(e,s,f,32,pair_age>c.pair_delay and pair.begins_with('virus:'),pair)
  if s.allowed.has(33):add(e,s,f,33,speed>c.velocity_min)
  if s.allowed.has(34):add(e,s,f,34,speed>c.velocity_min)
  if s.allowed.has(35):add(e,s,f,35,b.get('friendly_stun',0)>0,friendly_touch)
  if s.allowed.has(37):add(e,s,f,37,dragged and e.now-s.drag_since>c.drag_spiral)
  if s.allowed.has(40):add(e,s,f,40,dragged and e.now-s.drag_since>c.drag_spiral)
  if s.allowed.has(41):add(e,s,f,41,b.get('food',0)<a.get('recipe_food',c.recipe_bullet_default),'',food_point)
  if s.allowed.has(42):add(e,s,f,42,(b.get('food',0)<a.get('recipe_food',c.recipe_food_default) or b.get('bullet_food',0)<a.get('recipe_bullets',0)),'',food_point)
  if s.allowed.has(46):add(e,s,f,46,b.get('charge',0)<=0 and s.prev.get('charge',0)>0)
  if s.allowed.has(47):add(e,s,f,47,b.get('kills',0)>0 and a.get('interval',INF)<=c.minimum_interval,enemy,p,enemies)
  if s.allowed.has(48):add(e,s,f,48,enemy_touch!='' and actors[enemy_touch].body.get('tag',0)>0,enemy_touch)
  if s.allowed.has(49):add(e,s,f,49,b.get('tags',0)<=0 and s.prev.get('tags',0)>0)
  if s.allowed.has(51):add(e,s,f,51,worried_watchers.size()>=c.worried_watchers,'',p,worried_watchers)
  if s.allowed.has(52):add(e,s,f,52,enemy=='')
  if s.allowed.has(53):add(e,s,f,53,no_target_age>c.no_target_delay)
  if s.allowed.has(54):add(e,s,f,54,enemy=='',core)
  if s.allowed.has(57):add(e,s,f,57,enemy!='' and s.get('network_seen','')!=enemy,enemy)
  if s.allowed.has(67):add(e,s,f,67,work!='',work)
  if s.allowed.has(68):add(e,s,f,68,enemy_touch!='',enemy_touch)
  if s.allowed.has(71):add(e,s,f,71,pair!='' and pair.begins_with('core:'),pair)
  if s.allowed.has(72):add(e,s,f,72,s.orbit_total>=c.orbit_laps*TAU)
  if s.allowed.has(76):add(e,s,f,76,hp_ratio<=c.low_hp,partner)
  if s.allowed.has(79):add(e,s,f,79,has_tag,'',tag_point)
  if s.allowed.has(86):add(e,s,f,86,speed<c.velocity_min,friend)
  if s.allowed.has(90):add(e,s,f,90,s.contact_times.size()>=c.collision_count)
  if s.allowed.has(91):add(e,s,f,91,b.get('charge',0)<=0 and partner!='',partner)
  if s.allowed.has(97):add(e,s,f,97,friendly_touch!='' and speed<c.velocity_min,friendly_touch)
  if s.allowed.has(99):add(e,s,f,99,e.phase=='launch',partner)
  if s.allowed.has(100):add(e,s,f,100,e.phase=='launch' and e.frame.money>=c.carbon_rich)
  if s.allowed.has(101):add(e,s,f,101,e.phase=='win' and hovered)
  if s.allowed.has(107):add(e,s,f,107,e.ui.get('offer_key','')==a.key and not same.is_empty(),e.closest(same,p))
  if s.allowed.has(108):add(e,s,f,108,rotating)
  if s.allowed.has(110):add(e,s,f,110,s.rotation_total>=c.rotation_spiral)
  if s.allowed.has(111):add(e,s,f,111,e.ui.get('selected_uid','')==uid and e.ui.get('sell_hover',false))
  if s.allowed.has(113):add(e,s,f,113,e.ui.get('selected_uid','')==uid and e.ui.get('sell_hover',false) and b.get('sale',1)>1)
  if s.allowed.has(114):add(e,s,f,114,partner=='')
  if s.allowed.has(116):add(e,s,f,116,true)
  if s.allowed.has(117):add(e,s,f,117,e.now-e.last_action>c.idle_delay)
  if s.allowed.has(118):add(e,s,f,118,dragged)
  if s.allowed.has(119):add(e,s,f,119,e.ui.get('offer_key','')!='','',cursor)
  if s.allowed.has(120):add(e,s,f,120,e.frame.money<e.previous_money)
  if s.allowed.has(121):add(e,s,f,121,not friends.is_empty(),friend,p,friends)
  if s.allowed.has(126):add(e,s,f,126,pair_age>c.pair_blush and pair in linked,pair)
  if s.allowed.has(127):add(e,s,f,127,hovered and dwell>c.cursor_blush and e.ui.get('zoom',1)>=c.big_zoom)
  if s.allowed.has(128):add(e,s,f,128,hovered and dwell>c.cursor_dwell)
  if s.allowed.has(129):add(e,s,f,129,catch_player)
  if s.allowed.has(130):add(e,s,f,130,incoming.filter(func(id):return id in linked).size()>=c.worried_watchers,'',p,incoming)
  if s.allowed.has(131):add(e,s,f,131,s.caught and e.now-e.cursor_jump_at<c.caught_decay)
  if s.allowed.has(132):add(e,s,f,132,stretched!='',stretched)
 if a.group=='core':
  if s.allowed.has(133):add(e,s,f,133,e.phase=='aftermath' and e.frame.losses.get('core',0)>0,'',p,[],[s.grief_point])
  if s.allowed.has(134):add(e,s,f,134,e.phase=='aftermath' and e.frame.losses.get('core',0)==0 and e.frame.losses.get('cells',0)==0,'',p,linked)
  if s.allowed.has(135):add(e,s,f,135,pair!='' and actors[pair].key=='orbiter',pair)
  if s.allowed.has(136):add(e,s,f,136,enemy!='' and p.distance_to(e.point(enemy))<c.threat_radius,enemy)
  if s.allowed.has(137):add(e,s,f,137,enemy!='' and e.inbound.get(enemy,[]).filter(func(id):return actors[id].behavior in ['shoot','sniper']).is_empty(),friend)
  if s.allowed.has(143):add(e,s,f,143,enemy!='' and (actors[enemy].body.get('tag',0)>0 or actors[enemy].body.get('freeze',0)>0),enemy)
  if s.allowed.has(145):add(e,s,f,145,e.now-s.grief_at>=c.core_grief_delay and e.now-s.grief_at<c.core_grief_delay+c.durations.cry,enemy,s.grief_point)
  if s.allowed.has(146):add(e,s,f,146,e.phase=='win')
  if s.allowed.has(148):add(e,s,f,148,dragged)
  if s.allowed.has(149):add(e,s,f,149,e.ui.get('offer_key','')!='','',cursor)
  if s.allowed.has(150):add(e,s,f,150,pair_age>c.pair_blush,pair)
  if s.allowed.has(152):add(e,s,f,152,dragged and e.now-s.drag_since>c.drag_spiral)
  if s.allowed.has(153):add(e,s,f,153,hovered and dwell>c.cursor_blush and e.ui.get('zoom',1)>=c.big_zoom)
  if s.allowed.has(154):add(e,s,f,154,hovered and dwell>c.cursor_dwell)
  if s.allowed.has(155):add(e,s,f,155,catch_player)
  if s.allowed.has(156):add(e,s,f,156,s.caught and e.now-e.cursor_jump_at<c.caught_decay)
 if a.group=='virus':
  if s.allowed.has(157):add(e,s,f,157,hp<=c.critical_hp,friend)
  if s.allowed.has(158):add(e,s,f,158,food!='','',food_point)
  if s.allowed.has(159):add(e,s,f,159,core!='' and close_core<c.virus_threat_radius,core)
  if s.allowed.has(160):add(e,s,f,160,b.get('jump',false),friend)
  if s.allowed.has(161):add(e,s,f,161,enemies.size()>=c.swarm_count,core,p,enemies)
  if s.allowed.has(163):add(e,s,f,163,true)
  if s.allowed.has(166):add(e,s,f,166,e.now-s.born<c.event_fresh and over and cursor.distance_to(p)<c.cursor_near)
  if s.allowed.has(168):add(e,s,f,168,pair_age>c.pair_delay and pair in shooters,pair)
  if s.allowed.has(169):add(e,s,f,169,true,core)
  if s.allowed.has(170):add(e,s,f,170,friends.size()>=c.squeezed_count and touched.size()>=c.squeezed_count,friend,p,friends)
  if s.allowed.has(171):add(e,s,f,171,e.ui.get('clicked_uid','')==uid)
  if s.allowed.has(172):add(e,s,f,172,b.get('visual_avoiding',false),friend)
  if s.allowed.has(174):add(e,s,f,174,friend!='' and p.distance_to(e.point(friend))<c.push_radius,friend,p,friends)
  if s.allowed.has(175):add(e,s,f,175,friendly_touch!='',friendly_touch)
  if s.allowed.has(176):add(e,s,f,176,hovered and dwell>c.cursor_blush and e.ui.get('zoom',1)>=c.big_zoom)
  if s.allowed.has(177):add(e,s,f,177,hovered and dwell>c.cursor_dwell)
  if s.allowed.has(178):add(e,s,f,178,core!='' and not blocked,core)
  if s.allowed.has(179):add(e,s,f,179,watching_shooters.size()>=c.look_pressure,'',p,watching_shooters)
  if s.allowed.has(181):add(e,s,f,181,s.prev.get('avoiding',false) and not b.get('visual_avoiding',false),core)
  if s.allowed.has(182):add(e,s,f,182,e.groups.virus.size()==1 and not e.dead_viruses.is_empty(),'',p,[],e.dead_viruses)
  if s.allowed.has(184):add(e,s,f,184,b.get('tag',0)>0 or b.get('freeze',0)>0)
  if s.allowed.has(185):add(e,s,f,185,not b.get('jump',false) and b.get('jump_cooldown',1)<c.hold_min)
  if s.allowed.has(187):add(e,s,f,187,friend!='',friend)
  if s.allowed.has(188):add(e,s,f,188,s.prev.get('jump',false) and not b.get('jump',false))
  if s.allowed.has(189):add(e,s,f,189,s.prev.get('jump',false) and not b.get('jump',false) and not walls.is_empty(),e.closest(walls,p))
  if s.allowed.has(191):add(e,s,f,191,b.get('lived',0)>b.get('lifespan',INF)*c.lifetime_fraction)
 s.network_seen=enemy
 for code in [103,116,163,169]:
  if f.has(code):f[code].time=-INF
 # One-hop laughter: a source serial is consumed once; received laughs never relay.
 for neighbor in linked:
  if not states.has(neighbor):continue
  var ns: Dictionary=states[neighbor]
  if ns.choice.get('emotion','')=='laugh' and int(ns.choice.get('case',0))!=77 and int(ns.serial)!=s.counted_laugh:
   if s.allowed.has(77):add(e,s,f,77,true,neighbor);s.counted_laugh=ns.serial;break
 # Idle-only gaze contagion, queued nearest first by distance-based delay.
 if (s.allowed.has(104) or s.allowed.has(129) or s.allowed.has(155)) and (s.choice.is_empty() or int(s.choice.get('case',0)) in [102,103,104,147,180]):
  var votes={}
  for neighbor in nearby:
   if neighbor==uid:continue
   var ns: Dictionary=states[neighbor];var key=ns.target if ns.target!='' else 'lens' if ns.choice.get('direction',0)==6 else ''
   if key=='':continue
   if not votes.has(key):votes[key]=[]
   votes[key].append(neighbor)
  for target in votes:
   if votes[target].size()<c.contagion_count:continue
   if s.contagion_target!=target:s.contagion_target=target;s.contagion_at=e.now+lerpf(c.contagion_min,c.contagion_max,p.distance_to(e.point(votes[target][0],p))/c.contagion_radius)
   if e.now>=s.contagion_at:
    if target=='lens':add(e,s,f,155 if a.group=='core' else 129,true)
    else:add(e,s,f,104,true,target,e.point(target))
   break
 return f
func emit_codes(e,uid,codes,target='',p=Vector2.ZERO,targets=[]):
 for code in codes:e.emit(uid,code,{'target':target,'point':p,'targets':targets})
func event(e,event_data):
 var name=event_data.event
 if not EVENTS.has(name):return
 var d=event_data.data;var c=e.config
 var id=int(d.get('id',d.get('source',-1)));var uid=e.actor_id(id)
 if name.begins_with('virus_') or name in ['tagged','tag_ended','thawed']:uid='virus:'+str(id)
 if name in ['blood_lost','core_protected','core_hit']:uid='core:'+str(id)
 var p=d.get('p',e.point(uid));var source=e.actor_id(int(d.get('source_id',d.get('owner',-1))))
 var target=e.actor_id(int(d.get('target_id',d.get('target',-1)))) if d.get('target',-1) is int or d.has('target_id') else ''
 var q=d.get('from',e.point(source,p));var nearby=e.near(p,c.event_radius) if name in ['pushed','protein_eaten','generator_fed','blast_started','cell_rest','virus_defeated','merge','purchase','sell'] else []
 match name:
  'damage','virus_hit','core_hit':
   emit_codes(e,uid,[81 if name=='damage' else 193 if name=='virus_hit' else 142],source,q)
   if name=='virus_hit' and d.get('cause','')=='blast':
    for parent in e.states:
     if e.states[parent].children.has(source):
      var ps=e.states[parent]
      if not ps.has('blast_hits'):ps.blast_hits={}
      if not ps.blast_hits.has(source):ps.blast_hits[source]=[]
      if uid not in ps.blast_hits[source]:ps.blast_hits[source].append(uid)
      if ps.blast_hits[source].size()>=c.bomb_targets:emit_codes(e,parent,[44],uid,p,ps.blast_hits[source])
   if e.states.has(uid):
    var s=e.states[uid];s.last_hit=e.now;s.last_shooter=source
    if name=='virus_hit' and e.actors.get(uid,{}).get('key','')=='virus_wave':emit_codes(e,uid,[194],source,q)
    if name=='damage' and s.get('pushed_by','')!='' and e.now-s.get('pushed_when',-INF)<c.event_fresh:emit_codes(e,s.pushed_by,[89],uid,p)
    if s.pair!='':emit_codes(e,uid,[186 if name=='virus_hit' else 66],s.pair,e.point(s.pair))
   if name=='damage':
    emit_codes(e,uid,[65],source,q)
    if d.get('source_cause','')=='blast':emit_codes(e,uid,[58],source,q)
  'heal':
   emit_codes(e,uid,[83],source,q)
   emit_codes(e,source,[38,70],uid,p)
   if float(d.get('hp',0))-float(d.get('amount',0))<=c.critical_hp:emit_codes(e,source,[30],uid,p)
  'transfer':
   var path=d.get('path',[])
   if not path.is_empty():
    var provider=e.actor_id(path[-1]);var recipient=e.actor_id(path[0])
    emit_codes(e,provider,[59],recipient,e.point(recipient));emit_codes(e,recipient,[4],provider,e.point(provider))
    if d.get('lethal_prevented',false):emit_codes(e,provider,[60],recipient,e.point(recipient))
  'pushed':
   if d.get('kind','')=='virus':uid='virus:'+str(id)
   emit_codes(e,uid,[183 if uid.begins_with('virus:') else 84],source,q)
   if e.states.has(uid):
    var s=e.states[uid];s.pushed_by=source;s.pushed_when=e.now;s.push_times.append(e.now);s.push_times=s.push_times.filter(func(t):return e.now-t<c.collision_window)
    if s.push_times.size()>=c.repeat_push_count:emit_codes(e,uid,[8],source,q)
   for other in nearby:
    if other!=uid:emit_codes(e,other,[85],uid,p)
   if e.states.has(source):
    var s=e.states[source]
    if not s.has('pushed_targets') or e.now-s.get('pushed_at',-INF)>c.event_fresh:s.pushed_targets=[]
    s.pushed_at=e.now;s.pushed_targets.append(uid)
    if s.pushed_targets.size()>=c.bomb_targets:emit_codes(e,source,[55],uid,p,s.pushed_targets)
  'attack_fired':
   if e.states.has(uid):e.states[uid].shot_target=target;e.states[uid].shot_at=e.now
   emit_codes(e,uid,[31,74],target,e.point(target,p))
  'cell_target':emit_codes(e,uid,[67],target,d.get('target',p))
  'cell_return':emit_codes(e,uid,[28],'',p)
  'bullet_split':emit_codes(e,uid,[62],source,q)
  'cell_split':emit_codes(e,uid,[73],'',p)
  'accelerated':emit_codes(e,uid,[29],target,d.get('q',p))
  'charge_generated':emit_codes(e,uid,[36,63,64],target,e.point(target,p))
  'generator_charged':emit_codes(e,uid,[63],source,q)
  'discharge':
   uid=e.actor_id(d.get('source',-1));emit_codes(e,uid,[82],target,e.point(target,p))
   if d.get('path',[]).size()>=c.lightning_links:
    for other in e.near(e.point(uid),c.event_radius):emit_codes(e,other,[75],uid,e.point(uid))
  'charge_kill':emit_codes(e,uid,[80],target,e.point(target,p))
  'tagged':
   source=e.actor_id(d.get('owner',-1));emit_codes(e,source,[22,39],uid,p)
  'protein_eaten','generator_fed':
   if d.get('kind','')=='bullet':emit_codes(e,uid,[62],source,q)
   if e.actors.has(uid):
    var key=e.actors[uid].key
    if key=='mint' and int(d.get('food',0))==0:emit_codes(e,uid,[87],'',p)
    if key=='hungry_bomb':emit_codes(e,uid,[88],'',p)
    for other in nearby:
     if e.actors[other].key=='virus_hungry' and e.states[other].get('food_point',Vector2.INF).distance_to(q)<c.contact_gap:emit_codes(e,other,[173],uid,p)
  'virus_fed':emit_codes(e,uid,[195],'',q)
  'produced':
   target=e.actor_id(d.get('child',-1));emit_codes(e,uid,[43,69],target,p)
   if e.states.has(uid):e.states[uid].children[target]=e.now
  'blast_started':
   uid=e.actor_id(d.get('owner',-1));var affected=[]
   for other in e.near(p,d.get('reach',c.event_radius)):
    if e.actors[other].group=='virus':affected.append(other)
   for other in nearby:
    if e.actors[other].group=='core':emit_codes(e,other,[151,152],'',p)
    elif e.states[other].last_hit<e.now:emit_codes(e,other,[162 if e.actors[other].group=='virus' else 13],'',p)
  'cell_rest':
   emit_codes(e,uid,[50],'',p)
   for other in nearby:
    if e.links.get(other,[]).any(func(link):return link.uid==uid):emit_codes(e,other,[61],'',p)
   source=e.actor_id(d.get('source_id',-1))
   if source.begins_with('virus:'):emit_codes(e,source,[196],'',p)
   for parent in e.states:
    if e.states[parent].children.has(uid) and e.now-e.states[parent].children[uid]<c.early_child_death:emit_codes(e,parent,[45],'',p)
  'blood_lost':
   for neighbor in d.get('hand_neighbors',[]):
    var core='core:'+str(neighbor);emit_codes(e,core,[141],'',p)
    if e.states.has(core):e.states[core].grief_at=e.now;e.states[core].grief_point=p
  'core_protected':emit_codes(e,uid,[144],source,q)
  'virus_defeated':
   e.dead_viruses.append(p)
   var owner=e.actor_id(int(d.get('owner',-1)))
   emit_codes(e,owner,[94 if d.get('cause','')=='bullet' else 95,92],'',p)
   if e.ui.get('over_field',false) and p.distance_to(e.ui.get('cursor',Vector2.INF))<c.cursor_near:emit_codes(e,owner,[93],'',p)
   for other in nearby:
    var a=e.actors[other]
    if a.group=='core' and p.distance_to(a.body.p)<c.core_kill_radius:emit_codes(e,other,[139],'',p)
    if a.group=='core' and d.get('cause','')=='expiry':emit_codes(e,other,[138],'',p)
    if a.behavior=='wall' and uid in e.states[other].previous_contacts:emit_codes(e,other,[96],'',p)
    if a.key=='virus_swarmer' and a.body.get('host',-1)==id:emit_codes(e,other,[197],'',p)
    if e.states[other].target==uid and other!=owner:emit_codes(e,other,[198 if a.group=='virus' else 98],'',p)
  'virus_target':emit_codes(e,uid,[164],d.get('target_uid',target),d.get('target',p))
  'virus_attachment':
   target='virus:'+str(d.get('host',-1))
   if d.get('host',-1)>=0:emit_codes(e,uid,[190],target,e.point(target,p))
  'merge':
   emit_codes(e,uid,[125],'',p)
   if d.get('rank',1)>=3:
    for other in nearby:emit_codes(e,other,[151 if e.actors[other].group=='core' else 124],'',p)
  'purchase':
   uid=e.actor_id(d.get('id',-1));p=d.get('p',e.point(uid))
   for other in e.near(p,c.event_radius):
    if other!=uid:emit_codes(e,other,[122],uid,p)
  'purchase_buff':
   emit_codes(e,uid,[123,112],source,q)
   if d.get('source_id',-1)>=0:emit_codes(e,source,[106],uid,p)
  'sell':
   p=d.get('p',Vector2.ZERO)
   for other in e.near(p,c.event_radius):emit_codes(e,other,[109],'',p)
  'swap':
   var a=e.actor_id(d.get('a',-1));var b=e.actor_id(d.get('b',-1))
   emit_codes(e,a,[115,105],b,d.get('q',p));emit_codes(e,b,[105],a,p)
  'permanent_growth':emit_codes(e,uid,[3],'',p)
