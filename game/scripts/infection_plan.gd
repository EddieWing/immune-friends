extends RefCounted
# Single-player geometry/timing from Auto Immune Demo 1.0.0.
# One reference blood-cell width (3.5) maps to our Core diameter (26).
const WORLD_SCALE = 26.0 / 3.5
const ANGLES = [0,45,90,135,180,-45,-135]
const DISTANCES = [80,70,60,70,80,70,70]
const GROWTH = [2,2,3,3,5,6,8,9,12,14,18,20]

func slots(angle: float, distance: float, layer: int) -> Array:
 var points=[]
 var direction=Vector2.from_angle(deg_to_rad(angle))
 var center=direction*distance
 var inset=[0.0,35.0,45.0][layer]
 var start=deg_to_rad(270+inset)
 var arc=deg_to_rad(180-2*inset)
 var radius=maxf(4.55,20.0*layer)
 while radius<20.0*(1+layer)-1.75:
  var count=radius*arc/4.55
  for index in range(int(ceil(count))):
   var p=center+direction.rotated(start+index*4.55/radius)*radius
   # Reference world Y is up; Godot canvas Y is down.
   points.append(Vector2(p.x,-p.y)*WORLD_SCALE)
  radius+=5.915
 return points

func shuffle(values: Array, rng: RandomNumberGenerator):
 for i in range(values.size()-1,0,-1):
  var j=rng.randi_range(0,i)
  var value=values[i]
  values[i]=values[j]
  values[j]=value

func build(seed_value: int, round_no: int, kinds: Array, training: int=3) -> Dictionary:
 # Dedicated RNG makes preview/reload reproducible without consuming shop RNG.
 # It preserves the rules, not the original JS RNG's seed sequence.
 var rng=RandomNumberGenerator.new()
 rng.seed=seed_value
 var candidates=[1,2,3,4,5,6]
 shuffle(candidates,rng)
 var directions=[0,candidates[0],candidates[1]]
 var order=[1,2,0,1,2,0,1,2]
 shuffle(order,rng)
 order.push_front(0)
 var layers=[1,0,0]
 var groups=[]
 var emitters=[]
 for r in range(1,mini(round_no,12)+1):
  var group_index=int((r-1)/2)
  var amount=GROWTH[r-1]
  if r%2==1:
   var direction=order[group_index]
   while layers[direction]>=3: direction=(direction+1)%3
   var layer=layers[direction]
   layers[direction]+=1
   var angle_index=directions[direction]
   var pool=kinds.filter(func(kind):return kind not in ["basic","splitter"])
   var basic_group=group_index==0 or (training==0 and group_index<2)
   var kind="basic" if basic_group or pool.is_empty() else pool[rng.randi_range(0,pool.size()-1)]
   var group={"direction":direction,"layer":layer,"slots":slots(ANGLES[angle_index],DISTANCES[angle_index],layer),"used":0,"members":[],"type":kind}
   groups.append(group)
   for i in range(amount): add_emitter(group,group_index,emitters,rng)
  else:
   var group=groups[group_index]
   for i in range(amount):
    var member=group.members[rng.randi_range(0,group.members.size()-1)]
    if rng.randf()>0.5 or group.used>=group.slots.size(): emitters[member].amount+=1
    else: add_emitter(group,group_index,emitters,rng)
 var sorted=range(groups.size())
 sorted.sort_custom(func(a,b): return groups[a].direction<groups[b].direction if groups[a].direction!=groups[b].direction else groups[a].layer<groups[b].layer)
 var delay=1.0
 var previous=-1
 for index in sorted:
  var group=groups[index]
  if previous>=0 and previous!=group.direction: delay+=3.0
  for member in group.members: emitters[member].delay=delay
  previous=group.direction
  delay+=3.0
 var positions=[]
 var wave=[]
 for i in range(groups.size()):
  var center=Vector2.ZERO
  var count=0
  for member in groups[i].members:
   center+=emitters[member].p
   count+=emitters[member].amount
  positions.append(center/groups[i].members.size())
  wave.append({"type":groups[i].type,"count":count,"lane":i})
 return {"positions":positions,"wave":wave,"emitters":emitters}

func add_emitter(group: Dictionary, index: int, emitters: Array, rng: RandomNumberGenerator):
 group.members.append(emitters.size())
 emitters.append({"p":group.slots[group.used],"lane":index,"type":group.type,"amount":1,"cooldown":1.0+rng.randf(),"delay":0.0})
 group.used+=1

# Schedule contains every future release, independent of surviving active viruses.
func schedule(wave,emitters,rng):
 var queue=[]
 for entry in wave:
  var remaining=int(entry.count)
  for index in range(emitters.size()):
   var emitter=emitters[index]
   if emitter.lane!=entry.lane or emitter.type!=entry.type:continue
   var count=mini(remaining,emitter.amount)
   for i in range(count):
    queue.append({"type":entry.type,"lane":entry.lane,"emitter":index,"p":emitter.p,"due":emitter.delay+i*emitter.cooldown})
   remaining-=count
  # User-created Gym/debug sources have no persistent emitter yet.
  var interval=rng.randf_range(1.0,2.0)
  for i in range(remaining):queue.append({"type":entry.type,"lane":entry.lane,"due":1.0+i*interval})
 queue.sort_custom(func(a,b):return a.due<b.due)
 return queue
