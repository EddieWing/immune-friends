extends "res://scripts/electricity.gd"
var local_core
var local_ready=false
func _init():
	super()
	local_core=ClassDB.instantiate("CoreKernel")
	web_kernel=local_core # Worker-local implementation supplies the accelerated path.
func build_web_graph(nodes,reach):
	if not local_ready:
		local_core.local_init(preload("res://scripts/web_electricity.gd").SOURCE)
		local_ready=true
	var rows=[]
	for id in nodes:
		var node=nodes[id];var body=node.body
		rows.append([id,body.p.x,body.p.y,node.source,node.magnet,body.get("charge",0)>0,body.has("type")])
	var result=JSON.parse_string(local_core.local_graph(JSON.stringify([rows,reach,currents.keys()],"",true,true)))
	var index=0
	for id in nodes:
		var next=int(result[1][index]);index+=1
		if next>=0:nodes[id].outgoing.append(next)
	var active=[]
	for id in result[0]:active.append(int(id))
	return active
