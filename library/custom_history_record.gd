extends Reference

# Custom History Record for rotate object
# v1.0.0
var type = "scale_pattern"
var main_script = null
var node_data: Dictionary
const ENABLE_LOGGING = true
const LOGGING_LEVEL = 0

func outputlog(msg,level=0):
	if ENABLE_LOGGING:
		if level <= LOGGING_LEVEL:
			printraw("(%d) <ScalePatternTexture>: " % OS.get_ticks_msec())
			print(msg)
	else:
		pass

# Function to look at a node and determine what type it is based on its properties
func get_node_type(node):

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

# Function to update the nodes 
func update_nodes_to_data_dictionary(data: Dictionary, type: String):

	outputlog("update_nodes_to_data_dictionary: " + str(data),2)
	var node
	var node_id

	# For each entry in the history record
	for node_id_string in data.keys():
		node_id = int(node_id_string.replace("node-id-",""))
		if Global.World.HasNodeID(node_id):
			node = Global.World.GetNodeByID(node_id)
			if get_node_type(node) == "pattern_shapes":
				node.scale = data[node_id_string][type]["scale"]
				node.polygon = data[node_id_string][type]["points"]
				node.position = data[node_id_string][type]["position"]

func undo():

	outputlog("undo: " + str(node_data),2)

	update_nodes_to_data_dictionary(node_data, "old")

func redo():

	outputlog("redo: " + str(node_data),2)

	update_nodes_to_data_dictionary(node_data, "new")


