extends SceneTree
var failures=0
func check(value,label):
 print(('PASS: ' if value else 'FAIL: ')+label)
 if not value:failures+=1
func _initialize():call_deferred('run')
func run():
 var sim=preload('res://scripts/simulation.gd').new();sim.reset(42,12)
 var view=preload('res://atlas_integration/presentation.gd').new()
 for kind in ['wall','seeker','orbiter','tackle']:
  sim.cells.append(sim.make_cell(kind,Vector2(100,0)))
 view.update(sim,1.0/60)
 var initial={}
 for cell in sim.cells:
  var state=view.states[view.key_of(cell)]
  initial[cell.id]={'mode':state.mode,'age':state.age,'look':state.look}
 var stable=true;var uninterrupted=true;var heading=true
 # Pointer events arrive less often than display frames, then stop and reverse.
 for frame in 60:
  for cell in sim.cells:
   if frame%3==0:cell.p+=Vector2(9 if frame<30 else -9,3)
  view.update(sim,1.0/60)
  for cell in sim.cells:
   var state=view.states[view.key_of(cell)]
   stable=stable and state.mode==initial[cell.id].mode
   uninterrupted=uninterrupted and state.age>initial[cell.id].age
   heading=heading and state.look.is_equal_approx(initial[cell.id].look)
   initial[cell.id].age=state.age
 check(stable,'preparation drag never alternates idle and locomotion between pointer events')
 check(uninterrupted,'preparation animation clock runs continuously through drag, pause and reversal')
 check(heading,'manual placement does not jitter autonomous facing')
 var cell=sim.cells[1];sim.phase='battle';sim.elapsed+=1.0/60;cell.p+=Vector2(2,0)
 view.update(sim,1.0/60)
 check(view.states[view.key_of(cell)].mode=='pursue','real battle movement still activates Seeker locomotion')
 print('Atlas drag failures: '+str(failures));quit(failures)
