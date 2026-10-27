extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok: failures+=1
func _initialize():
 var sim=preload("res://scripts/simulation.gd").new()
 sim.reset(42,12)
 var director=preload("res://scripts/camera_director.gd").new()
 sim.blood=[{"alive":true,"p":Vector2.ZERO},{"alive":false,"p":Vector2(-10000,0)}]
 sim.viruses=[]
 sim.spawn_queue=[]
 check(director.interest(sim).is_empty(),"No threats means no camera target")
 sim.viruses=[{"alive":true,"p":Vector2(100,0)},{"alive":false,"p":Vector2(10000,0)}]
 var region=director.interest(sim)
 check(region.focus==Vector2(48.5,0) and region.radius==61.5,"Living Core and virus body sizes define bounds")
 sim.cells=[{"alive":true,"p":Vector2(20000,0)}]
 check(region==director.interest(sim),"Immune cells do not affect camera bounds")
 sim.viruses=[]
 sim.infection_sources=[Vector2(200,0),Vector2(-1000,0)]
 sim.spawn_queue=[{"lane":0,"type":"basic"},{"lane":1,"type":"basic"}]
 sim.spawn_timer=0.65
 var queue=sim.spawn_queue.duplicate(true)
 region=director.interest(sim)
 check(region.focus==Vector2(127.5,0),"Source at exactly 0.65 seconds is included; later release excluded")
 check(sim.spawn_queue==queue and sim.spawn_timer==0.65,"Framing does not mutate spawn schedule")
 sim.spawn_timer=0.65001
 check(director.interest(sim).is_empty(),"Source beyond release threshold is excluded")
 sim.spawn_queue=[]
 check(director.interest(sim).is_empty(),"Empty sources are excluded")
 var safe=Rect2(0,0,600,600)
 var position=Vector2(300,300)
 check(director.follow_position(position,1.0,safe,{"focus":Vector2(100,0),"radius":50},1)==position,"Camera holds when interest fits")
 var moved=director.follow_position(position,1.0,safe,{"focus":Vector2(400,0),"radius":50},0.1)
 check(moved.x<position.x and moved.x>-100,"Camera smoothly follows outside interest")
 check(director.follow_position(position,1.0,safe,{"focus":Vector2(1,0),"radius":500},1)==position,"Oversized region does not produce center jitter")
 check(director.follow_position(position,1.0,safe,{},1)==position,"No interest holds camera")
 sim.blood=[{"alive":true,"p":Vector2.ZERO}]
 sim.cells=[]
 var forecast=director.forecast_frame(sim,[{"lane":0,"count":10}],[Vector2(400,0),Vector2(10000,10000)],safe,0.9)
 check(forecast.focus==Vector2(200,0),"Forecast ignores reserved but inactive source positions")
 var far=director.forecast_frame(sim,[{"lane":0,"count":10}],[Vector2(1800,900)],safe,0.9)
 var origin=safe.get_center()-far.focus*far.zoom
 var screen_bounds=Rect2(far.bounds.position*far.zoom+origin,far.bounds.size*far.zoom)
 check(safe.grow(0.01).encloses(screen_bounds),"Forecast fits actual formation and distant active source")
 quit(failures)
