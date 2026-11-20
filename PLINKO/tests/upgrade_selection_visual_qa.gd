extends "res://tests/area_ability_visual_qa.gd"
## Actual selected-node draws and compact cards, with isolated in-memory saves.
const MapArt=preload("res://scripts/upgrade_map.gd")

class RecordedFood extends "res://scripts/food_art.gd":
	var portraits: Array[String]=[]
	func draw(canvas: CanvasItem,name: String,target: Rect2,tint: Color=Color.WHITE,preserve_aspect: bool=true) -> bool:
		if target==MapArt.PORTRAIT_RECT or target==Rect2(-80,-84,160,160): portraits.append(name)
		return super.draw(canvas,name,target,tint,preserve_aspect)

class RecordedMap extends "res://scripts/upgrade_map.gd":
	var price_labels: Array[String]=[]
	var signature_icons=0
	func _label(canvas: CanvasItem,value: String,rect: Rect2,size: int,color: Color,face: Font=null):
		if rect==Rect2(-94,-40,188,80): price_labels.append(value)
		super._label(canvas,value,rect,size,color,face)
	func _draw_twin_icon(canvas: CanvasItem,rect: Rect2,tint: Color):
		signature_icons+=1
		super._draw_twin_icon(canvas,rect,tint)

class SelectionPreview extends AbilityPreview:
	func _ready():
		super._ready()
		food_art=RecordedFood.new();food_art.load_assets()
		upgrade_map=RecordedMap.new(self)

func unlock_power(game) -> Vector2i:
	for step in range(16):
		var power: Vector2i=game.next_shop_node(1)
		if power.x>=0: return power
		var bought=false
		for node in game.upgrade_graph().nodes():
			if not game.shop_node_owned(node.x,node.y) and game.shop_node_unlocked(node.x,node.y):
				bought=game.buy_upgrade_node(node.x,node.y)
				break
		if not bought: break
	return Vector2i(-1,-1)

func frame_node(game,node: Vector2i):
	game.upgrade_map.twin_selected=node==game.upgrade_map.TWIN_NODE
	game.upgrade_map.selected=-1 if game.upgrade_map.twin_selected else node.x
	game.upgrade_map.tier=node.y
	var nodes: Array[Vector2i]=[node]
	game.upgrade_map.zoom=.84
	game.upgrade_map._frame_nodes(nodes);game.upgrade_map._finish_camera()
	game.upgrade_map.update(game.upgrade_map.FEEDBACK_DURATION)
	game.upgrade_map._card_bounce_age=-1;game.note_time=0;game.navigation_delay=0

func selection_capture(game,output: String,name: String,resolution: Vector2i):
	game.food_art.portraits.clear();game.upgrade_map.price_labels.clear();game.upgrade_map.signature_icons=0
	await capture(game,output,name,resolution)
	observations[-1]["selected_price_labels"]=game.upgrade_map.price_labels.duplicate()
	observations[-1]["ordinary_portraits"]=game.food_art.portraits.duplicate()
	observations[-1]["signature_icons"]=game.upgrade_map.signature_icons

func run():
	var output=output_directory()
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("Selected-node visual QA needs absolute output and GPU renderer");quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	var game=SelectionPreview.new();root.add_child(game)
	game.get_viewport().size_changed.connect(game.update_safe_area)
	for resolution in SIZES:
		root.size=resolution;await process_frame;await process_frame
		for area in ["bakery","gelato","crystal"]:
			stage(game,area);game.bank=1000000;game.mode="shop"
			var power=unlock_power(game)
			check(power.x==1,"Legal purchases reveal Power for actual renderer: "+area)
			frame_node(game,power)
			await selection_capture(game,output,area+"-power-selected-affordable",resolution)
			check(game.upgrade_map.price_labels==[game.credits_text(game.upgrade_cost(1))] and not "cookie_armored" in game.food_art.portraits,area+" selected affordable Power draws only required amount on its map tile")
			game.upgrade_map.selected=-1
			await selection_capture(game,output,area+"-power-unselected",resolution)
			check(game.upgrade_map.price_labels.is_empty() and "cookie_armored" in game.food_art.portraits,area+" deselected Power restores map artwork")
			game.upgrade_map.selected=power.x;game.bank=0;game.upgrade_map.update(game.upgrade_map.FEEDBACK_DURATION)
			await selection_capture(game,output,area+"-power-selected-unaffordable",resolution)
			check(game.upgrade_map.state_for(power.x,power.y)=="unaffordable" and game.upgrade_map.price_labels==[game.credits_text(game.upgrade_cost(1))] and not "cookie_armored" in game.food_art.portraits,area+" unaffordable selection retains required amount without artwork")
			game.bank=game.upgrade_cost(1);game.upgrade_map.press(game.upgrade_map.buy_rect().get_center());frame_node(game,power)
			await selection_capture(game,output,area+"-power-selected-owned",resolution)
			check(game.upgrade_map.state_for(power.x,power.y)=="owned" and game.upgrade_map.price_labels.is_empty() and "cookie_armored" in game.food_art.portraits,area+" real purchase restores selected owned artwork and status")
			stage(game,area);show_card(game)
			await selection_capture(game,output,area+"-signature-selected-locked",resolution)
			check(game.upgrade_map.state_for(8,1)=="locked" and game.upgrade_map.price_labels==[game.credits_text(game.ability_ui.cost())] and game.upgrade_map.signature_icons==0,area+" unowned signature uses earned amount while compact card retains gate and paid action")
			game.upgrade_map.twin_selected=false
			await selection_capture(game,output,area+"-signature-unselected",resolution)
			check(game.upgrade_map.price_labels.is_empty() and game.upgrade_map.signature_icons>0,area+" signature artwork returns after deselection")
		stage(game,"bakery");game.mode="shop";game.highest_unlocked=10;game.levels=game.MAX_LEVELS.duplicate();game.bank=game.ability_ui.cost();game.ability_ui.controller().buy()
		game.upgrade_map.reset_view_state();frame_node(game,game.upgrade_map.MORE_JAM_NODE)
		await selection_capture(game,output,"bakery-more-jam-selected-free",resolution)
		check(game.upgrade_map.price_labels==["Free"],"Available selected More Jam displays its Free requirement")
		check(game.bakery_ability.quick_buy(),"Available selected More Jam unlocks through the existing free action")
		game.note_time=0;game.upgrade_map.update(game.upgrade_map.FEEDBACK_DURATION)
		await selection_capture(game,output,"bakery-more-jam-selected-owned",resolution)
		check(game.upgrade_map.price_labels.is_empty(),"Owned More Jam restores its regular status presentation")
	check(game.persistence_attempts==0,"Selected-node renderer never reads or writes player profiles")
	var report={"checks":checks,"failed":failures.size(),"failures":failures,"captures":files,"observations":observations,"profile_io":game.persistence_attempts,"phone_verified":false,"renderer":RenderingServer.get_video_adapter_name()}
	var saved=FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	saved.store_string(JSON.stringify(report,"\t"));saved.close()
	print("UPGRADE_SELECTION_PREVIEW_RESULT passed=%d failed=%d captures=%d"%[checks-failures.size(),failures.size(),files.size()])
	game.free();quit(0 if failures.is_empty() else 1)
