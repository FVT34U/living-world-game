@tool
extends Control

## Small wrapper isolating a real editor-only risk: EditorResourcePicker is
## only registered in the editor binary, not export templates, and cannot be
## referenced as a static type in a script that might parse outside it - so
## it's instantiated via ClassDB.instantiate("EditorResourcePicker") (a
## string, never a static EditorResourcePicker type reference anywhere in
## this file). Falls back to an OptionButton scanning the project for
## GoapResourceType .tres assets if that instantiation fails.
##
## Built eagerly in _init() (not _ready()) so a caller can call
## set_selected_resource() immediately after `.new()`, before this control
## is even added to a scene tree.

signal resource_picked(resource: GoapResourceType)

var _picker: Control
var _fallback_button: OptionButton
var _fallback_paths: Array[String] = []

func _init() -> void:
	var instance: Object = ClassDB.instantiate("EditorResourcePicker")
	if instance is Control:
		_picker = instance
		_picker.set("base_type", "GoapResourceType")
		_picker.connect("resource_changed", _on_picker_resource_changed)
		add_child(_picker)
	else:
		_build_fallback()

func set_selected_resource(resource: GoapResourceType) -> void:
	if _picker:
		_picker.set("edited_resource", resource)
	elif _fallback_button:
		var idx := _fallback_paths.find(resource.resource_path) if resource else -1
		_fallback_button.select(idx + 1)  # +1 to account for the leading "<none>" entry

func _on_picker_resource_changed(resource: Resource) -> void:
	resource_picked.emit(resource as GoapResourceType)

func _build_fallback() -> void:
	_fallback_button = OptionButton.new()
	_fallback_button.add_item("<none>")
	var found: Array[String] = []
	_scan_dir_recursive("res://", found)
	for path in found:
		var res: Resource = load(path)
		if res is GoapResourceType:
			var label: String = res.display_name if res.display_name != "" else path.get_file()
			_fallback_button.add_item(label)
			_fallback_paths.append(path)
	_fallback_button.item_selected.connect(_on_fallback_selected)
	add_child(_fallback_button)

func _scan_dir_recursive(path: String, out_files: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if not entry_name.begins_with("."):
			var full := path.path_join(entry_name)
			if dir.current_is_dir():
				_scan_dir_recursive(full, out_files)
			elif entry_name.ends_with(".tres"):
				out_files.append(full)
		entry_name = dir.get_next()
	dir.list_dir_end()

func _on_fallback_selected(index: int) -> void:
	if index <= 0:
		resource_picked.emit(null)
		return
	var res: Resource = load(_fallback_paths[index - 1])
	resource_picked.emit(res as GoapResourceType)
