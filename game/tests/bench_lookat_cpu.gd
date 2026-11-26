extends SceneTree
func _initialize():
 var observer=load('res://scripts/lookat/observer.gd').new()
 var sim=load('res://tests/fixtures/heavy_battle.gd').new();sim.setup()
 var times=[];var total=0;var peak=0
 for frame in 180:
  for tick in 5:sim.update(1.0/60)
  var before=Time.get_ticks_usec()
  observer.update(sim,1.0/60,{'over_field':false,'speed':5})
  for uid in observer.engine.actors:observer.output(uid)
  var cost=Time.get_ticks_usec()-before
  times.append(cost);total+=cost;peak=maxi(peak,cost)
 times.sort()
 var result={'frames':times.size(),'simulation_ticks':900,'speed':5,'mean_us':float(total)/times.size(),'p95_us':times[int(times.size()*0.95)],'peak_us':peak,'states':observer.engine.states.size(),'includes':'sampling, selection, events and per-frame gaze output; excludes existing art drawing'}
 print('LOOKAT_CPU ',JSON.stringify(result))
 var out=FileAccess.open('user://lookat_cpu_result.json',FileAccess.WRITE);out.store_string(JSON.stringify(result,'  '));out.close()
 quit()
