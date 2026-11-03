extends RefCounted
## Difficulty and income are separate budgets. These rules need no extra saved
## per-peg counters: cumulative earned credit is derived from HP already saved.

static func hit_damage(power: float, ball_kind: String, used: bool, peg_kind: String, tuning: Dictionary) -> float:
	if ball_kind=="shard": return power*.5
	if ball_kind=="impact" and not used:
		var key="impact_armored_multiplier" if peg_kind=="armored" else "impact_damage_multiplier"
		return power*float(tuning.get(key,6.0 if peg_kind=="armored" else 4.0))
	return power

static func damage_budget(peg_kind: String, tuning: Dictionary) -> int:
	return maxi(0,int(tuning.get("armored_damage_coin_budget",9) if peg_kind=="armored" else tuning.get("peg_damage_coin_budget",6)))

static func earned_damage_coins(max_hp: float, hp: float, budget: int) -> int:
	if max_hp<=0.0 or budget<=0: return 0
	if hp<=0.0: return budget
	# Only cumulative whole coins are paid. The epsilon absorbs floating point
	# error at exact boundaries; repeated fractional hits cannot round up income.
	var fraction=clampf((max_hp-hp)/max_hp,0.0,1.0)
	return clampi(floori(float(budget)*fraction+0.0000001),0,budget)

static func damage_coins(max_hp: float, before_hp: float, after_hp: float, budget: int) -> int:
	return maxi(0,earned_damage_coins(max_hp,after_hp,budget)-earned_damage_coins(max_hp,before_hp,budget))
