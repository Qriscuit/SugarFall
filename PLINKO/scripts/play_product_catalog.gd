extends RefCounted

const REMOVE_ADS_PRODUCT = "remove_ads"
const PRODUCTS = ["sugarfall_bakery_ability", "sugarfall_gelato_ability", "sugarfall_crystal_ability", REMOVE_ADS_PRODUCT]

static func purchase_option(product_id: String) -> String:
	return "remove-ads" if product_id == REMOVE_ADS_PRODUCT else "early-unlock"
