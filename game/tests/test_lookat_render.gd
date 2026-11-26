extends SceneTree
var failures=0
func check(ok,label):
 print(('PASS ' if ok else 'FAIL ')+label)
 if not ok:failures+=1
func _initialize():
 var renderer=load('res://atlas_integration/renderer.gd').new()
 var bandage=renderer.create('bandage');bandage.mode='healDeath';renderer.advance(bandage,0.3)
 check(bandage.weights.kiss>0.9 and bandage.weights.hurt<0.01,'Bandage dies with kiss')
 var wall=renderer.create('wall');wall.mode='death';renderer.advance(wall,0.3)
 check(wall.weights.hurt>0.9,'ordinary death remains hurt')
 var bomb=renderer.create('bomb');bomb.mode='explode';bomb.dead=true;renderer.advance(bomb,0.3)
 check(bomb.weights.hurt>0.9,'lethal explosion keeps hurt death exception limited to Bandage')
 quit(failures)
