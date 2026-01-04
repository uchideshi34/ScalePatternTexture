#########################################################################################################
##
## Scale Pattern Texture MOD
##
#########################################################################################################

var script_class = "tool"
var ui_config = {}
var _lib_mod_config

var pattern_scale_slider
var pattern_tex_origin_xslider
var pattern_tex_origin_yslider

var store_last_valid_selection = null

var content_is_hovered = false

var NewHSlider
var history_record = {}
var emit_refresh_node = false

const ENABLE_LOGGING = true

var logging_level = 0

#########################################################################################################
##
## UTILITY FUNCTIONS
##
#########################################################################################################

# Function to see if a structure that looks like a copied dd data entry is the same
func is_the_same(a, b) -> bool:

	if a is Dictionary:
		if not b is Dictionary:
			return false
		if a.keys().size() != b.keys().size():
			return false
		for key in a.keys():
			if not b.has(key):
				return false
			if not is_the_same(a[key], b[key]):
				return false
	elif a is Array:
		if not b is Array:
			return false
		if a.size() != b.size():
			return false
		for _i in a.size():
			if not is_the_same(a[_i], b[_i]):
				return false
	elif a != b:
		return false

	return true

func outputlog(msg,level=0):
	if ENABLE_LOGGING:
		if level <= logging_level:
			printraw("(%d) <ScalePatternTexture>: " % OS.get_ticks_msec())
			print(msg)
	else:
		pass

# Make a button and return it
func make_button(parent_node, icon_path: String, hint_tooltip: String, toggle_mode: bool) -> Button:

	var button = Button.new()
	button.toggle_mode = toggle_mode
	button.icon = load_image_texture(icon_path)
	button.hint_tooltip = hint_tooltip
	parent_node.add_child(button)
	return button

# Function to look at resource string and return the texture
func load_image_texture(texture_path: String):

	var image = Image.new()
	var texture = ImageTexture.new()

	# If it isn't an internal resource
	if not "res://" in texture_path:
		image.load(Global.Root + texture_path)
		texture.create_from_image(image)
	# If it is an internal resource then just use the ResourceLoader
	else:
		texture = ResourceLoader.load(texture_path)
	
	return texture

# Function to look at a node and determine what type it is based on its properties
func get_node_type(node):

	if node == null: return null

	if node.get("WallID") != null:
		return "portals"

	# Note this is also true of portals but we caught those with WallID
	elif node.get("Sprite") != null:
		return "objects"
	elif node.get("FadeIn") != null:
		return "paths"
	elif node.get("HasOutline") != null:
		return "pattern_shapes"
	elif node.get("Joint") != null:
		return "walls"

	return null

# Function to get the texture of a node based on tool_type
func get_asset_texture(node, tool_type: String):
	var texture = null

	match tool_type:
		"ObjectTool","ScatterTool","WallTool","PortalTool","objects","portals","walls":
			texture = node.Texture
		"PathTool", "LightTool","paths","lights":
			texture = node.get_texture()
		"PatternShapeTool","pattern_shapes":
			texture = node._Texture
		"RoofTool","roofs":
			texture = node.TilesTexture
		_:
			return null

	return texture

func pos_mod(x: float, m: float) -> float:
	return fmod(fmod(x, m) + m, m)


#########################################################################################################
##
## UI CREATION FUNCTIONS
##
#########################################################################################################

func make_pattern_scale_slider():

	pattern_scale_slider = NewHSlider.new(Global.Editor.Toolset.GetToolPanel("SelectTool").patternShapeOptions, 1.0, 0.1, 5.0, 0.1)
	pattern_scale_slider.connect("value_changed", self, "on_pattern_scale_slider_changed")
	pattern_scale_slider.connect("emit_history_event_signal", self, "create_update_custom_history")
	Global.Editor.Toolset.GetToolPanel("SelectTool").patternShapeOptions.move_child(pattern_scale_slider.hbox, 0)

	var texturerect = TextureRect.new()
	texturerect.texture = load_image_texture("icons/aspect-ratio-icon.png")
	texturerect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	texturerect.hint_tooltip = "Scale"
	pattern_scale_slider.hbox.add_child(texturerect)
	pattern_scale_slider.hbox.move_child(texturerect,0)

func make_pattern_texture_origin_sliders():

	pattern_tex_origin_yslider = NewHSlider.new(Global.Editor.Toolset.GetToolPanel("SelectTool").patternShapeOptions, 0.0, 0.0, 1.0, 0.001)
	pattern_tex_origin_yslider.connect("value_changed", self, "on_pattern_tex_origin_slider_changed", ["x"])
	pattern_tex_origin_yslider.connect("emit_history_event_signal", self, "create_update_custom_history")
	Global.Editor.Toolset.GetToolPanel("SelectTool").patternShapeOptions.move_child(pattern_tex_origin_yslider.hbox, 0)

	var label_y = Label.new()
	label_y.text = "Y Axis"
	label_y.hint_tooltip = "Texture origin slider for y-axis"
	pattern_tex_origin_yslider.hbox.add_child(label_y)
	pattern_tex_origin_yslider.hbox.move_child(label_y,0)

	pattern_tex_origin_xslider = NewHSlider.new(Global.Editor.Toolset.GetToolPanel("SelectTool").patternShapeOptions, 0.0, 0.0, 1.0, 0.001)
	pattern_tex_origin_xslider.connect("value_changed", self, "on_pattern_tex_origin_slider_changed", ["x"])
	pattern_tex_origin_xslider.connect("emit_history_event_signal", self, "create_update_custom_history")
	Global.Editor.Toolset.GetToolPanel("SelectTool").patternShapeOptions.move_child(pattern_tex_origin_xslider.hbox, 0)

	var label_x = Label.new()
	label_x.text = "X Axis"
	label_x.hint_tooltip = "Texture origin slider for x-axis"
	pattern_tex_origin_xslider.hbox.add_child(label_x)
	pattern_tex_origin_xslider.hbox.move_child(label_x,0)

	var label = Label.new()
	label.text = "Texture Origin"
	Global.Editor.Toolset.GetToolPanel("SelectTool").patternShapeOptions.add_child(label)
	Global.Editor.Toolset.GetToolPanel("SelectTool").patternShapeOptions.move_child(label, 0)


#########################################################################################################
##
## CORE FUNCTIONS
##
#########################################################################################################

# Function to respond when the scale slider is changed
func on_pattern_scale_slider_changed(value: float):

	for node in Global.Editor.Tools["SelectTool"].Selected:
		if get_node_type(node) == "pattern_shapes":
			add_update_history_data(node)
			change_pattern_scale(node, value)
			add_update_history_data(node)
			# If the Colour things mod is loaded
			if emit_refresh_node:
				Global.API.ModSignalingApi.emit_signal("refresh_node_combined_shader", node)
	
	Global.Editor.Tools["SelectTool"].OnFinishSelection()

# Function to change a patterns scale
func change_pattern_scale(pattern: Node2D, scale: float):

	outputlog("change_pattern_scale: " + str(scale),2)

	# store old global points (world space) and desired anchor (use top-left of those points)
	var old_global_points = pattern.GlobalPolygon
	#var desired_anchor_global = get_global_top_left(old_global_points)
	var desired_anchor_global = old_global_points[0]

	pattern.scale = pattern.scale.sign() * scale
	update_pattern_to_new_global_points(pattern, old_global_points)

	transform_pattern_to_desired_global_anchor(pattern, desired_anchor_global)
	
# Function to take a pattern and transform it so the texture aligns to the desired anchor point 
func transform_pattern_to_desired_global_anchor(pattern, desired_anchor_global: Vector2):

	outputlog("transform_pattern_to_desired_global_anchor: ",2)

	# current global position of the pattern's local origin (local (0,0))
	var current_origin_global = pattern.to_global(Vector2.ZERO)

	outputlog("current_origin_global: " + str(current_origin_global),2)
	outputlog("desired_anchor_global: " + str(desired_anchor_global),2)

	# how much we need to move the origin in global space to make it equal desired_anchor_global
	var delta_global = desired_anchor_global - current_origin_global

	if delta_global.length() <= 0.0001:
		# already aligned; nothing to do
		return
	
	var delta_local = pattern.to_local(desired_anchor_global) - pattern.to_local(current_origin_global)

	# Convert to local points
	var current_local_points = pattern.polygon
	var new_local_points = []
	for point in current_local_points:
		new_local_points.append(point - delta_local)

	# set the points (local coordinates)
	pattern.SetPoints(new_local_points, false)

	# finally, move the node origin by delta_global (so local origin maps to desired_anchor_global)
	pattern.position += delta_global

# Function to update a pattern with a set of new global points. Noting that we can't directly update global points, it has to be done via SetPoints
func update_pattern_to_new_global_points(patternshape, new_points):

	outputlog("update_pattern_to_new_global_points",2)
	if patternshape == null:
		return
	
	new_points = move_polygon(new_points, -patternshape.position)

	new_points = rotate_polygon(new_points, Vector2.ZERO, - patternshape.rotation)

	new_points = scale_polygon(new_points, Vector2(1.0 / patternshape.scale.x, 1.0 / patternshape.scale.y))

	patternshape.SetPoints(new_points,false)

# Function to rotate a polygon of Vector2 points around a central point and return a new array of points
func rotate_polygon(polygon, centre: Vector2, phi: float):

	outputlog("rotate_polygon: centre" + str(centre),3)

	if abs(phi) < 0.005:
		return polygon

	var new_points = []
	for point in polygon:
		new_points.append(rotate_point(point, centre, phi))
	
	return new_points

func rotate_point(point: Vector2, centre: Vector2, phi: float):

	return (point - centre).rotated(phi) + centre

# Function to move the points of a polygon in delta direction
func move_polygon(polygon, delta: Vector2):

	outputlog("move_polygon: delta" + str(delta),3)

	var new_points = []
	for point in polygon:
		new_points.append(move_point(point, delta))
	
	return new_points

func move_point(point: Vector2, delta: Vector2):

	return point+delta

# Function to scale the points of a polygon
func scale_polygon(polygon, scale: Vector2):

	outputlog("scale_polygon: scale: " + str(scale),3)

	var new_points = []
	for point in polygon:
		new_points.append(scale_point(point, scale))
	
	return new_points

func scale_point(point: Vector2, scale: Vector2):

	return Vector2(point.x * scale.x, point.y * scale.y)

#########################################################################################################
##
## ADJUST TEXTURE START TO SELECTION
##
#########################################################################################################

func on_pattern_tex_origin_slider_changed(value: float, type: String):

	# Check something is selected and it is a pattern
	if Global.Editor.Toolset.GetToolPanel("SelectTool").patternShapeOptions.visible:
		for pattern in Global.Editor.Tools["SelectTool"].Selected:
			if get_node_type(pattern) == "pattern_shapes":
				update_pattern_tex_origin(pattern, pattern_tex_origin_xslider.value, pattern_tex_origin_yslider.value)

		Global.Editor.Tools["SelectTool"].OnFinishSelection()

# Update a pattern with the new origin uv values
func update_pattern_tex_origin(pattern: Node2D, origin_uv_x: float, origin_uv_y: float):

	outputlog("update_pattern_tex_origin",3)

	var point = Vector2.ZERO
	var tex = get_asset_texture(pattern, "pattern_shapes")
	if tex != null:
		point = Vector2(tex.get_width() * origin_uv_x * pattern.scale.x,tex.get_height() * origin_uv_y * pattern.scale.y)
		point = rotate_point(point, Vector2.ZERO, pattern.rotation)

		transform_pattern_to_desired_global_anchor(pattern, point)
	
	
# Function to get the current uv of the first point of the pattern (which is assumed to be the top left but doesn't need to be)
func get_pattern_origin_uv(pattern):

	outputlog("get_pattern_origin_uv",2)
	var uv = Vector2.ZERO
	var point = Vector2.ZERO

	var current_origin_global = pattern.to_global(Vector2.ZERO)
	
	outputlog("current_origin_global: " + str(current_origin_global))
	var tex = get_asset_texture(pattern, "pattern_shapes")
	outputlog("tex.get_size(): " + str(tex.get_size()),2)
	if tex != null:

		point = Vector2(
			current_origin_global.x / (tex.get_size().x * pattern.scale.x),
			current_origin_global.y / (tex.get_size().y * pattern.scale.y)
		)

		outputlog("point: " + str(point),2)

		uv = Vector2(
			pos_mod(point.x, 1.0),
			pos_mod(point.y, 1.0)
		)

		outputlog("uv: " + str(uv),2)
		return uv
	else:
		return null


func get_pattern_origin_uv_new(pattern):

	outputlog("get_pattern_origin_uv_new: ",2)

	var tex = get_asset_texture(pattern, "pattern_shapes")
	if tex == null:
		return null

	# Local-space offset of texture origin
	var local_origin = pattern.to_local(pattern.to_global(Vector2.ZERO))

	# Undo rotation
	local_origin = local_origin.rotated(-pattern.rotation)

	# Undo scale
	local_origin.x /= pattern.scale.x
	local_origin.y /= pattern.scale.y

	# Convert to UV
	var uv = Vector2(
		pos_mod(local_origin.x / tex.get_width(), 1.0),
		pos_mod(local_origin.y / tex.get_height(), 1.0)
	)

	outputlog("uv: " + str(uv),2)

	return uv



#########################################################################################################
##
## SET UI TO SELECTION
##
#########################################################################################################

func set_pattern_scale_to_selection():

	if Global.Editor.Tools["SelectTool"].Selected.size() > 0:
		if Global.Editor.Toolset.GetToolPanel("SelectTool").patternShapeOptions.visible:
			var pattern = Global.Editor.Tools["SelectTool"].Selected[0]
			if get_node_type(pattern) == "pattern_shapes":
				pattern_scale_slider.slider_and_spinbox_change(min(abs(pattern.scale.x),abs(pattern.scale.y)),true)
				var uv = get_pattern_origin_uv(pattern)
				get_pattern_origin_uv(pattern)
				if uv != null:
					pattern_tex_origin_xslider.slider_and_spinbox_change(uv.x,true)
					pattern_tex_origin_yslider.slider_and_spinbox_change(uv.y,true)

#########################################################################################################
##
## HISTORY RECORD FUNCTIONS FOR UNDO & REDO
##
#########################################################################################################

# Function to take a node id and store their current status so that we can create a before and after data record
func add_update_history_data(node: Node2D):

	outputlog("add_update_history_data",2)

	var node_id_string = "node-id-" + str(node.get_meta("node_id"))

	# If there is no existing record for that node, then create a record, ie do not update if there is an existing record
	if not history_record.has(node_id_string):
		history_record[node_id_string] = {"old": {
			"scale": node.scale,
			"points": node.polygon,
			"position": node.position
		}}

	# Make the new node data record
	history_record[node_id_string]["new"] =  {
			"scale": node.scale,
			"points": node.polygon,
			"position": node.position
		}

# Create custom history record, called when a colour preset is selected, the color picker is closed, or a slider timer finishes
func create_update_custom_history():

	var record_script
	outputlog("create_update_custom_history",2)

	# Create a new record if one is needed or simply update the existing one
	record_script = Script.InstanceReference("library/custom_history_record.gd")

	# If this is null for any reason then return to avoid a crash
	if record_script == null:
		outputlog("record_script is null",2)
		# As the data is invalid, clear the data
		history_record = {}
		return
	
	if is_history_the_same():
		outputlog("no change in history",2)
		outputlog(JSON.print(history_record,"\t"),2)
		# clear the data
		history_record = {}
		return

	record_script.node_data = history_record.duplicate(true)
	record_script.main_script = self

	outputlog("node_data\n" + JSON.print(record_script.node_data,"\t"),2)

	# If this is a new action then create a new custom record
	var record = Global.Editor.History.CreateCustomRecord(record_script)

	# Reset the history record
	history_record = {}

func is_history_the_same() -> bool:

	# For each entry in the history record
	for node_id_string in history_record.keys():
		if not is_the_same(history_record[node_id_string]["old"],history_record[node_id_string]["new"]):
			return false
	
	return true

#########################################################################################################
##
## GUI HOVER FUNCTIONS
##
#########################################################################################################

func update_hover_status_content(active: bool):

	content_is_hovered = active

#########################################################################################################
##
## INPUT CAPTURE FUNCTIONS
##
#########################################################################################################

# If a new node is added
func on_new_node_added_to_world(node: Node2D):

	outputlog("on_new_node_added_to_world: " + str(node),2)

	if node == null:
		return


# Function to respond to unhandled mouse events
func on_unhandled_mouse_event(event):

	outputlog("on_unhandled_mouse_event",4)

		
# Function to respond to unhandled key events
func on_unhandled_key_event(event):

	outputlog("on_unhandled_key_event",4)

# Function to set up the 
func set_up_input_capture():
	var unhandledeventemitter = UnhandledEventEmitter.new()
	unhandledeventemitter.global = Global
	Global.World.add_child(unhandledeventemitter)
	unhandledeventemitter.connect("key_input", self, "on_unhandled_key_event")
	unhandledeventemitter.connect("mouse_input", self, "on_unhandled_mouse_event")

# Class to emit unhandled events
class UnhandledEventEmitter extends Node:

	var global = null

	signal key_input
	signal mouse_input
	signal pan_input

	func _unhandled_input(event):

		if not global.Editor.SearchHasFocus:
			var focus = global.Editor.GetFocus()
			if focus == null || (not focus is LineEdit && not focus is Tree):
				if event is InputEventKey:
					self.emit_signal("key_input", event)

	
	func _input(event):

		if not global.Editor.SearchHasFocus:
			var focus = global.Editor.GetFocus()
			if focus == null || (not focus is LineEdit && not focus is Tree):
				if event is InputEventMouse:
					self.emit_signal("mouse_input", event)
				if event is InputEventPanGesture:
					self.emit_signal("pan_input", event)

#########################################################################################################
##
## Logging configs FUNCTION
##
#########################################################################################################

func make_lib_configs():

	# Create a config builder to ensure we can update the offset if needed
	var _lib_config_builder = Global.API.ModConfigApi.create_config()
	_lib_config_builder\
		.h_box_container().enter()\
			.label("Log Level ")\
			.option_button("log_level", 0, ["0","1","2","3","4"])\
		.exit()
	_lib_mod_config = _lib_config_builder.build()

	logging_level = int(_lib_mod_config.core_log_level)

#########################################################################################################
##
## VERSION CHECKER FUNCTIONS
##
#########################################################################################################

# Check whether a semver strng 2 is greater than string one. Only works on simple comparisons - DO NOT USE THIS FUNCTION OUTSIDE THIS CONTEXT
func compare_semver(semver1: String, semver2: String) -> bool:

	outputlog("compare_semver: semver1: " + str(semver1) + " semver2" + str(semver2),2)
	var semver1data = get_semver_data(semver1)
	var semver2data = get_semver_data(semver2)

	if semver1data == null || semver2data == null : return false

	if semver1data["major"] != semver2data["major"]:
		return semver1data["major"] < semver2data["major"]
	if semver1data["minor"] != semver2data["minor"]:
		return semver1data["minor"] < semver2data["minor"]
	if semver1data["patch"] != semver2data["patch"]:
		return semver1data["major"] < semver2data["major"]
	
	return false

# Parse the semver string
func get_semver_data(semver: String):

	var data = {}

	if semver.split(".").size() < 3: return null

	return {
		"major": int(semver.split(".")[0]),
		"minor": int(semver.split(".")[1]),
		"patch": int(semver.split(".")[2].split("-")[0])
	}


#########################################################################################################
##
## START FUNCTION
##
#########################################################################################################


# Function to check if the selection has changed
func has_selection_changed() -> bool:

	outputlog("has_selection_changed: " + str(Global.Editor.Tools["SelectTool"].Selected),4)

	# Check if it has changed from the stored version and update it if it has changed
	if not is_the_same(store_last_valid_selection, Global.Editor.Tools["SelectTool"].Selected):
		store_last_valid_selection = Global.Editor.Tools["SelectTool"].Selected
		return true
	else:
		return false

# Function called with the selection has changed
func selection_changed():

	outputlog("selection_changed",2)

	set_pattern_scale_to_selection()


func update(delta: float):

	# A new node has been added since we last checked
	if Global.Editor.ActiveToolName == "SelectTool":
		# If the selection has changed then call the selection changed function
		if has_selection_changed():
			selection_changed()

func start() -> void:

	outputlog("ScalePatternTexture Mod Has been loaded.")

	NewHSlider = ResourceLoader.load(Global.Root + "NewHSlider.gd", "GDScript", true)

	make_pattern_scale_slider()
	make_pattern_texture_origin_sliders()

	# If _Lib is installed then register with it
	if Engine.has_signal("_lib_register_mod"):
		# Register this mod with _lib
		Engine.emit_signal("_lib_register_mod", self)
		make_lib_configs()
		# If the ColourThings mod
		if "uchideshi34.ColourAndModifyThings" in Script.GetActiveMods():
			emit_refresh_node = true
		
		var _lib_mod_meta = Global.API.ModRegistry.get_mod_info("CreepyCre._Lib").mod_meta
		if _lib_mod_meta != null:
			if compare_semver("1.1.2", _lib_mod_meta["version"]):
				var update_checker = Global.API.UpdateChecker
				
				update_checker.register(Global.API.UpdateChecker.builder()\
														.fetcher(update_checker.github_fetcher("uchideshi34", "ScalePatternTexture"))\
														.downloader(update_checker.github_downloader("uchideshi34", "ScalePatternTexture"))\
														.build())
	
	
		

	

	
	


















	