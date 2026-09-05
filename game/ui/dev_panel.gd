class_name DevPanel
extends CanvasLayer

## In-game developer panel: spawns or removes any NPC/building at a clicked
## map position, and shows live population counts. Purely a game-layer debug
## tool - it only ever goes through EntityFactory/Game, the same entry points
## the normal bootstrap uses, so it can't get ECS/GOAP state out of sync with
## the rest of the sim. Toggle with F1.

const REMOVE_PICK_RADIUS := 28.0

const SPAWNABLE := [
	{"key": "settler_woodcutter", "label": "+ Settler: Woodcutter"},
	{"key": "settler_hunter", "label": "+ Settler: Hunter"},
	{"key": "boar", "label": "+ Boar"},
	{"key": "deer", "label": "+ Deer"},
	{"key": "plant", "label": "+ Plant"},
	{"key": "sawmill", "label": "+ Sawmill"},
	{"key": "storage", "label": "+ Storage"},
]

var _world: ECSWorld
var _parent: Node2D
var _pending_kind: String = ""
var _remove_mode: bool = false

var _status_label: Label
var _stats_label: Label

func setup(world: ECSWorld, parent: Node2D) -> void:
	_world = world
	_parent = parent
	_build_ui()
	visible = false

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(220, 0)
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Dev Panel (F1)"
	vbox.add_child(title)

	for entry in SPAWNABLE:
		var btn := Button.new()
		btn.text = entry["label"]
		btn.pressed.connect(_on_spawn_pressed.bind(entry["key"]))
		vbox.add_child(btn)

	var remove_btn := CheckButton.new()
	remove_btn.text = "Remove mode (click to delete)"
	remove_btn.toggled.connect(_on_remove_toggled)
	vbox.add_child(remove_btn)

	_status_label = Label.new()
	vbox.add_child(_status_label)

	_stats_label = Label.new()
	vbox.add_child(_stats_label)

func _on_spawn_pressed(kind: String) -> void:
	_remove_mode = false
	_pending_kind = kind
	_status_label.text = "Click the map to place: %s" % kind

func _on_remove_toggled(pressed: bool) -> void:
	_remove_mode = pressed
	_pending_kind = ""
	_status_label.text = "Click an NPC/building to remove it" if pressed else ""

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		visible = not visible
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos: Vector2 = _parent.get_global_mouse_position()
		if _remove_mode:
			_try_remove_at(world_pos)
		elif _pending_kind != "":
			_spawn_at(world_pos, _pending_kind)
			_pending_kind = ""
			_status_label.text = ""
		get_viewport().set_input_as_handled()

func _spawn_at(pos: Vector2, kind: String) -> void:
	match kind:
		"settler_woodcutter":
			EntityFactory.spawn_settler(_world, _parent, pos, &"woodcutter")
		"settler_hunter":
			EntityFactory.spawn_settler(_world, _parent, pos, &"hunter")
		"boar":
			EntityFactory.spawn_animal(_world, _parent, pos, &"boar")
		"deer":
			EntityFactory.spawn_animal(_world, _parent, pos, &"deer")
		"plant":
			EntityFactory.spawn_plant(_world, _parent, pos)
		"sawmill":
			EntityFactory.spawn_building(_world, _parent, pos, &"sawmill")
		"storage":
			EntityFactory.spawn_building(_world, _parent, pos, &"storage")

func _try_remove_at(pos: Vector2) -> void:
	var buf: Array[int] = []
	_world.query_into([Game.POSITION_TYPE], buf)
	var best := -1
	var best_dist := REMOVE_PICK_RADIUS
	for e in buf:
		var p: PositionComponent = _world.get_component(e, Game.POSITION_TYPE)
		var d := p.pos.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = e
	if best != -1:
		Game.despawn_entity(_world, best)

func _process(_delta: float) -> void:
	if visible:
		_stats_label.text = _build_stats()

func _build_stats() -> String:
	var settlers: Array[int] = []
	var animals: Array[int] = []
	var plants: Array[int] = []
	var buildings: Array[int] = []
	_world.query_into([Game.SETTLER_ROLE_TYPE], settlers)
	_world.query_into([Game.ANIMAL_TYPE], animals)
	_world.query_into([Game.PLANT_TYPE], plants)
	_world.query_into([Game.BUILDING_TYPE], buildings)
	return "Settlers: %d   Animals: %d\nPlants: %d   Buildings: %d" % [
		settlers.size(), animals.size(), plants.size(), buildings.size(),
	]
