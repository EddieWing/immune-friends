extends RefCounted
# Demo 1.0.0 electricity: persistent current, directed conductor graph,
# stable branch order and simultaneous one-edge advancement per simulation step.
var web_kernel
func _init():
	if OS.has_feature("web") and OS.get_thread_caller_id()==OS.get_main_thread_id():
		JavaScriptBridge.eval(preload("res://scripts/web_electricity.gd").SOURCE,true)
		web_kernel=JavaScriptBridge.get_interface("microcosmElectricity")
var currents={}
var step=0
const SOURCES=["zapper","generator","electric_wall","kinetic_generator","electromagnet"]
func reset():
	currents.clear();step=0
func draw_toward(id,nodes):
	var seen={};var queue=[id];var found=false
	while not queue.is_empty() and not found:
		var next=[]
		for here in queue:
			if seen.has(here):continue
			seen[here]=true
			if currents.has(here) and (here!=id or not nodes[id].source):found=true
			var neighbors=nodes[here].outgoing.duplicate()
			if nodes[id].source:
				for x in nodes[here].incoming:
					if not neighbors.has(x):neighbors.append(x)
			neighbors.sort()
			for other in neighbors:
				if seen.has(other):continue
				next.append(other)
				nodes[here].outgoing.erase(other)
				if not nodes[here].incoming.has(other):nodes[here].incoming.append(other)
				nodes[other].incoming.erase(here)
				if not nodes[other].outgoing.has(here):nodes[other].outgoing.append(here)
		queue=next
func update(s):
	step+=1
	if not s.cells.any(func(c):return c.alive and c.key in SOURCES):
		currents.clear();return
	var bodies={};var eligible=[];var sources=[]
	var reach=float(s.rules.charge_range)
	for body in s.cells+s.viruses+s.particles:
		if not body.get("alive",true) or body.get("life",1)<=0 or body.get("jump",false):continue
		if not body.has("id"):body.id=s.next_id;s.next_id+=1
		var id=int(body.id)
		var source=body.get("key","") in SOURCES
		bodies[id]=body;eligible.append(body)
		if source:sources.append(id)
	for id in currents.keys():
		if not bodies.has(id) or not bodies.has(currents[id].source):currents.erase(id)
	for id in sources:
		if not currents.has(id) and bodies[id].charge>0:currents[id]={"source":id,"path":[id]}
	# Particle IDs and current pruning still run without charge. Graph storage
	# and spatial buckets have no persistent state and are only needed with current.
	if currents.is_empty():return
	var nodes={};var buckets={}
	for body in eligible:
		var id=int(body.id)
		nodes[id]={"body":body,"source":body.get("key","") in SOURCES,"magnet":body.get("key","")=="electromagnet","outgoing":[]}
		if web_kernel==null:
			nodes[id].incoming=[];nodes[id].targets=[]
			var bucket=Vector2i(floori(body.p.x/reach),floori(body.p.y/reach))
			if not buckets.has(bucket):buckets[bucket]=[]
			buckets[bucket].append(id)
	var active=build_web_graph(nodes,reach) if web_kernel!=null else build_graph(nodes,sources,buckets,reach)
	var transfers=[]
	for id in active:
		var outgoing=nodes[id].outgoing
		if not outgoing.is_empty():
			outgoing.sort();transfers.append([outgoing[0],currents[id]])
		currents.erase(id)
	for transfer in transfers:
		currents[transfer[0]]=transfer[1]
		transfer[1].path.push_front(transfer[0])
	for id in nodes:
		var node=nodes[id]
		if not currents.has(id):continue
		var virus=node.body.has("type")
		var sink=(virus and (node.outgoing.is_empty() or step%2==id%2)) or (node.magnet and node.outgoing.is_empty())
		if not sink:continue
		var current=currents[id];var source=nodes[current.source].body
		if source.charge<=0:currents.erase(id);continue
		source.charge-=1
		var path=[]
		for point in current.path:
			if nodes.has(point):path.push_front(nodes[point].body.p)
		if virus:
			s.damage_virus(node.body,1,{"p":source.p,"cause":"electric","owner":source.id})
			if not node.body.alive:s.record("charge_kill",{"source":source.id})
		else:node.body.charge+=1
		s.record("discharge",{"path":path,"source":source.id,"target":id})
		for i in range(1,path.size()):s.effects.append({"p":path[i-1],"end":path[i],"color":Color("#fff3a9"),"text":"","r":0,"life":0.15,"max":0.15})

func build_graph(nodes,sources,buckets,reach):
	var queue=sources.duplicate();var seen={};var active=[];var cursor=0
	while cursor<queue.size():
		var id=queue[cursor];cursor+=1
		if seen.has(id):continue
		seen[id]=true
		if currents.has(id):active.append(id)
		# Only reached nodes consume their neighbour list. Disconnected bodies
		# still exist for current pruning and sink handling, with empty edges.
		var body: Dictionary=nodes[id].body
		var position: Vector2=body.p
		var bucket=Vector2i(floori(position.x/reach),floori(position.y/reach))
		for x in range(-1,2):
			for y in range(-1,2):
				for other in buckets.get(bucket+Vector2i(x,y),[]):
					if other!=id and position.distance_squared_to(nodes[other].body.p)<reach*reach:nodes[id].targets.append(other)
		nodes[id].targets.sort()
		for other in nodes[id].targets:
			if nodes[id].incoming.has(other) or nodes[id].outgoing.has(other):continue
			var outgoing=false
			if nodes[other].source and nodes[other].body.charge>0:
				var charged=nodes[id].source and nodes[id].body.charge>0
				if charged and not (not nodes[id].magnet and nodes[other].magnet):continue
				outgoing=true
			var a=id if outgoing else other;var b=other if outgoing else id
			nodes[a].outgoing.append(b);nodes[b].incoming.append(a);queue.append(other)
	for id in sources:
		if nodes[id].magnet:draw_toward(id,nodes)
	for id in nodes:
		if nodes[id].body.has("type"):draw_toward(id,nodes)
	return active

func build_web_graph(nodes,reach):
	var rows=[]
	for id in nodes:
		var node=nodes[id];var body=node.body
		rows.append([id,body.p.x,body.p.y,node.source,node.magnet,body.get("charge",0)>0,body.has("type")])
	var result=JSON.parse_string(web_kernel.graph(JSON.stringify([rows,reach,currents.keys()],"",true,true)))
	var index=0
	for id in nodes:
		var next=int(result[1][index]);index+=1
		if next>=0:nodes[id].outgoing.append(next)
	var active=[]
	for id in result[0]:active.append(int(id))
	return active
