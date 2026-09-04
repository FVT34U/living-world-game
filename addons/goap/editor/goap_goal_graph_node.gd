@tool
extends GraphNode

## Leaf GoapGoal editor node: name, target_resource picker, priority, and a
## dynamic list of desired_state dict rows, all editable in-graph. Every
## field write goes straight into the backing `goal` resource - the host
## editor (goap_goal_graph_editor.gd) only needs to read that resource back
## and the node's position at save time.

var goal: GoapGoal

var _name_edit: LineEdit
var _resource_picker: Control
var _priority_spin: SpinBox
var _state_rows_box: VBoxContainer
var _state_rows: Array[Dictionary] = []  # [{row, key_edit, value_edit}]

const ResourceTypePickerScript := preload("res://addons/goap/editor/goap_resource_type_picker.gd")

## Call once, right after `.new()`, before adding this node to the GraphEdit.
func setup(p_goal: GoapGoal) -> void:
	goal = p_goal
	_build_ui()

func _build_ui() -> void:
	title = goal.goal_name if goal.goal_name != "" else "Goal"

	_name_edit = LineEdit.new()
	_name_edit.text = goal.goal_name
	_name_edit.placeholder_text = "goal_name"
	_name_edit.text_changed.connect(_on_name_changed)
	add_child(_name_edit)
	set_slot_enabled_left(0, false)
	set_slot_enabled_right(0, true)
	set_slot_type_right(0, 0)
	set_slot_color_right(0, Color(0.5, 0.8, 0.5))

	_resource_picker = ResourceTypePickerScript.new()
	_resource_picker.custom_minimum_size = Vector2(160, 0)
	add_child(_resource_picker)
	_resource_picker.resource_picked.connect(_on_target_resource_picked)
	_resource_picker.set_selected_resource(goal.target_resource)

	_priority_spin = SpinBox.new()
	_priority_spin.min_value = -1000
	_priority_spin.max_value = 1000
	_priority_spin.step = 0.1
	_priority_spin.value = goal.priority
	_priority_spin.value_changed.connect(_on_priority_changed)
	add_child(_priority_spin)

	_state_rows_box = VBoxContainer.new()
	add_child(_state_rows_box)
	for key in goal.desired_state.keys():
		_add_state_row(String(key), goal.desired_state[key])

	var add_btn := Button.new()
	add_btn.text = "+ Add State"
	add_btn.pressed.connect(func() -> void: _add_state_row("", true))
	add_child(add_btn)

func _on_name_changed(text: String) -> void:
	goal.goal_name = text
	title = text if text != "" else "Goal"

func _on_target_resource_picked(resource: GoapResourceType) -> void:
	goal.target_resource = resource

func _on_priority_changed(value: float) -> void:
	goal.priority = value

func _add_state_row(key: String, value: Variant) -> void:
	var row := HBoxContainer.new()
	var key_edit := LineEdit.new()
	key_edit.text = key
	key_edit.placeholder_text = "fact key"
	key_edit.custom_minimum_size = Vector2(90, 0)
	var value_edit := LineEdit.new()
	value_edit.text = str(value)
	value_edit.placeholder_text = "true/false/value"
	value_edit.custom_minimum_size = Vector2(70, 0)
	var remove_btn := Button.new()
	remove_btn.text = "x"
	row.add_child(key_edit)
	row.add_child(value_edit)
	row.add_child(remove_btn)
	_state_rows_box.add_child(row)

	var row_data := {"row": row, "key_edit": key_edit, "value_edit": value_edit}
	_state_rows.append(row_data)

	key_edit.text_changed.connect(func(_t: String) -> void: _sync_state_dict())
	value_edit.text_changed.connect(func(_t: String) -> void: _sync_state_dict())
	remove_btn.pressed.connect(func() -> void:
		_state_rows.erase(row_data)
		row.queue_free()
		_sync_state_dict()
	)

func _sync_state_dict() -> void:
	var new_state: Dictionary = {}
	for row_data in _state_rows:
		var key: String = (row_data["key_edit"] as LineEdit).text.strip_edges()
		if key == "":
			continue
		new_state[key] = _parse_value((row_data["value_edit"] as LineEdit).text)
	goal.desired_state = new_state

static func _parse_value(text: String) -> Variant:
	var trimmed := text.strip_edges()
	if trimmed == "true":
		return true
	if trimmed == "false":
		return false
	if trimmed.is_valid_float():
		return trimmed.to_float()
	return trimmed
