@tool
extends EditorPlugin

## Registers the GOAP addon as a togglable Godot plugin, and adds the
## "Goal Graph" bottom panel for visually authoring GoapGoal/GoapCompositeGoal
## .tres assets - see addons/goap/editor/goap_goal_graph_editor.gd.
## No autoload otherwise: GoapPlanner/GoapAgent are plain RefCounted classes
## instantiated and driven by the consuming project.

const GoalGraphEditorScript := preload("res://addons/goap/editor/goap_goal_graph_editor.gd")

var _graph_editor: Control

func _enter_tree() -> void:
	_graph_editor = GoalGraphEditorScript.new()
	add_control_to_bottom_panel(_graph_editor, "Goal Graph")

func _exit_tree() -> void:
	remove_control_from_bottom_panel(_graph_editor)
	_graph_editor.queue_free()
