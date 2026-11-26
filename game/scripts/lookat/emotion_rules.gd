extends RefCounted
# Portable presentation arbitration. No simulation or atlas dependencies.
var config: Dictionary
var rows: Dictionary
var rare_until=0.0
var serial=0
var index={}
func _init(settings={},cases={}):
 config=settings;rows=cases
 for key in rows:
  index[key]={}
  for row in rows[key]:index[key][int(row.case)]=row
func priority(row,phase):
 if row.emotion=='hurt':return 6
 # The loser of a stare contest reacts after hurt, even under ongoing threat.
 if int(row.case) in [66,186]:return 5.5
 if phase=='battle' and row.frequency=='state' and row.emotion in ['angry','worried']:return 5
 return {'often':4,'sometimes':3,'rare':2,'state':1}[row.frequency]
func duration(row):
 if int(row.case)==141:return config.core_grief_delay
 if row.emotion=='hurt':return config.durations.hurt
 if config.reactions.has(row.emotion):
  var v=config.reactions[row.emotion];return v[0]+v[1]+v[2]
 return config.hold_min if row.frequency=='state' else config.durations.get(row.emotion,config.durations.default)
func choose(actor,state,facts,phase,speed,now,rng):
 var current=state.get('choice',{})
 var winner={};var best=-1;var newest=-INF
 if not current.is_empty() and now<state.until and current.phases.has(phase):
  winner=current;best=priority(current,phase);newest=state.chosen_at
 for code in facts:
  if not code is int or not index.get(actor.key,{}).has(code):continue
  var row=index[actor.key][code]
  if not row.phases.has(phase):continue
  if actor.get('no_mouth',false) and row.emotion=='kiss':continue
  if row.frequency=='rare' and (now<rare_until or (phase=='battle' and speed>=config.speed5)):continue
  if phase=='battle' and facts.get('threat',false) and (row.frequency=='rare' or code in [32,71,93,126,127,128,129,130,131,135,150,153,154,155,156,166,168,171,176,177,179]):continue
  if now<float(state.cooldowns.get(code,-INF)):continue
  var fact=facts[code]
  if row.frequency!='state' and state.seen.get(code,-INF)>=fact.time:continue
  var rank=priority(row,phase)
  if rank<best or (rank==best and fact.time<=newest):continue
  if config.chance.has(str(code)) and rng.randf()>float(config.chance[str(code)]):state.seen[code]=fact.time;continue
  winner=row;best=rank;newest=fact.time
 if winner.is_empty():return {}
 if current.get('id','')!=winner.id or (winner.frequency!='state' and newest>state.get('chosen_at',-INF)):
  var code=int(winner.case);var fact=facts.get(code,{})
  if not config.reactions.has(current.get('emotion','calm')):state.return_emotion=current.get('emotion','calm')
  state.choice=winner;state.chosen_at=now;state.until=now+duration(winner)
  state.target=fact.get('target','');state.point=fact.get('point',actor.body.p)
  state.targets=fact.get('targets',[]);state.points=fact.get('points',[])
  state.seen[code]=newest;state.choice_fact_time=newest
  var cooldown=float(config.cooldowns[winner.frequency])
  if phase=='battle' and speed>=config.speed5 and winner.frequency=='sometimes':cooldown*=config.speed5_cooldown
  state.cooldowns[code]=now+cooldown
  if winner.frequency=='rare':rare_until=now+config.rare_global
  serial+=1;state.serial=serial
 elif winner.frequency=='state' and facts.has(int(winner.case)):
  var fact=facts[int(winner.case)]
  state.target=fact.get('target',state.target);state.point=fact.get('point',state.point)
  state.targets=fact.get('targets',state.targets);state.points=fact.get('points',state.points)
 return winner
