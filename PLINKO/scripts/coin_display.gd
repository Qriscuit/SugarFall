extends RefCounted
## Presentation only. Balances keep their existing cent precision in gameplay
## and saves; only earned whole coins are shown or described as spendable.

static func whole(amount: float) -> int:
	return maxi(0, int(floorf(roundf(amount * 100.0) / 100.0)))

static func text(amount: float) -> String:
	return str(whole(amount))

static func shortfall_text(amount: float) -> String:
	return str(maxi(0, int(ceilf(roundf(amount * 100.0) / 100.0))))

static func gain(before: float, amount: float) -> int:
	return maxi(0, whole(before + amount) - whole(before))
