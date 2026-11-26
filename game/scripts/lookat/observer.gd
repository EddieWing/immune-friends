extends RefCounted
# Read-only adapter: all state below belongs to presentation, never to sim.
var actors=[]
var links={}
var contacts={}
var by_uid={}
var sample_age=INF
var cursor=0
var observed
var revision=-1
var engine=preload('res://scripts/lookat/engine.gd').new()
var last_us=0
var enabled=true
func update(sim,delta,ui={}):
 if not enabled:return
 var started=Time.get_ticks_usec()
 var fresh=sim!=observed or revision!=sim.presentation_revision or sim.elapsed<engine.sim_elapsed
 if fresh:
  observed=sim;revision=sim.presentation_revision;cursor=sim.event_sequence;sample_age=INF
  engine.reset(int(sim.seed_value),int(sim.round_no))
 var paused=bool(ui.get('paused',false))
 var dt=0.0 if paused else maxf(0,delta)
 sample_age+=dt
 if sample_age>=1.0/engine.config.hz:
  sample_age=0;actors=[];by_uid={};links={};contacts={}
  for group in [sim.cells,sim.blood,sim.viruses]:
   for body in group:
    if not body.alive:continue
    var uid=uid_of(body);var key='virus_'+str(body.type) if body.has('type') else body.get('key','core')
    var spec=sim.catalog.get(key,{})
    var actor={'uid':uid,'key':key,'body':body,'group':'virus' if body.has('type') else 'core' if not body.has('key') else 'cell','range':sim.range_of(body) if body.has('key') else engine.config.near,'radius':sim.physics.radius(body),'behavior':spec.get('behavior',''),'no_mouth':key in ['turret','sniper','cannon','bullet_wall','impact_wall','mortar','gatling','seeker_factory','virus_hungry']}
    if body.has('key'):
     actor.interval=sim.interval_of(body) if key=='gatling' else 0.0
     actor.recipe_food=sim.constant_of(body,'consume',2) if key=='accelerator' else sim.constant_of(body,'consume',4) if key=='mortar' else sim.constant_of(body,'capsid',1) if key=='seeker_factory' else 0.0
     actor.recipe_bullets=sim.constant_of(body,'bullet',2) if key=='seeker_factory' else 0.0
    actors.append(actor);by_uid[uid]=actor
  for link in sim.links:
   var a=endpoint(link.a);var b=endpoint(link.b)
   if by_uid.has(a) and by_uid.has(b):
    if not links.has(a):links[a]=[]
    if not links.has(b):links[b]=[]
    links[a].append({'uid':b,'rest':link.get('rest',engine.config.near)});links[b].append({'uid':a,'rest':link.get('rest',engine.config.near)})
  for link in sim.blood_links:
   var a='core:'+str(sim.blood[link.a].id);var b='core:'+str(sim.blood[link.b].id)
   if not by_uid.has(a) or not by_uid.has(b):continue
   if not links.has(a):links[a]=[]
   if not links.has(b):links[b]=[]
   links[a].append({'uid':b,'rest':link.get('rest',engine.config.near)});links[b].append({'uid':a,'rest':link.get('rest',engine.config.near)})
  for pair in sim.physics.contacts:
   var a=endpoint(pair.x);var b=endpoint(pair.y)
   if not contacts.has(a):contacts[a]=[]
   if not contacts.has(b):contacts[b]=[]
   contacts[a].append(b);contacts[b].append(a)
  engine.sample(actors,links,contacts,sim.particles)
 var events=sim.events_since(cursor)
 engine.update(dt,ui,events,{'phase':sim.phase,'staging':ui.get('staging',''),'elapsed':sim.elapsed,'money':sim.money,'losses':sim.round_losses,'round':sim.round_no})
 cursor=sim.event_sequence
 last_us=Time.get_ticks_usec()-started
func output(uid):return engine.output(uid)
static func uid_of(body):return ('virus:' if body.has('type') else 'cell:' if body.has('key') else 'core:')+str(body.id)
func endpoint(id):
 if int(id)<-1:return 'core:'+str(-2-int(id))
 return 'cell:'+str(id) if by_uid.has('cell:'+str(id)) else 'virus:'+str(id)
