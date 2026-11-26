extends SceneTree
var failures=0
func check(ok,label):
 print(('PASS ' if ok else 'FAIL ')+label)
 if not ok:failures+=1
func state():return {'choice':{},'cooldowns':{},'seen':{},'until':0.0,'chosen_at':-INF,'target':'','point':Vector2.ZERO,'targets':[],'points':[]}
func row(code,emotion,frequency):return {'id':str(code),'case':code,'emotion':emotion,'frequency':frequency,'phases':['shop','battle'],'direction':0}
func _initialize():
 var c=JSON.parse_string(FileAccess.get_file_as_string('res://data/lookat.json'))
 var rules=load('res://scripts/lookat/emotion_rules.gd').new(c,{'actor':[row(1,'calm','state'),row(2,'angry','state'),row(3,'hurt','often'),row(4,'wink','rare'),row(5,'surprised','sometimes'),row(6,'kiss','often')]})
 var rng=RandomNumberGenerator.new();rng.seed=5
 var a={'key':'actor','body':{'p':Vector2.ZERO},'no_mouth':false};var s=state()
 var all={1:{'time':0},2:{'time':0},3:{'time':0},4:{'time':0}}
 check(rules.choose(a,s,all,'battle',1,0,rng).emotion=='hurt','hurt wins over threat and rare gag')
 check(rules.choose(a,s,{1:{'time':0},2:{'time':0}},'battle',1,1,rng).emotion=='angry','threat resumes after hurt')
 s=state();rules.rare_until=0
 check(rules.choose(a,s,{4:{'time':0}},'battle',5,0,rng).is_empty(),'rare blocked at x5')
 check(rules.choose(a,s,{4:{'time':0}},'shop',5,0,rng).emotion=='wink','preparation allows rare at x5')
 var other=state()
 check(rules.choose(a,other,{4:{'time':1}},'shop',1,1,rng).is_empty(),'global rare budget shared across actors')
 s=state();rules.choose(a,s,{5:{'time':0}},'battle',5,0,rng)
 check(s.cooldowns[5]==16,'sometimes cooldown doubled at x5')
 check(rules.choose(a,s,{5:{'time':1}},'battle',5,3,rng).is_empty(),'cooldown blocks replay of fresh event')
 a.no_mouth=true;s=state()
 check(rules.choose(a,s,{6:{'time':0}},'shop',1,0,rng).is_empty(),'no-mouth actor cannot kiss')
 print('LookAt arbitration failures: ',failures);quit(failures)
