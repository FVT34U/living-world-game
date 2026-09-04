@tool
extends EditorPlugin

## Registers the ECS addon as a togglable Godot plugin.
## Deliberately does not add any autoload or dock: ECSWorld is meant to be
## instantiated by the consuming project's own scene, not injected globally.

func _enter_tree() -> void:
	pass

func _exit_tree() -> void:
	pass
