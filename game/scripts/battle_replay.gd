extends RefCounted
const Save=preload("res://scripts/preparation_save.gd")
const Sim=preload("res://scripts/simulation.gd")
const STEP=1.0/60.0
var recording={}
var last={}
static func rules_id():
	# Exported scripts can be compiled; use the shipped build version and data.
	var source="replay-v1:"+str(ProjectSettings.get_setting("application/config/version"))
	for name in ["cells","assumptions","shop_rules"]:
		source+=FileAccess.get_file_as_string("res://data/"+name+".json")
	return source.sha256_text()
static func outcome(s):
	return JSON.stringify(Save.encode({"phase":s.phase,"losses":s.round_losses,"cells":s.cells,"blood":s.blood,"money":s.money,"max_funds":s.max_funds,"rewards":s.reward_choices,"rng":str(s.rng.state)}),"",true,true).sha256_text()
func start(s):
	recording={"version":1,"rules":rules_id(),"preparation":Save.capture(s),"catalog":s.catalog.duplicate(true),"balance":s.rules.duplicate(true),"tuning":s.tuning.duplicate(true),"ticks":0}
func tick(s):
	if recording.is_empty():return
	recording.ticks+=1
	if s.phase!="battle":
		recording["outcome"]=outcome(s)
		last=recording
		recording={}
static func open(data):
	if not data is Dictionary or data.get("version",0)!=1 or data.get("rules","")!=rules_id():return {"error":"This replay uses a different game version."}
	if not data.get("ticks") is float and not data.get("ticks") is int:return {"error":"The replay is incomplete."}
	if data.ticks<1 or data.ticks>360000 or not data.get("outcome") is String:return {"error":"The replay is incomplete."}
	for field in ["catalog","balance","tuning"]:
		if not data.get(field) is Dictionary:return {"error":"The replay settings are incomplete."}
	var s=Sim.new()
	var checked=Save.inspect(data.get("preparation"),s)
	if checked.has("error"):return checked
	s.catalog=data.catalog.duplicate(true);s.rules=data.balance.duplicate(true);s.tuning=data.tuning.duplicate(true)
	Save.restore(s,checked);s.begin_battle()
	return {"sim":s}
