extends SceneTree
func _initialize():
	var results=[]
	for stage in [4,8,12]:
		for module in ["none","ricochet","splitter","impact"]:
			for pulse_enabled in [false,true]:
				var sums={"wins":0,"seconds":0.0,"coins":0,"pulse_kills":0,"special_kills":0,"core_kills":0,"special_drops":0,"remaining":0}
				for seed_value in range(10):
					var g=load("res://scripts/main.gd").new()
					g.testing=true
					g.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
					g.tuning.merge({"peg_base":2,"peg_level_step":.25,"peg_level_offset":1,"combo_credit_cap":0,"clear_base":40,"clear_per_level":5,"min_rebound_speed":160},true)
					var hp=[1,1,1,2,2,2,2,3,3,3,4,4]
					for i in range(12):
						g.board_data[i].base_hp=hp[i]
						if i>=9:
							g.board_data[i].armored_count=i-7
							g.board_data[i].armored_hp_multiplier=2
					g.current_level=stage
					g.highest_unlocked=12
					g.levels=[2,2,1,0,0,0,0,0]
					g.bank=600
					var spent=0
					if module!="none":
						var idx=["ricochet","splitter","impact"].find(module)+3
						while g.buy_upgrade(idx): pass
						spent=600-g.bank
						g.equipped=[module]
					g.start_shift()
					g.rng.seed=7000+seed_value
					var t=0.0
					var reaction=0.0
					var target=Vector2(360,515)
					while g.mode=="play" and t<100:
						reaction-=1.0/60
						if reaction<=0:
							reaction=.4
							var next=null
							for p in g.pegs:
								if p.hp>0 and (next==null or p.p.y<next.p.y): next=p
							if next!=null: target=next.p
						var pos=Vector2(g.aim_x,g.aim_y).move_toward(target,250.0/60)
						g.aim_x=pos.x
						g.aim_y=pos.y
						if pulse_enabled and g.pulse_charge>=.99: g.pulse()
						if module!="none": g.queue_module(module)
						g.step(1.0/60)
						t+=1.0/60
					sums.wins+=int(g.level_won)
					sums.seconds+=t
					sums.coins+=g.shift_coins
					sums.pulse_kills+=g.special_stats.pulse
					sums.core_kills+=g.special_stats.normal
					sums.remaining+=g.pegs.size()-g.destroyed
					for k in ["ricochet","splitter","impact","shard"]:
						sums.special_kills+=g.special_stats[k]
						sums.special_drops+=g.type_drops[k]
					sums["module_spend"]=spent
					g.free()
				var row={"stage":stage,"module":module,"pulse":pulse_enabled,"runs":10,"data":sums}
				results.append(row)
				print(JSON.stringify(row))
	var f=FileAccess.open("res://tests/queued_module_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"\t"))
	f.close()
	quit()
