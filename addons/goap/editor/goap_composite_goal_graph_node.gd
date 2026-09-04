@tool
extends GraphNode

## Composite GoapCompositeGoal editor node: name, AND/OR mode, priority, and
## one input-port row per current sub_goals slot (plus a trailing "+" button
## to add another empty slot). The host editor (goap_goal_graph_editor.gd)
## resolves the actual connections into `sub_goals` at save time - this node
## only needs to expose how many slots exist and let their labels be updated
## to reflect what's wired in.

var goal: GoapCompositeGoal

var _name_edit: LineEdit
var _mode_option: OptionButton
var _priority_spin: SpinBox
var _slot_labels: Array[Label] = []
var _add_slot_btn: Button

## Call once, right after `.new()`, before adding this node to the GraphEdit.
func setup(p_goal: GoapCompositeGoal) -> void:
	goal = p_goal
	_build_ui()

func _build_ui() -> void:
	title = goal.goal_name if goal.goal_name != "" else "Composite Goal"

	_name_edit = LineEdit.new()
	_name_edit.text = goal.goal_name
	_name_edit.placeholder_text = "goal_name"
	_name_edit.text_changed.connect(_on_name_changed)
	add_child(_name_edit)
	set_slot_enabled_left(0, false)
	set_slot_enabled_right(0, true)
	set_slot_type_right(0, 0)
	set_slot_color_right(0, Color(0.5, 0.6, 0.9))

	_mode_option = OptionButton.new()
	_mode_option.add_item("ALL (AND)")
	_mode_option.add_item("ANY (OR)")
	_mode_option.select(0 if goal.mode == GoapCompositeGoal.Mode.ALL else 1)
	_mode_option.item_selected.connect(_on_mode_selected)
	add_child(_mode_option)

	_priority_spin = SpinBox.new()
	_priority_spin.min_value = -1000
	_priority_spin.max_value = 1000
	_priority_spin.step = 0.1
	_priority_spin.value = goal.priority
	_priority_spin.value_changed.connect(_on_priority_changed)
	add_child(_priority_spin)

	_add_slot_btn = Button.new()
	_add_slot_btn.text = "+ Add Sub-goal Slot"
	_add_slot_btn.pressed.connect(_add_slot_row)
	add_child(_add_slot_btn)

	var initial_slots: int = maxi(goal.sub_goals.size(), 1)
	for i in initial_slots:
		_add_slot_row()

func _on_name_changed(text: String) -> void:
	goal.goal_name = text
	title = text if text != "" else "Composite Goal"

func _on_mode_selected(index: int) -> void:
	goal.mode = GoapCompositeGoal.Mode.ALL if index == 0 else GoapCompositeGoal.Mode.ANY

func _on_priority_changed(value: float) -> void:
	goal.priority = value

## Appends one more empty sub-goal input row/slot, keeping the "+" button last.
func _add_slot_row() -> void:
	remove_child(_add_slot_btn)
	var label := Label.new()
	label.text = "Sub-goal %d (unconnected)" % _slot_labels.size()
	add_child(label)
	var slot_index := get_child_count() - 1
	set_slot_enabled_left(slot_index, true)
	set_slot_type_left(slot_index, 0)
	set_slot_color_left(slot_index, Color(0.5, 0.6, 0.9))
	set_slot_enabled_right(slot_index, false)
	_slot_labels.append(label)
	add_child(_add_slot_btn)

func slot_count() -> int:
	return _slot_labels.size()

## Updates a slot row's label to show the connected sub-goal's live name -
## called by the host editor after resolving a connection change.
func set_slot_label(slot_index: int, sub_goal_name: String) -> void:
	if slot_index < 0 or slot_index >= _slot_labels.size():
		return
	var display := sub_goal_name if sub_goal_name != "" else "(unconnected)"
	_slot_labels[slot_index].text = "Sub-goal %d: %s" % [slot_index, display]
