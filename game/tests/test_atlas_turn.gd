extends SceneTree
var failures=0
func check(value,label):
 print(('PASS: ' if value else 'FAIL: ')+label)
 if not value:failures+=1
func _initialize():call_deferred('run')
func run():
 var r=preload('res://atlas_integration/renderer.gd').new()
 var smooth=true;var arrived=true;var gaze=true
 for id in r.data.characters:
  var state=r.create(id);state.angle=0.0;r.advance(state,0)
  var previous=r.visual_angle(state,0)
  state.angle=PI
  for frame in 90:
   r.advance(state,1.0/60,Vector2.LEFT)
   var angle=r.visual_angle(state,state.angle)
   smooth=smooth and absf(wrapf(angle-previous,-PI,PI))<=8.0/60+0.0001
   gaze=gaze and is_equal_approx(state.look.length(),1)
   previous=angle
  arrived=arrived and absf(wrapf(previous-PI,-PI,PI))<0.01
 check(smooth,'all 50 rigs turn without instantaneous jumps')
 check(arrived,'all rigs reach the requested orientation')
 check(gaze,'opposite gaze directions never collapse through zero')
 var orb=r.create('orbiter');orb.mode='orbit';orb.velocity=Vector2.RIGHT;r.advance(orb,0)
 var previous=r.visual_angle(orb,0);orb.velocity=Vector2.LEFT;r.advance(orb,1.0/60)
 check(absf(wrapf(r.visual_angle(orb,0)-previous,-PI,PI))<0.14,'Orbiter velocity reversal is visually smoothed')
 r.action(orb,'idle');previous=r.visual_angle(orb,0);r.advance(orb,1.0/60)
 check(absf(wrapf(r.visual_angle(orb,0)-previous,-PI,PI))<0.14,'mode changes retain continuous orientation')
 var wave=r.create('virus_wave');wave.mode='wave';wave.wave_progress=0.0;r.advance(wave,0)
 wave.wave_progress=0.5;r.advance(wave,0.5)
 check(is_equal_approx(r.visual_angle(wave,0),TAU),'Wave retains its complete revolution')
 var frozen=r.visual_angle(wave,0);r.action(wave,'death');r.advance(wave,0.1)
 check(is_equal_approx(r.visual_angle(wave,0),frozen),'death retains the last orientation')
 var rest=r.create('seeker');rest.preparing=true;r.advance(rest,0.25)
 check(absf(r.resting_scale(rest)-1)>0.005,'preparation idle has visible continuous breathing')
 rest.preparing=false
 check(r.resting_scale(rest)==1,'idle breathing does not affect battle scale')
 var wall=r.create('wall');wall.preparing=true;r.advance(wall,0.5)
 check(r.resting_scale(wall)==1,'accepted Wall idle remains unchanged')
 print('Atlas turn failures: '+str(failures));quit(failures)
