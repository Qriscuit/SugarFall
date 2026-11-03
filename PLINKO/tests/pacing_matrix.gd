extends SceneTree
func _initialize():
	var results=[]
	for stage in [1,4,8,12]:
		for style in ["center_passive","sweep_pulse","targeted_active"]:
			var wins=0
			var coins=0
			var total_time=0.0
			var remaining_pegs=0
			var first_upgrade=0
			for seed_value in range(20):
				var g=load("res://scripts/main.gd").new()
				g.testing=true
				g.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
				g.highest_unlocked=stage
				g.current_level=stage
				match stage:
					1: g.levels=[0,0,0,0,0,0,0,0]
					2: g.levels=[1,1,0,0,0,0,0,0]
					4: g.levels=[3,3,1,1,1,1,1,1]
					8: g.levels=[6,5,3,3,3,3,3,4]
					12: g.levels=[8,7,4,4,4,4,4,5]
				g.equipped=[] if stage==1 else (["ricochet","splitter"] if stage<10 else ["impact","splitter"])
				g.start_shift()
				g.rng.seed=100+seed_value
				var elapsed=0.0
				while g.mode=="play" and elapsed<120:
					if style=="sweep_pulse":
						g.aim_x=75+fmod(elapsed*90,570)
						if g.pulse_charge>=.99: g.pulse()
					elif style=="targeted_active":
						var next=null
						for p in g.pegs:
							if p.hp>0 and (next==null or p.p.y<next.p.y): next=p
						if next!=null:
							g.aim_x=next.p.x
							g.aim_y=next.p.y
						if g.pulse_charge>=.99: g.pulse()
						for pickup in g.pickups: g.collect_pickups(pickup.p)
					g.step(1.0/60)
					elapsed+=1.0/60
				if g.level_won: wins+=1
				coins+=g.shift_coins
				total_time+=elapsed
				if g.shift_coins>=g.upgrade_cost(0): first_upgrade+=1
				for p in g.pegs:
					if p.hp>0: remaining_pegs+=1
				g.free()
			var row={"level":stage,"style":style,"runs":20,"wins":wins,"mean_credits":coins/20.0,"mean_seconds":total_time/20.0,"credits_per_minute":coins/maxf(total_time,.01)*60,"mean_pegs_remaining":remaining_pegs/20.0,"affords_feeder":first_upgrade}
			results.append(row)
			print(JSON.stringify(row))
	var file=FileAccess.open("res://tests/pacing_chapter_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	quit()
