extends SceneTree
var errors=0
func check(ok,label):
 print(('PASS: ' if ok else 'FAIL: ')+label)
 if not ok:errors+=1
func _initialize():
 var r=preload('res://atlas_integration/renderer.gd').new()
 var a=r.create('tackle');var b=r.create('tackle');b.idle_phase=2.4
 var closed=false;var open=false;var different=false;var previous=0.0;var jump=0.0
 for i in 1500:
  a.clock=i/120.0;b.clock=a.clock
  var value=r.blink_amount(a)
  closed=closed or value>0.99;open=open or value==0
  different=different or absf(value-r.blink_amount(b))>0.5
  if i>0:jump=maxf(jump,absf(previous-value))
  previous=value
 check(closed and open,'Periodic full blink followed by open eyes')
 check(different,'Independent per-cell phase')
 check(jump<0.15,'Continuous lid motion at 120 Hz')
 a.mode='death'
 check(r.blink_amount(a)==0,'Death hurt face never overridden by blinking')
 a.mode='idle';a.reaction='wink'
 check(r.blink_amount(a)==0,'Explicit wink reaction keeps priority')
 quit(errors)
