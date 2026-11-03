extends RefCounted
## Versioned run rules overlay authored data without changing content fingerprints.
## Callers pin the revision before constructing or validating a saved run.
const LEGACY_REVISION = 1
const CURRENT_REVISION = 2
const WALL_TRAY = 8
const LATE_HP_MULTIPLIER = 1.15
const LATE_REWARD_MULTIPLIER = 1.25
const MAX_REWARD = 100000000

static func valid_revision(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) in [float(LEGACY_REVISION),float(CURRENT_REVISION)]

static func applies(wave: int, trial: bool, revision: int) -> bool:
	return revision==CURRENT_REVISION and wave>=WALL_TRAY and not trial

static func normal_hp(base: float, wave: int, trial: bool, revision: int = CURRENT_REVISION) -> float:
	if not is_finite(base) or base<=0.0: return 0.0
	var result = base*LATE_HP_MULTIPLIER if applies(wave,trial,revision) else base
	return result if is_finite(result) else base

static func damage_budget(base: int, wave: int, trial: bool, revision: int = CURRENT_REVISION) -> int:
	return _reward(base,wave,trial,revision)

static func break_reward(base: int, wave: int, trial: bool, revision: int = CURRENT_REVISION) -> int:
	# Pass the final authored reward, including prism and combo, exactly once.
	return _reward(base,wave,trial,revision)

static func clear_reward(base: int, wave: int, trial: bool, revision: int = CURRENT_REVISION) -> int:
	return _reward(base,wave,trial,revision)

static func _reward(base: int, wave: int, trial: bool, revision: int) -> int:
	var safe = clampi(base,0,MAX_REWARD)
	return mini(MAX_REWARD,roundi(float(safe)*LATE_REWARD_MULTIPLIER)) if applies(wave,trial,revision) else safe
