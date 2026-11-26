extends SceneTree
var failures=0
func check(ok,label):
 print(('PASS: ' if ok else 'FAIL: ')+label)
 if not ok:failures+=1
func actor(uid,key,p,group='cell',behavior='wall'):
 var body={'p':p,'hp':10.0,'max_hp':10.0,'angle':0.0,'alive':true,'jump':false}
 return {'uid':uid,'key':key,'body':body,'group':group,'behavior':behavior,'range':150.0,'radius':10.0,'no_mouth':false,'wall_half':Vector2(43,13)}
func engine(actors,phase='battle'):
 var e=load('res://scripts/lookat/engine.gd').new();e.reset(42,1);e.sample(actors,{}, {},[])
 e.phase=phase;e.frame={'losses':{},'money':0};e.ui={'over_field':false};e.now=1.0
 for uid in e.states:e.states[uid].triggers.clear()
 return e
func frame(e,dt=0.1):
 e.update(dt,e.ui,[],{'phase':e.phase,'staging':'','elapsed':0,'money':0,'losses':{}})
func _initialize():
 test_points();test_sell();test_duel();test_jump()
 print('LookAt gap failures: ',failures);quit(failures)
func test_points():
 var list=[]
 for i in 4:list.append(actor('cell:'+str(i),'wall',Vector2(i*25,0)))
 var e=engine(list,'shop');var receiver=e.states['cell:0']
 receiver.choice={'case':102};receiver.target=''
 for i in range(1,4):
  var s=e.states['cell:'+str(i)];s.target='';s.point=Vector2(11+i*0.5,300);s.choice={'direction':2}
 var f=e.detectors.facts(e,e.actors['cell:0'],receiver)
 check(not f.has(104),'point contagion waits for telegraph delay')
 e.now+=0.6;f=e.detectors.facts(e,e.actors['cell:0'],receiver)
 check(f.has(104) and f[104].target=='' and f[104].point.distance_to(Vector2(12,300))<0.01,'three nearby point targets spread their mean, across bin boundary')
 e.states['cell:3'].point=Vector2(-1000,0)
 f=e.detectors.facts(e,e.actors['cell:0'],receiver)
 check(not f.has(104),'two matching votes cannot preserve a stale contagion')
 for i in range(1,4):e.states['cell:'+str(i)].target='cell:0'
 e.detectors.facts(e,e.actors['cell:0'],receiver);e.now+=0.6
 f=e.detectors.facts(e,e.actors['cell:0'],receiver)
 check(f.has(104) and f[104].target=='cell:0','existing object contagion remains supported')
func test_sell():
 var e=engine([actor('cell:0','wall',Vector2.ZERO),actor('cell:1','wall',Vector2(70,0)),actor('cell:2','wall',Vector2(700,0)),actor('core:3','core',Vector2(40,50),'core','')],'shop')
 e.ui={'over_field':false,'selected_uid':'cell:0','sell_hover':true}
 for i in 4:frame(e)
 check(e.output('cell:0').emotion=='worried','Sell selected cell stays worried')
 check(e.output('cell:1').emotion=='raised_brow' and e.output('core:3').emotion=='raised_brow','Sell hover raises neighboring cell and Core eyebrows before sale')
 check(e.output('cell:2').get('case',0)!=199,'distant cell does not react to Sell')
 e.phase='battle'
 for i in 20:frame(e)
 check(e.output('cell:1').get('case',0)!=199,'Sell hover is preparation-only')
func test_duel():
 var e=engine([actor('cell:1','turret',Vector2.ZERO,'cell','shoot'),actor('virus:2','virus_basic',Vector2(60,0),'virus','')])
 var a=e.states['cell:1'];var b=e.states['virus:2']
 a.target='virus:2';a.pair='virus:2';a.pair_since=0.0
 b.target='cell:1';b.pair='cell:1';b.pair_since=0.0
 e.detectors.event(e,{'event':'damage','data':{'id':1,'source_id':2,'p':Vector2.ZERO}})
 e.now+=0.01
 e.detectors.event(e,{'event':'virus_hit','data':{'id':2,'source_id':1,'p':Vector2(60,0)}})
 var sequence=[];var other_surprised=false
 for i in 24:
  frame(e,0.1)
  var expression=e.output('cell:1').emotion
  if sequence.is_empty() or sequence.back()!=expression:sequence.append(expression)
  other_surprised=other_surprised or e.output('virus:2').get('case',0)==186
 check(sequence.size()>=3 and sequence[0]=='hurt' and sequence[1]=='surprised' and sequence[2]=='angry','first hit: hurt then surprised then ongoing combat angry')
 check(not other_surprised,'second contestant hit does not receive first-hit surprise')
 # Reverse event order in a new pair episode.
 e=engine([actor('cell:1','turret',Vector2.ZERO,'cell','shoot'),actor('virus:2','virus_basic',Vector2(60,0),'virus','')])
 a=e.states['cell:1'];b=e.states['virus:2'];a.target='virus:2';a.pair='virus:2';a.pair_since=0;b.target='cell:1';b.pair='cell:1';b.pair_since=0
 e.detectors.event(e,{'event':'virus_hit','data':{'id':2,'source_id':1}})
 e.detectors.event(e,{'event':'damage','data':{'id':1,'source_id':2}})
 var virus_surprised=false;var cell_surprised=false
 for i in 18:
  frame(e);virus_surprised=virus_surprised or e.output('virus:2').get('case',0)==186;cell_surprised=cell_surprised or e.output('cell:1').get('case',0)==66
 check(virus_surprised and not cell_surprised,'reverse order: only first-hit virus reacts')
func landing(e,start,finish):
 var s=e.states['virus:2'];s.triggers.clear()
 e.detectors.event(e,{'event':'virus_jump_started','data':{'id':2,'p':start}})
 e.detectors.event(e,{'event':'virus_landed','data':{'id':2,'p':finish}})
 return s.triggers.has(189)
func test_jump():
 var e=engine([actor('cell:1','wall',Vector2.ZERO),actor('virus:2','virus_jumper',Vector2(0,60),'virus','')])
 e.states['virus:2'].prev.jump=true
 var facts=e.detectors.facts(e,e.actors['virus:2'],e.states['virus:2'])
 check(not facts.has(189),'an observed landing near a wall cannot fabricate crossing without a takeoff')
 check(not landing(e,Vector2(0,35),Vector2(0,60)),'landing near wall on same side does not smirk')
 check(not landing(e,Vector2(100,-60),Vector2(100,60)),'jump around wall end does not count as crossing')
 check(not landing(e,Vector2(0,-60),Vector2(0,15)),'landing inside wall clearance does not count as behind it')
 check(landing(e,Vector2(0,-60),Vector2(0,60)),'crossing the wall during one render frame triggers C189')
 frame(e,0.2)
 check(e.output('virus:2').get('case',0)==189,'crossing selects smirk in the emotion arbiter')
 e.actors['cell:1'].body.angle=PI/2
 check(landing(e,Vector2(60,0),Vector2(-60,0)),'crossing respects rotated wall geometry')
 check(not landing(e,Vector2(60,100),Vector2(-60,100)),'rotated wall near-miss does not smirk')
 # Verify the real movement code supplies both events even between observer samples.
 var sim=load('res://scripts/simulation.gd').new();sim.reset(42,12)
 sim.spawn_virus({'type':'jumper','lane':0,'p':Vector2.ZERO});var v=sim.viruses.back();v.jump_cooldown=0.0
 var cursor=sim.event_sequence
 sim.virus_motion.tick(sim,v,Vector2.RIGHT,0.01)
 sim.virus_motion.tick(sim,v,Vector2.RIGHT,0.11)
 var names=sim.events_since(cursor).map(func(event):return event.event)
 check('virus_jump_started' in names and 'virus_landed' in names,'real jump exports takeoff and landing events')
