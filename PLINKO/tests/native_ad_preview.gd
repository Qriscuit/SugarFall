extends SceneTree
## Native ad UI states only; this renderer fixture never invokes a native SDK.
const QA = preload("res://tests/native_ad_integration_qa.gd")
const Service = preload("res://scripts/native_ad_service.gd")
const ResultUI = preload("res://scripts/result_comparison_ui.gd")
var captures: Array=[]
var failures: Array=[]
class PreviewGame extends "res://scripts/main.gd":
	var profile_accesses=0
	func _ready():
		testing=true;sound_on=false
		load_presentation();food_art.load_assets();set_active_area("bakery")
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _notification(_what): pass
	func _input(_event): pass
	func save_game(): profile_accesses+=1;return false
	func load_game(): profile_accesses+=1

func _initialize(): call_deferred("capture")

func capture():
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output=arg.trim_prefix("--output-dir=")
	if not output.is_absolute_path() or DisplayServer.get_name()=="headless": quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport=SubViewport.new();viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=PreviewGame.new();viewport.add_child(game)
	for resolution in [Vector2i(450,800),Vector2i(720,1280)]:
		viewport.size=resolution;game.scale=Vector2.ONE*float(resolution.x)/720.0
		for state in ["ready","loading","no-fill","privacy-error","earned","confirm"]:
			game.first_run_guide.reset();game.run_transition.finish();game.page_transition.enabled=false
			game.mode="result";game.shift_claimed=false;game.run_id="native-ui-fixture";game.run_area_id="bakery"
			game.bank=50;game.shift_coins=100;game.destroyed=12;game.result_peg_total=24;game.max_combo=4
			game.native_ad_message=""
			if game.native_ad_service!=null: game.native_ad_service.free()
			var provider=QA.FakeProvider.new()
			var service=Service.new(provider,func(): return true)
			game.native_ad_service=service;service.initialize({})
			if state=="loading": provider.inventory.rewarded=false
			if state=="no-fill": provider.inventory.rewarded=false;provider.error={"rewarded":{"message":"No fill"}}
			if state=="privacy-error": game.native_ad_message="Ad privacy setup is unavailable. Try again later."
			if state=="earned":
				service.request("rewarded","bakery",game.run_id,"render-fixture")
				provider.reward_earned.emit(service.pending.id,{"amount":1})
			if state=="confirm": game.mode="bonus_confirm"
			var detail: String=game.reward_ad_detail()
			if game.font.get_string_size(detail,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x>ResultUI.BONUS_RECT.size.x-20: failures.append(state+": inline detail exceeds its action")
			if ResultUI.COLLECT_RECT.intersects(ResultUI.BONUS_RECT): failures.append("Collect and ad actions overlap")
			game.queue_redraw()
			await process_frame;await RenderingServer.frame_post_draw
			var filename="%s-%dx%d.png" % [state,resolution.x,resolution.y]
			if viewport.get_texture().get_image().save_png(output.path_join(filename))!=OK: failures.append(filename+": save failed")
			captures.append({"file":filename,"label":game.reward_ad_label(),"detail":detail})
	if game.profile_accesses!=0: failures.append("UI fixture accessed a profile")
	game.native_ad_service.free();game.native_ad_service=null
	var report={"captures":captures,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"note":"Actual game result/confirmation rendering with a fake provider; no native ad display or device acceptance implied."}
	var file=FileAccess.open(output.path_join("preview-summary.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
	print("NATIVE_AD_PREVIEW captures=",captures.size()," failed=",failures.size())
	quit(0 if failures.is_empty() else 1)
