extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
var failures=0
func check(ok,label):
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok:failures+=1
func _initialize():
	var s=Sim.new();s.reset(42,12);s.experimental=true
	for key in ["wall","tackle"]:
		var a=s.make_cell(key,Vector2.ZERO);var b=s.make_cell(key,Vector2(100,0));a.rank=2
		s.cells.append(a);s.cells.append(b);s.merge(a,b)
	check(s.reward_choices.size()==2,"two promotions queue two independent choices")
	for choice in s.reward_choices:
		check(choice.size()==2 and choice[0]!=choice[1],"reward options are distinct")
		for key in choice:check(s.available_cell_keys().has(key) and s.catalog[key].tier==0,"reward belongs to available special pool")
	var expected=s.reward_choices[0][0];s.choose_reward(0)
	check(s.rewards==[expected] and s.reward_choices.size()==1,"first choice consumes only first queue item")
	s.choose_reward(1);s.choose_reward(0)
	check(s.rewards.size()==2 and s.selected_rewards.size()==2 and s.reward_choices.is_empty(),"empty queue cannot grant a third reward")
	s.cells=[];s.money=0;s.rewards=["resonant_buffer"]
	for i in range(4):s.cells.append(s.make_cell("tackle",Vector2(i*100,0)))
	var before_id=s.next_id
	check(not s.purchase(0,Vector2.ZERO,true),"full roster refuses incompatible free reward")
	check(s.next_id==before_id and s.rewards==["resonant_buffer"] and s.money==0,"refused free reward preserves offer, money and ID sequence")
	s.cells[0]=s.make_cell("resonant_buffer",Vector2.ZERO)
	check(s.purchase(0,Vector2.ZERO,true) and s.cells.size()==4 and s.cells[0].rank==2,"free reward can merge at capacity")
	check(s.money==0 and s.rewards.is_empty(),"free reward never charges purchase price")
	check(not s.purchase(0,Vector2.ZERO,true),"consumed reward cannot be purchased again")
	s.selected_rewards=["resonant_buffer"];s.shop_rules.reward_chance=0.01
	var reward_draws=0
	for i in range(1000):
		var probe=RandomNumberGenerator.new();probe.state=s.rng.state
		var expected_reward=probe.randf()<0.01
		var drawn=s.draw_offer()
		if drawn=="resonant_buffer":reward_draws+=1
		if (drawn=="resonant_buffer")!=expected_reward:
			check(false,"each shop position uses its own 1% reward roll");break
	check(reward_draws>0 and reward_draws<40,"deterministic sample contains rare returning rewards")
	for mode in range(4):
		var m=Sim.new();m.training_mode=mode;m.reset(42,12)
		for i in range(15):m.queue_reward()
		check(m.reward_choices.all(func(c):return c.size()==2 and c[0]!=c[1] and m.available_cell_keys().has(c[0]) and m.available_cell_keys().has(c[1])),"mode filters every reward choice %d"%mode)
	print("RESULT: rewards, %d failures"%failures)
	quit(1 if failures else 0)
