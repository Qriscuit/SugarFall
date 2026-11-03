extends SceneTree
func game():
	var g=load("res://scripts/main.gd").new()
	g.testing=true; g.sound_on=false
	g.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	g.tuning.merge({"core_step":.5,"core_cost_growth":1.55,"clock_base_cost":15},true)
	var counts=[8,12,16,18,20,22,24,26,28,30,32,34]
	for i in range(12):
		g.board_data[i].peg_count=counts[i]
		if i<3:g.board_data[i].family="compact"
	return g
func run(g,seed_value):
	g.start_shift(); g.rng.seed=seed_value
	var t=0.0
	var reaction=0.0
	var target=Vector2(360,515)
	while g.mode=="play" and t<120:
		reaction-=1.0/60
		if reaction<=0:
			reaction=.4
			var next=null
			for p in g.pegs:
				if p.hp>0 and (next==null or p.p.y<next.p.y): next=p
			if next!=null: target=next.p
		var pos=Vector2(g.aim_x,g.aim_y).move_toward(target,250.0/60)
		g.aim_x=pos.x;g.aim_y=pos.y
		g.collect_pickups(pos)
		if g.pulse_charge>=.99: g.pulse()
		if g.queued_special=="" and pos.distance_to(target)<20:
			for kind in g.equipped:
				if g.queue_module(kind): break
		g.step(1.0/60);t+=1.0/60
	var hp_remaining=0.0
	for p in g.pegs: hp_remaining+=maxf(0,p.hp)
	return {"board":g.wave,"won":g.level_won,"seconds":t,"credits":g.shift_coins,"destroyed":g.destroyed,"pegs":g.pegs.size(),"hp_remaining":hp_remaining,"levels":g.levels.duplicate()}
func _initialize():
	var chapters=[]
	for scenario in range(20):
		var seed_value=scenario%10
		var policy="threshold_then_feed_clock" if scenario<10 else "freeze_after_board5"
		var g=game()
		var trace=[]
		var total_time=0.0
		var retries=0
		var first_purchase=0
		for attempt in range(100):
			var row=run(g,2000+seed_value*1000+attempt)
			total_time+=row.seconds
			if not row.won: retries+=1
			g.collect_reward(false)
			for kind in ["ricochet","splitter","impact"]:g.claim_module(kind)
			var buys=[]
			var targets=[10,4,0,0,0,0,0,10]
			while true:
				var best=-1
				for i in range(8):
					if g.levels[i]>=targets[i] or g.upgrade_cost(i)>g.bank:continue
					if best<0 or g.upgrade_cost(i)<g.upgrade_cost(best):best=i
				if g.levels[1]<4:
					best=1 if g.upgrade_cost(1)<=g.bank else -1
				if policy=="freeze_after_board5" and g.current_level>5:best=-1
				if best<0:break
				g.buy_upgrade(best);buys.append(best)
			if first_purchase==0 and not buys.is_empty():first_purchase=attempt+1
			row["buys"]=buys;row["bank_after"]=g.bank;trace.append(row)
			var preferred=["ricochet","splitter","impact"] if g.current_level<7 else (["splitter","ricochet","impact"] if g.current_level<10 else ["impact","splitter","ricochet"])
			for kind in g.equipped.duplicate():g.toggle_module(kind)
			for kind in preferred:
				if g.equipped.size()<g.module_slots():g.toggle_module(kind)
			if g.chapter_complete:break
		var result={"policy":policy,"seed":seed_value,"completed":g.chapter_complete,"final_board":g.current_level,"attempts":trace.size(),"retries":retries,"seconds":total_time,"first_purchase_attempt":first_purchase,"trace":trace}
		chapters.append(result);print(JSON.stringify({"policy":policy,"seed":seed_value,"completed":g.chapter_complete,"final_board":g.current_level,"attempts":trace.size(),"retries":retries,"seconds":total_time,"first_purchase_attempt":first_purchase}));g.free()
	var f=FileAccess.open("res://tests/v04_freeze_ablation_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"chapters":chapters},"\t"));f.close();quit()
