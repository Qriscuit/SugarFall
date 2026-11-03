extends SceneTree
## Reproducible headless checkpoint stress evidence, not device validation.
## Run safely with: bash tests/run_codec_stress.sh
## Game instances use testing=true and are not attached to the SceneTree, so
## automatic lifecycle, save and audio setup do not run during these fixtures.
const Main = preload("res://scripts/main.gd")
const Codec = preload("res://scripts/run_snapshot.gd")
const FLOAT_TOLERANCE = 1e-9
var failures = []
var samples = 0
var runs = 0
var trial_runs = 0
var malformed_checks = 0
var rng_boundary_checks = 0
var flags = {"negative_hp":false,"negative_spawn":false,"negative_combo":false,"negative_pickup":false,"shards":false,"time_cap":false,"last_half_second":false,"zero_life_pickup":false}
func _initialize():
	var configs = [ [[0,0,0,0,0,0,0,0],[]], [[2,2,1,1,1,1,0,0],["ricochet","splitter"]], [[10,10,6,6,6,6,8,10],["impact","splitter"]] ]
	for config in configs:
		for board in range(1,13):
			var game = make_game(board,config)
			game.start_shift()
			for tick in range(5500):
				if game.mode != "play": break
				# Collect every available pickup, including a checkpoint before removal.
				for pickup in game.pickups:
					game.collect_pickups(pickup.p)
					if pickup.life == 0: flags.zero_life_pickup=true
				if tick % 10 == 0: sample(game,board,tick)
				if tick % 120 == 0:
					for kind in game.equipped: game.queue_module(kind)
				game.aim_x=66.0+float((tick*3)%588)
				game.step(1.0/60.0)
				for peg in game.pegs:
					if peg.hp < 0: flags.negative_hp=true
				for ball in game.balls:
					if ball.kind=="shard": flags.shards=true
				if game.spawn_clock < 0: flags.negative_spawn=true
				if game.combo_timer < 0: flags.negative_combo=true
				if game.pickup_clock < 0: flags.negative_pickup=true
				if game.time_bonus >= 10: flags.time_cap=true
				if game.remaining > 0 and game.remaining < .5: flags.last_half_second=true
			runs += 1
			game.free()
	for board in [4,8,12]:
		var config = configs[1]
		var game = make_game(board,config)
		game.trial_active=true
		game.start_shift()
		for tick in range(1500):
			if game.mode != "play": break
			game.step(1.0/60.0)
			if tick%30==0 and game.mode=="play": sample(game,board,tick)
		trial_runs += 1
		game.free()
	var game = make_game(1,configs[0])
	game.start_shift()
	game.mode="abandon_confirm"
	sample(game,1,0)
	var good=Codec.capture(game)
	for key in good:
		for bad in [null,true,{},NAN,INF]:
			var changed=good.duplicate(true)
			changed[key]=bad
			malformed_checks += 1
			if Codec.validate_and_decode(changed,game).ok: failures.append("accepted malformed: "+key)
	for value in ["9223372036854775807", "-9223372036854775808", "0", "-5520495837382843786"]:
		var changed=good.duplicate(true)
		changed.rng_state=value
		rng_boundary_checks += 1
		if not Codec.validate_and_decode(changed,game).ok: failures.append("rejected valid RNG "+value)
	for value in ["9223372036854775808", "-9223372036854775809", "18446744073709551615", "001", "+1", "", "1.0"]:
		var changed=good.duplicate(true)
		changed.rng_state=value
		rng_boundary_checks += 1
		if Codec.validate_and_decode(changed,game).ok: failures.append("accepted invalid RNG "+value)
	game.free()
	print("CODEC_STRESS campaign_runs=",runs," trial_runs=",trial_runs," samples=",samples," malformed_checks=",malformed_checks," rng_boundary_checks=",rng_boundary_checks," float_tolerance=",FLOAT_TOLERANCE)
	print("CODEC_STRESS flags=",flags)
	print("CODEC_STRESS failures=",failures)
	quit(0 if failures.is_empty() else 1)
func sample(game,board,tick):
	var encoded=Codec.capture(game)
	var roundtrip=JSON.parse_string(JSON.stringify(encoded,"",true,true))
	var result=Codec.validate_and_decode(roundtrip,game)
	if not result.ok:
		if failures.size()<30: failures.append("board%d tick%d: %s" % [board,tick,result.reason])
	else:
		if result.state.rng_state != str(game.rng.state): failures.append("RNG state mismatch")
		if result.state.rng_seed != str(game.rng.seed): failures.append("RNG seed mismatch")
		if result.state.run_id != game.run_id: failures.append("Run identity mismatch")
		for key in Codec.STATE_FIELDS:
			if not deep_equal(result.state[key],game.get(key)):
				failures.append("board%d tick%d: round-trip mismatch in %s" % [board,tick,key])
		# Both generators are detached copies. Checking continuation does not
		# consume randomness from the game whose checkpoint is being inspected.
		var expected_rng = RandomNumberGenerator.new()
		expected_rng.seed = game.rng.seed
		expected_rng.state = game.rng.state
		var resumed_rng = RandomNumberGenerator.new()
		resumed_rng.seed = result.state.rng_seed.to_int()
		resumed_rng.state = result.state.rng_state.to_int()
		for draw in range(4):
			if resumed_rng.randi() != expected_rng.randi(): failures.append("RNG continuation mismatch")
	samples+=1
func make_game(board,config):
	var game=Main.new()
	game.testing=true
	game.board_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/board_design.json")).boards
	game.current_level=board
	game.highest_unlocked=12
	game.levels=config[0].duplicate()
	game.equipped=config[1].duplicate()
	return game
func deep_equal(a,b):
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b))<FLOAT_TOLERANCE
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not deep_equal(a[i],b[i]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not deep_equal(a[key],b[key]): return false
		return true
	return a==b
