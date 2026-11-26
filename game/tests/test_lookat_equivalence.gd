extends SceneTree
func _initialize():
 var fixture=load('res://tests/fixtures/heavy_battle.gd')
 var a=fixture.new();var b=fixture.new();a.setup();b.setup()
 var observer=load('res://scripts/lookat/observer.gd').new()
 for tick in 3600:
  a.update(1.0/60);b.update(1.0/60)
  observer.update(b,1.0/60,{'speed':1,'over_field':false})
  if tick%120==119 and a.fingerprint()!=b.fingerprint():
   push_error('LookAt modified simulation at tick '+str(tick+1));quit(1);return
 print('PASS LookAt on/off full fingerprint identical at 3600 ticks: ',a.fingerprint())
 quit()
