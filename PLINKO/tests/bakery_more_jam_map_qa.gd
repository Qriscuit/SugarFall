extends "res://tests/v04_map_qa.gd"
## Real map/input path plus authored capstone clearance, with intercepted saves.
const AudioFixture=preload("res://tests/audio_feedback_integration_qa.gd")
const Campaign=preload("res://scripts/area_campaign.gd")

func ready_reward():
	g.set_active_area("bakery"); Campaign.apply_local(g,Campaign.default_record())
	g.testing=true; g.sound_on=true; g.page_transition.enabled=false
	g.first_run_guide.completed=true; g.first_run_guide.active=false
	g.mode="shop"; g.navigation_delay=0; g.result_input_delay=0
	g.shift_claimed=true; g.run_id=""; g.bank=0
	g.levels=g.MAX_LEVELS.duplicate(); g.highest_unlocked=10; g.current_level=10
	g.bakery_jam_burst=true; g.ability_unlock_source="earned"
	m.reset_view_state(); m.update(0); g.clear_heard()

func capstone_geometry():
	var layout=JSON.parse_string(FileAccess.get_file_as_string("res://data/upgrade_layout.json"))
	var cap=m.MORE_JAM_NODE
	var cap_nodes: Array[Vector2i]=[cap]
	check(layout.special_nodes.size()==1 and layout.special_edges.size()==3,"One capstone has three authored tip connections")
	check(m.node_prerequisites(cap)==[Vector2i(1,10),Vector2i(7,10),Vector2i(0,10)],"Capstone joins the actual three route endpoints")
	var cap_position: Vector2=m._positions[cap]
	check(cap_position.x>5000 and cap_position.y>800,"Reward sits beyond Bakery's far route ends")
	var clear=true
	for edge in layout.special_edges:
		var parent=Vector2i(edge.from[0],edge.from[1])
		var points: Array=edge.points
		for index in range(points.size()-1):
			var a=Vector2(points[index][0],points[index][1])
			var b=Vector2(points[index+1][0],points[index+1][1])
			for node in m._positions:
				if node in [parent,cap]: continue
				var rect=Rect2(m._positions[node]-Vector2.ONE*116,Vector2.ONE*232)
				if rect.has_point(a) or rect.has_point(b): clear=false
				var corners=[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
				for side in range(4):
					if Geometry2D.segment_intersects_segment(a,b,corners[side],corners[(side+1)%4])!=null: clear=false
	check(clear,"All three capstone trails avoid unrelated node faces")
	for camera_zoom in [m.MIN_ZOOM,.4,m.INITIAL_ZOOM,m.MAX_ZOOM]:
		m.zoom=camera_zoom; m._frame_nodes(cap_nodes); m._finish_camera(); m._clamp_pan()
		check(m.FOCUS_AREA.encloses(m.node_rect(cap.x,cap.y,false)),"Capstone can be framed clear of controls at zoom "+str(camera_zoom))
	ready_reward()

func _initialize():
	g=AudioFixture.Fixture.new(); m=g.upgrade_map
	g.audio_feedback_requested.connect(g.listen)
	ready_reward()
	var cap=m.MORE_JAM_NODE
	var cap_nodes: Array[Vector2i]=[cap]
	check(m.selected_node()==cap and m.node_in_view(cap.x,cap.y),"Existing maxed tray-10 player opens shop focused on More Jam")
	check(m.state_for(cap.x,cap.y)=="affordable" and m.node_cost(cap)==0,"Free eligible upgrade is green even with zero coins")
	capstone_geometry()
	var p=m.buy_rect().get_center()
	touch(p,0,true); touch(p,0,false,true)
	check(not g.bakery_jam_quick and g.heard.is_empty(),"Canceled unlock tap is inert and silent")
	touch(p,0,true); touch(p,1,true); touch(p,1,false); touch(p,0,false)
	check(not g.bakery_jam_quick and g.heard.is_empty(),"Multitouch cannot unlock More Jam")
	drag(p,p+Vector2(30,0))
	check(not g.bakery_jam_quick,"Dragging the purchase button cannot unlock")
	tap(p)
	check(g.bakery_jam_quick and g.bank==0 and m.state_for(cap.x,cap.y)=="owned","Clean unlock tap claims once with no charge")
	check(g.heard==["upgrade"],"Claim requests exactly one upgrade sound")
	tap(p)
	check(g.heard==["upgrade"] and g.bank==0,"Repeated owned tap is inert")
	check(g.ability_ui.effects()[0].begins_with("Every fourth"),"Owned Jam description reflects the earned improvement")
	ready_reward(); g.highest_unlocked=9
	m.reset_view_state(); m.selected=cap.x; m.tier=cap.y; m._frame_nodes(cap_nodes); m._finish_camera()
	check(m.state_for(cap.x,cap.y)=="locked" and m.more_jam_gate_text()=="Reach tray 10","A maxed tree below tray 10 shows its remaining gate")
	m.press(m.buy_rect().get_center())
	check(not g.bakery_jam_quick and g.mode=="shop","Locked capstone cannot open paid early access")
	ready_reward(); g.levels[0]-=1; m.update(0)
	check(m.state_for(cap.x,cap.y)=="locked" and m.more_jam_gate_text()=="Finish all 3 lanes","Missing final upgrade leaves the capstone locked")
	g.bank=100000; m.selected=0; m.tier=10; m.twin_selected=false
	m.press(m.buy_rect().get_center()); m._finish_camera()
	check(m.selected_node()==cap and m.state_for(cap.x,cap.y)=="affordable","Buying the last lane node selects and reveals the free reward")
	ready_reward(); g.bakery_jam_burst=false; m.update(0)
	check(m.more_jam_gate_text()=="Requires Jam Burst" and m.state_for(cap.x,cap.y)=="locked","Base Jam ability remains required")
	ready_reward(); g.levels.fill(0); g.highest_unlocked=1; m.reset_view_state()
	check(not m.more_jam_visible(),"Starter map does not expose the far-end capstone prematurely")
	for area in ["gelato","crystal"]:
		g.set_active_area(area); Campaign.apply_local(g,Campaign.default_record()); m.reset_view_state()
		check(not m.more_jam_visible() and cap not in m.visible_nodes(),"More Jam is absent in "+area)
	ready_reward(); g.trial_active=true; m.reset_view_state()
	check(not m.more_jam_visible(),"Trials do not expose the campaign upgrade")
	g.free()
	print("MORE_JAM_MAP_QA_RESULT passed=%d failed=%d"%[passed,failed.size()])
	quit(0 if failed.is_empty() else 1)
