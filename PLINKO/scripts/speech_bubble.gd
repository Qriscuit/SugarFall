extends RefCounted
## Internal speech layout: fit the complete text once, then reveal it without reflow.
## Callers can reshape a bubble through width, padding, typography and corner options.
const FACE = Color("fffaf0")
const EDGE = Color("c9b997")
const INK = Color("443b32")
const ACCENT = Color("3d8673")

static func wrap_text(font: Font, value: String, width: float, size: int) -> Array[String]:
	var lines: Array[String] = []
	for paragraph in value.split("\n"):
		var line = ""
		for word in paragraph.split(" ",false):
			var word_width = font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
			var candidate = word if line.is_empty() else line+" "+word
			if not line.is_empty() and font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > width:
				lines.append(line)
				line = ""
			# Long tokens must fit too, including future localized text.
			if word_width > width:
				for character in word:
					if not line.is_empty() and font.get_string_size(line+character,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > width:
						lines.append(line)
						line = ""
					line += character
			else:
				line += (" " if not line.is_empty() else "")+word
		lines.append(line)
	return lines

static func measure(font: Font, title_font: Font, value: String, title: String, hint_reserve: String, options: Dictionary = {}) -> Dictionary:
	var font_size = int(options.get("font_size",26))
	var title_size = int(options.get("title_size",25))
	var hint_size = int(options.get("hint_size",20))
	var padding = float(options.get("padding",23.0))
	var max_width = float(options.get("max_width",410.0))
	var min_width = minf(max_width,float(options.get("min_width",264.0)))
	var line_height = maxf(font.get_height(font_size),float(options.get("line_height",33.0)))
	var text_width = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var desired = clampf(sqrt(maxf(1.0,text_width)*line_height*3.8)+padding*2,min_width,max_width)
	var lines = wrap_text(font,value,desired-padding*2,font_size)
	var content_width = maxf(title_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x,font.get_string_size(hint_reserve,HORIZONTAL_ALIGNMENT_LEFT,-1,hint_size).x)
	for line in lines:
		content_width = maxf(content_width,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
	var width = clampf(ceilf(content_width+padding*2),min_width,max_width)
	var starts: Array[int] = []
	var search_from = 0
	for line in lines:
		var offset = value.find(line,search_from)
		starts.append(maxi(search_from,offset))
		search_from = starts.back()+line.length()
	var body_top = padding+title_font.get_height(title_size)+8.0
	var hint_top = body_top+lines.size()*line_height+10.0
	var size = Vector2(width,ceilf(hint_top+font.get_height(hint_size)+padding))
	return {"size":size,"lines":lines,"starts":starts,"text":value,"title":title,"font":font,"title_font":title_font,
		"font_size":font_size,"title_size":title_size,"hint_size":hint_size,"padding":padding,
		"line_height":line_height,"body_top":body_top,"hint_top":hint_top,"radius":float(options.get("radius",30.0))}

static func _tail(rect: Rect2, anchor: Vector2, radius: float) -> PackedVector2Array:
	# A tapered, curved tail ends beside the speaker's mouth. Body covers its seam.
	var left = anchor.x < rect.get_center().x
	var edge_x = rect.position.x+2 if left else rect.end.x-2
	var base_y = clampf(anchor.y,rect.position.y+radius+12,rect.end.y-radius-12)
	var upper = Vector2(edge_x,base_y-13)
	var lower = Vector2(edge_x,base_y+13)
	var control = Vector2(lerpf(edge_x,anchor.x,.48),base_y)
	var points = PackedVector2Array()
	for i in range(9):
		var t = float(i)/8.0
		points.append(upper.bezier_interpolate(control-Vector2(0,5),anchor-Vector2(0,3),anchor,t))
	for i in range(1,9):
		var t = float(i)/8.0
		points.append(anchor.bezier_interpolate(anchor+Vector2(8,8),control+Vector2(0,17),lower,t))
	return points

static func draw(canvas: CanvasItem, metrics: Dictionary, rect: Rect2, anchor: Vector2, characters: int, hint: String, progress: float):
	var scale_factor = clampf(progress,0.01,1.0)
	canvas.draw_set_transform(anchor*(1.0-scale_factor),0,Vector2.ONE*scale_factor)
	var tail = _tail(rect,anchor,metrics.radius)
	var shadow = StyleBoxFlat.new()
	shadow.bg_color = Color(0,0,0,.12)
	shadow.set_corner_radius_all(int(metrics.radius))
	canvas.draw_style_box(shadow,Rect2(rect.position+Vector2(0,5),rect.size))
	canvas.draw_colored_polygon(tail,FACE)
	canvas.draw_polyline(tail,EDGE,2,true)
	var face = StyleBoxFlat.new()
	face.bg_color = FACE
	face.border_color = EDGE
	face.set_border_width_all(2)
	face.set_corner_radius_all(int(metrics.radius))
	canvas.draw_style_box(face,rect)
	# Remove the body edge across the tail's mouth to keep one continuous balloon.
	canvas.draw_line(tail[0]+Vector2(0,2),tail[tail.size()-1]-Vector2(0,2),FACE,4,true)
	var start = rect.position+Vector2(metrics.padding,metrics.padding)
	canvas.draw_string(metrics.title_font,start+Vector2(0,metrics.title_font.get_ascent(metrics.title_size)),metrics.title,HORIZONTAL_ALIGNMENT_LEFT,-1,metrics.title_size,ACCENT)
	for i in range(metrics.lines.size()):
		var line: String = metrics.lines[i]
		var position = rect.position+Vector2(metrics.padding,metrics.body_top+metrics.font.get_ascent(metrics.font_size)+i*metrics.line_height)
		canvas.draw_string(metrics.font,position,line.substr(0,maxi(0,characters-metrics.starts[i])),HORIZONTAL_ALIGNMENT_LEFT,-1,metrics.font_size,INK)
	canvas.draw_string(metrics.font,rect.position+Vector2(metrics.padding,metrics.hint_top+metrics.font.get_ascent(metrics.hint_size)),hint,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-metrics.padding*2,metrics.hint_size,ACCENT)
	canvas.draw_set_transform(Vector2.ZERO)
