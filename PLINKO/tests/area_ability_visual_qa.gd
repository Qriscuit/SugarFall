extends "res://tests/area_completion_visual_qa.gd"
## Direct signature-card purchases through the actual portrait renderer, no saves.
const SIZES=[Vector2i(450,800),Vector2i(450,1000)]
const Access=preload("res://scripts/area_ability_access.gd")

class AbilityPreview extends AuditPreview:
	var drawn_buttons: Array[Dictionary]=[]
	var drawn_labels: Array[Dictionary]=[]
	var inside_button=Rect2()
	var inside_label=Rect2()
	func record_text(value: String,pos: Vector2,size: int,face: Font):
		if inside_label.has_area() and not value.is_empty():
			var ink=Rect2(pos-Vector2(0,face.get_ascent(size)),Vector2(face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x,face.get_height(size)))
			if not inside_label.grow(.01).encloses(ink): text_overflows.append("Fitted card text exceeds its allocated box: "+value)
		if inside_button.has_area() and not value.is_empty():
			var ink=Rect2(pos-Vector2(0,face.get_ascent(size)),Vector2(face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x,face.get_height(size)))
			if not inside_button.grow(-14).encloses(ink): text_overflows.append("Button text lacks safe inset: "+value)
		super.record_text(value,pos,size,face)
	func button(rect,label,primary=false,subtitle="",painter: CanvasItem=null):
		drawn_buttons.append({"rect":rect,"label":label})
		inside_button=rect
		super.button(rect,label,primary,subtitle,painter)
		inside_button=Rect2()
	func fitted_text(value,rect: Rect2,size=24,color=WHITE,align_center=false,painter: CanvasItem=null):
		drawn_labels.append({"value":str(value),"rect":rect,"size":size})
		inside_label=rect if mode=="shop" and upgrade_map.twin_selected and upgrade_map.TWIN_CARD_RECT.encloses(rect) else Rect2()
		super.fitted_text(value,rect,size,color,align_center,painter)
		inside_label=Rect2()

class LocalizedStore extends RefCounted:
	var pending=false
	func has_entitlement(_product): return false
	func offer(_product): return {"available":true,"pending":pending,"price_label":"R$ 14,99","error":""}
	func purchase(_product): return {}
	func restore(): pass

func _initialize(): call_deferred("run")

func stage(game,area: String):
	game.page_transition.enabled=false
	game.ability_access=Access.new(true)
	prepare(game,area)
	game.update_safe_area()
	game.current_level=1;game.highest_unlocked=1;game.levels.fill(0);game.bank=0
	game.gelato_shop_revision=0
	if area=="gelato": game.ensure_gelato_shop_state()
	game.ability_unlock_source="earned";game.bakery_jam_burst=false;game.bakery_run={}
	game.ability_ui.stage="details";game.ability_ui.message=""
	game.pause_transition.settle()

func capture(game,output: String,name: String,resolution: Vector2i):
	game.drawn_buttons.clear();game.drawn_labels.clear()
	await snap(root,game,output,name,resolution)
	var controls=game.drawn_buttons
	var aligned=true
	for i in range(controls.size()):
		aligned=aligned and Rect2(0,0,720,1280).encloses(controls[i].rect)
		for j in range(i+1,controls.size()):
			if controls[i].rect!=controls[j].rect: aligned=aligned and not controls[i].rect.intersects(controls[j].rect)
	check(aligned,name+" controls fit without overlap")
	var labels: Array[String]=[]
	for item in game.drawn_labels: labels.append(item.value)
	check(not "Unlock options" in labels,name+" has no unlock-options detour")
	if game.mode=="home":
		check(not labels.any(func(value): return value.contains("$2.99") or value.contains("Earn from tray 8") or value=="Purchased"),name+" Home contains no area purchase offer")
	elif game.mode=="shop" and game.upgrade_map.twin_selected:
		var m=game.upgrade_map
		check(m.TWIN_CARD_RECT.encloses(m.TWIN_BUY_RECT) and m.TWIN_CARD_RECT.encloses(m.TWIN_PAID_RECT) and m.TWIN_PAID_RECT.position.y>m.TWIN_BUY_RECT.end.y,name+" two purchase slots stack inside the same card")
		check(m.focus_area().end.y+24<=m.card_rect().position.y,name+" camera focus remains clear of the card")
		if game.ability_ui.owned(): check("Owned" in labels and not labels.any(func(value): return value.begins_with("Buy ")),name+" owned card has no repeated purchase action")
		elif game.ability_ui.card_confirming(): check("Confirm test" in labels and "Cancel" in labels and "No charge" in labels,name+" test confirmation stays in the purchase card")
		else:
			var offer=game.ability_access.offer(game.area_id,false)
			check("Buy "+game.credits_text(game.ability_ui.cost()) in labels,name+" coin price is always shown directly")
			check(("Restore" if game.ability_ui.can_restore() else ("Pending" if offer.pending else "Buy "+offer.price_label)) in labels,name+" paid or restore action is directly below coins")
		for line in m._twin_effect_lines(): check(line in labels,name+" retains effect disclosure: "+line)
	observations[-1]["labels"]=labels

func show_card(game):
	game.mode="shop";game.upgrade_map.reset_view_state();game.upgrade_map.update(0)
	game.upgrade_map.twin_selected=true;game.upgrade_map.selected=-1
	var nodes: Array[Vector2i]=[game.upgrade_map.TWIN_NODE]
	game.upgrade_map._frame_nodes(nodes);game.upgrade_map._finish_camera()
	game.upgrade_map._card_bounce_age=-1;game.navigation_delay=0

func run():
	var output=output_directory()
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless":
		push_error("Ability visual QA requires an absolute output folder and actual GPU renderer");quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	var game=AbilityPreview.new();root.add_child(game)
	game.get_viewport().size_changed.connect(game.update_safe_area)
	for resolution in SIZES:
		root.size=resolution
		await process_frame;await process_frame
		for area in ["bakery","gelato","crystal"]:
			stage(game,area)
			await capture(game,output,area+"-ability-home",resolution)
			show_card(game)
			await capture(game,output,area+"-ability-locked",resolution)
			game.ability_ui.buy_from_card()
			check(game.mode=="shop" and game.ability_ui.card_confirming(),area+" real paid action enters inline test confirmation")
			await capture(game,output,area+"-ability-confirm",resolution)
			game.ability_ui.cancel_card_purchase();game.navigation_delay=0
			game.current_level=8;game.highest_unlocked=8;game.bank=5000;game.levels[1]=6 if area=="gelato" else 4
			if area=="gelato": game.gelato_shop_revision=0;game.ensure_gelato_shop_state()
			show_card(game)
			await capture(game,output,area+"-ability-eligible",resolution)
			game.upgrade_map.press(game.upgrade_map.buy_rect().get_center())
			check(game.ability_ui.owned(),area+" rendered eligible card performs its real coin purchase")
			show_card(game)
			await capture(game,output,area+"-ability-owned",resolution)
		stage(game,"gelato");show_card(game)
		var store=LocalizedStore.new();game.ability_access=Access.new(false);game.ability_access.bind_provider(store)
		await capture(game,output,"gelato-ability-localized",resolution)
		store.pending=true
		await capture(game,output,"gelato-ability-pending",resolution)
		stage(game,"bakery");show_card(game)
		game.ability_ui.buy_from_card();game.ability_ui.press_action("confirm")
		game.ability_access.clear_preview_benefits();game.bakery_jam_burst=false
		show_card(game)
		await capture(game,output,"bakery-ability-restore",resolution)
		stage(game,"crystal");show_card(game);game.ability_access=Access.new(false)
		game.ability_ui.buy_from_card()
		await capture(game,output,"crystal-ability-unavailable",resolution)
	check(game.persistence_attempts==0,"Ability renderer never reads or writes player profiles")
	var report={"checks":checks,"failed":failures.size(),"failures":failures,"captures":files,"observations":observations,"profile_io":game.persistence_attempts,"phone_verified":false,"renderer":RenderingServer.get_video_adapter_name()}
	var saved=FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE)
	saved.store_string(JSON.stringify(report,"\t"));saved.close()
	print("AREA_ABILITY_PREVIEW_RESULT passed=%d failed=%d captures=%d"%[checks-failures.size(),failures.size(),files.size()])
	game.free();quit(0 if failures.is_empty() else 1)
