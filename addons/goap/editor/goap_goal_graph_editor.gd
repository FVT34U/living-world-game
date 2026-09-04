@tool
extends Control

## Host control for the "Goal Graph" bottom panel: a GraphEdit canvas plus a
## toolbar to open a folder of GoapGoal/GoapCompositeGoal .tres assets, add
## new ones, wire sub-goal connections, and save everything back to disk.
##
## v1 scope, deliberately cut (see addons/goap/README.md for the full list):
## no undo/redo, folder loading is top-level only (no recursive scan),
## deleting a node never deletes its .tres file, and only the trailing empty
## sub-goal slot can be removed from a composite node.

const GoalNodeScript := preload("res://addons/goap/editor/goap_goal_graph_node.gd")
const CompositeNodeScript := preload("res://addons/goap/editor/goap_composite_goal_graph_node.gd")

var _graph_edit: GraphEdit
var _status_label: Label
var _open_folder: String = ""

var _next_id: int = 0
## node name (String) -> {"resource": GoapGoal, "path": String, "node": GraphNode}
var _node_data: Dictionary = {}

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	custom_minimum_size = Vector2(0, 320)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	var toolbar := HBoxContainer.new()
	vbox.add_child(toolbar)

	var open_btn := Button.new()
	open_btn.text = "Open Folder"
	open_btn.pressed.connect(_on_open_folder_pressed)
	toolbar.add_child(open_btn)

	var new_goal_btn := Button.new()
	new_goal_btn.text = "New Goal"
	new_goal_btn.pressed.connect(_on_new_goal_pressed)
	toolbar.add_child(new_goal_btn)

	var new_composite_btn := Button.new()
	new_composite_btn.text = "New Composite Goal"
	new_composite_btn.pressed.connect(_on_new_composite_pressed)
	toolbar.add_child(new_composite_btn)

	var save_btn := Button.new()
	save_btn.text = "Save All"
	save_btn.pressed.connect(_on_save_all_pressed)
	toolbar.add_child(save_btn)

	_status_label = Label.new()
	_status_label.text = "No folder open."
	toolbar.add_child(_status_label)

	_graph_edit = GraphEdit.new()
	_graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_edit.connection_request.connect(_on_connection_request)
	_graph_edit.disconnection_request.connect(_on_disconnection_request)
	_graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	vbox.add_child(_graph_edit)

# ---------------------------------------------------------------------------
# Toolbar actions
# ---------------------------------------------------------------------------

func _on_open_folder_pressed() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FileMode.FILE_MODE_OPEN_DIR
	dialog.access = EditorFileDialog.Access.ACCESS_RESOURCES
	dialog.dir_selected.connect(func(dir: String) -> void:
		_load_folder(dir)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered_ratio()

func _on_new_goal_pressed() -> void:
	var goal := GoapGoal.new()
	goal.goal_name = "new_goal"
	_create_leaf_node(goal, "", _node_data.size())

func _on_new_composite_pressed() -> void:
	var goal := GoapCompositeGoal.new()
	goal.goal_name = "new_composite_goal"
	_create_composite_node(goal, "", _node_data.size())

func _on_save_all_pressed() -> void:
	if _open_folder == "":
		_status_label.text = "Open a folder first."
		return
	var saved := 0
	var failed := 0
	for node_name in _node_data.keys():
		var entry: Dictionary = _node_data[node_name]
		var node: GraphNode = entry["node"]
		var resource: GoapGoal = entry["resource"]
		resource.editor_graph_position = node.position_offset
		if resource is GoapCompositeGoal:
			_rebuild_sub_goals(node_name, resource)

		var path: String = entry["path"]
		if path == "":
			path = _derive_path(resource.goal_name)
			entry["path"] = path

		var err := ResourceSaver.save(resource, path)
		if err == OK:
			saved += 1
		else:
			failed += 1
			push_error("Failed to save goal '%s' to %s (error %d)" % [resource.goal_name, path, err])

	_status_label.text = "Saved %d goal(s)%s" % [saved, ("" if failed == 0 else " - %d FAILED, see Output" % failed)]

# ---------------------------------------------------------------------------
# Folder loading
# ---------------------------------------------------------------------------

func _load_folder(dir_path: String) -> void:
	_clear_graph()
	_open_folder = dir_path

	var resource_to_node: Dictionary = {}  # Resource -> node_name
	var pending_composites: Array[String] = []

	var dir := DirAccess.open(dir_path)
	if not dir:
		_status_label.text = "Could not open folder: %s" % dir_path
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var cascade_index := 0
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := dir_path.path_join(file_name)
			var res: Resource = load(path)
			if res is GoapCompositeGoal:
				var node_name := _create_composite_node(res, path, cascade_index)
				pending_composites.append(node_name)
				resource_to_node[res] = node_name
				cascade_index += 1
			elif res is GoapGoal:
				var node_name2 := _create_leaf_node(res, path, cascade_index)
				resource_to_node[res] = node_name2
				cascade_index += 1
		file_name = dir.get_next()
	dir.list_dir_end()

	for node_name in pending_composites:
		var entry: Dictionary = _node_data[node_name]
		var composite: GoapCompositeGoal = entry["resource"]
		var composite_node: GraphNode = entry["node"]
		for i in composite.sub_goals.size():
			var sub: GoapGoal = composite.sub_goals[i]
			if sub != null and resource_to_node.has(sub):
				var from_name: String = resource_to_node[sub]
				_graph_edit.connect_node(from_name, 0, node_name, i)
				composite_node.set_slot_label(i, sub.goal_name)

	_status_label.text = "Loaded %d goal(s) from %s" % [resource_to_node.size(), dir_path]

func _clear_graph() -> void:
	_graph_edit.clear_connections()
	for node_name in _node_data.keys():
		(_node_data[node_name]["node"] as GraphNode).queue_free()
	_node_data.clear()
	_next_id = 0

# ---------------------------------------------------------------------------
# Node creation
# ---------------------------------------------------------------------------

func _create_leaf_node(goal: GoapGoal, path: String, cascade_index: int) -> String:
	var node := GoalNodeScript.new()
	var node_name := "n_%d" % _next_id
	_next_id += 1
	node.name = node_name
	node.setup(goal)
	node.position_offset = goal.editor_graph_position if goal.editor_graph_position != Vector2.ZERO else _cascade_position(cascade_index)
	_graph_edit.add_child(node)
	_node_data[node_name] = {"resource": goal, "path": path, "node": node}
	return node_name

func _create_composite_node(goal: GoapCompositeGoal, path: String, cascade_index: int) -> String:
	var node := CompositeNodeScript.new()
	var node_name := "n_%d" % _next_id
	_next_id += 1
	node.name = node_name
	node.setup(goal)
	node.position_offset = goal.editor_graph_position if goal.editor_graph_position != Vector2.ZERO else _cascade_position(cascade_index)
	_graph_edit.add_child(node)
	_node_data[node_name] = {"resource": goal, "path": path, "node": node}
	return node_name

func _cascade_position(index: int) -> Vector2:
	return Vector2(40, 40) + Vector2(30, 30) * maxi(index, 0)

# ---------------------------------------------------------------------------
# Connections
# ---------------------------------------------------------------------------

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	# At most one incoming connection per composite input slot - disconnect
	# whatever was there before accepting the new one.
	for existing in _graph_edit.get_connection_list():
		if existing["to_node"] == to_node and existing["to_port"] == to_port:
			_graph_edit.disconnect_node(existing["from_node"], existing["from_port"], existing["to_node"], existing["to_port"])
			break
	_graph_edit.connect_node(from_node, from_port, to_node, to_port)
	_refresh_slot_label(to_node, to_port, from_node)

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	_graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	if _node_data.has(to_node):
		var node: GraphNode = _node_data[to_node]["node"]
		if node.has_method("set_slot_label"):
			node.set_slot_label(to_port, "")

func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	for node_name in nodes:
		if _node_data.has(node_name):
			(_node_data[node_name]["node"] as GraphNode).queue_free()
			_node_data.erase(node_name)

func _refresh_slot_label(to_node: StringName, to_port: int, from_node: StringName) -> void:
	if not (_node_data.has(to_node) and _node_data.has(from_node)):
		return
	var composite_node: GraphNode = _node_data[to_node]["node"]
	var source_resource: GoapGoal = _node_data[from_node]["resource"]
	if composite_node.has_method("set_slot_label"):
		composite_node.set_slot_label(to_port, source_resource.goal_name)

# ---------------------------------------------------------------------------
# Saving
# ---------------------------------------------------------------------------

func _rebuild_sub_goals(node_name: String, composite: GoapCompositeGoal) -> void:
	var by_port: Dictionary = {}  # to_port -> from_node name
	for conn in _graph_edit.get_connection_list():
		if conn["to_node"] == node_name:
			by_port[conn["to_port"]] = conn["from_node"]

	var composite_node: GraphNode = _node_data[node_name]["node"]
	var new_sub_goals: Array[GoapGoal] = []
	for i in composite_node.slot_count():
		if by_port.has(i):
			var from_name: String = by_port[i]
			if _node_data.has(from_name):
				new_sub_goals.append(_node_data[from_name]["resource"])
	composite.sub_goals = new_sub_goals

func _derive_path(goal_name: String) -> String:
	var sanitized := goal_name.strip_edges().to_lower().replace(" ", "_")
	var regex := RegEx.create_from_string("[^a-z0-9_-]")
	sanitized = regex.sub(sanitized, "", true)
	if sanitized == "":
		sanitized = "goal_%d" % _next_id

	var final_path := _open_folder.path_join(sanitized + ".tres")
	var suffix := 2
	while FileAccess.file_exists(final_path):
		final_path = _open_folder.path_join("%s_%d.tres" % [sanitized, suffix])
		suffix += 1
	return final_path
