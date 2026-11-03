extends SceneTree
func _initialize():
	var all_results=[]
	for variant in ["productive","combined_productive"]:
		var style="bounded_active"
		for seed_value in range(10):
			var g=load("res://scripts/main.gd").new()
			g.testing=true
			g.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
			if variant in ["economy","combined","combined_productive"]:
				g.tuning.merge({"peg_base":2,"peg_level_step":.25,"peg_level_offset":1,"combo_credit_cap":0,"clear_base":40,"clear_per_level":5},true)
			if variant in ["hp","combined","combined_productive"]:
				var hp=[1,1,1,2,2,2,2,3,3,3,4,4]
				for i in range(12):
					g.board_data[i].base_hp=hp[i]
					if i>=9:
						g.board_data[i].armored_count=i-7
						g.board_data[i].armored_hp_multiplier=2
			g.tuning["productive_bins_only"]=true
			var runs=0
			var elapsed=0.0
			var retries=0
			var earned=0
			var purchases=[]
			var trace=[]
			while not g.chapter_complete and runs<60:
				g.start_shift()
				g.rng.seed=1000+seed_value*100+runs
				var t=0.0
				var react=0.0
				var target=Vector2(360,515)
				var bot_rng=RandomNumberGenerator.new()
				bot_rng.seed=9000+seed_value*100+runs
				while g.mode=="play" and t<120:
					if style=="sweep_pulse": g.aim_x=75+fmod(t*90,570)
					elif style=="bounded_active":
						react-=1.0/60
						if react<=0:
							react=.4
							var next=null
							for p in g.pegs:
								if p.hp>0 and (next==null or p.p.y<next.p.y): next=p
							if next!=null: target=next.p
							for pickup in g.pickups:
								if pickup.life>0 and pickup.p.distance_to(Vector2(g.aim_x,g.aim_y))<=250*pickup.life and bot_rng.randf()<.75: target=pickup.p
						var position=Vector2(g.aim_x,g.aim_y).move_toward(target,250.0/60)
						g.aim_x=position.x
						g.aim_y=position.y
						g.collect_pickups(position)
					else:
						var next=null
						for p in g.pegs:
							if p.hp>0 and (next==null or p.p.y<next.p.y): next=p
						if next!=null:
							g.aim_x=next.p.x
							g.aim_y=next.p.y
						for pickup in g.pickups: g.collect_pickups(pickup.p)
					if g.pulse_charge>=.99: g.pulse()
					g.step(1.0/60)
					t+=1.0/60
				trace.append({"board":g.current_level,"seconds":t,"earned":g.shift_coins,"levels":g.levels.duplicate(),"stats":g.special_stats.duplicate()})
				elapsed+=t
				runs+=1
				if not g.level_won: retries+=1
				earned+=g.shift_coins
				g.collect_reward(false)
				# Deterministic no-ad shopping: cheapest useful permanent upgrade, capped
				# targets. Early core/rate, one each special, modest clock/bounce/bin.
				var targets=[8,8,2,1,1,1,2,2]
				while true:
					var best=-1
					for i in range(8):
						if g.levels[i]>=targets[i] or g.upgrade_cost(i)>g.bank: continue
						if best<0 or g.upgrade_cost(i)<g.upgrade_cost(best): best=i
					if best<0: break
					g.buy_upgrade(best)
					purchases.append(best)
				# Choose owned family-relevant module plus the other available module.
				var preferred=["ricochet","splitter","impact"] if g.current_level<7 else (["splitter","ricochet","impact"] if g.current_level<10 else ["impact","splitter","ricochet"])
				for kind in g.equipped.duplicate(): g.toggle_module(kind)
				for kind in preferred:
					if g.equipped.size()<g.module_slots(): g.toggle_module(kind)
			var row={"style":style,"variant":variant,"seed":seed_value,"completed":g.chapter_complete,"runs":runs,"retries":retries,"gameplay_seconds":elapsed,"earned":earned,"bank":g.bank,"levels":g.levels.duplicate(),"purchase_count":purchases.size(),"trace":trace}
			all_results.append(row)
			print(JSON.stringify(row))
			g.free()
	var f=FileAccess.open("res://tests/productive_ablation_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(all_results,"\t"))
	f.close()
	quit()
