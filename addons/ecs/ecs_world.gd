class_name ECSWorld
extends Node

## Entity/component/system container.
##
## Not an autoload: instantiate this as a node in your own scene (see
## addons/ecs/README.md). Entities are plain recycled int ids; components are
## registered by Script once to obtain a stable int type-id used for all
## storage lookups (no string hashing in hot paths).

var _free_indices: Array[int] = []
var _alive: Array[bool] = []
var _next_index: int = 0

var _type_registry: Dictionary = {}          # Script -> int type_id (setup-time only)
var _storages: Array[ComponentStorage] = []  # indexed by type_id

var _process_systems: Array[System] = []
var _physics_systems: Array[System] = []

# ---------------------------------------------------------------------------
# Entities
# ---------------------------------------------------------------------------

func create_entity() -> int:
	var id: int
	if _free_indices.is_empty():
		id = _next_index
		_next_index += 1
		_alive.append(true)
	else:
		id = _free_indices.pop_back()
		_alive[id] = true
	return id

func destroy_entity(entity: int) -> void:
	if not is_alive(entity):
		return
	for storage in _storages:
		storage.remove(entity)
	_alive[entity] = false
	_free_indices.append(entity)

func is_alive(entity: int) -> bool:
	return entity < _alive.size() and _alive[entity]

# ---------------------------------------------------------------------------
# Components
# ---------------------------------------------------------------------------

## Registers a component type (its Script) once and returns a stable int id.
## Call this at bootstrap and cache the returned id - do not call per-frame.
func register_component(script: Script) -> int:
	if _type_registry.has(script):
		return _type_registry[script]
	var id := _storages.size()
	_type_registry[script] = id
	_storages.append(ComponentStorage.new())
	return id

func add_component(entity: int, type_id: int, component: Object) -> void:
	_storages[type_id].add(entity, component)

func remove_component(entity: int, type_id: int) -> void:
	_storages[type_id].remove(entity)

func has_component(entity: int, type_id: int) -> bool:
	return _storages[type_id].has(entity)

func get_component(entity: int, type_id: int) -> Object:
	return _storages[type_id].get_comp(entity)

## Fills out_entities (a caller-owned, reusable buffer) with every entity that
## has every component type in type_ids. Iterates the smallest matching pool
## and does O(1) sparse-set membership checks against the rest.
func query_into(type_ids: Array[int], out_entities: Array[int]) -> void:
	out_entities.resize(0)
	if type_ids.is_empty():
		return
	var driver_id: int = type_ids[0]
	var driver_size := _storages[driver_id].size()
	for tid in type_ids:
		var sz := _storages[tid].size()
		if sz < driver_size:
			driver_size = sz
			driver_id = tid
	var driver := _storages[driver_id]
	for e in driver.dense_entities:
		var ok := true
		for tid in type_ids:
			if tid != driver_id and not _storages[tid].has(e):
				ok = false
				break
		if ok:
			out_entities.append(e)

# ---------------------------------------------------------------------------
# Systems
# ---------------------------------------------------------------------------

func add_system(system: System) -> void:
	var bucket := _process_systems if system.phase == System.Phase.PROCESS else _physics_systems
	bucket.append(system)
	bucket.sort_custom(func(a: System, b: System) -> bool: return a.priority < b.priority)

func _process(delta: float) -> void:
	for s in _process_systems:
		s.update(self, delta)

func _physics_process(delta: float) -> void:
	for s in _physics_systems:
		s.update(self, delta)
