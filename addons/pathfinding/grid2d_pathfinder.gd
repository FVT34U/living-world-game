class_name Grid2DPathfinder
extends PathfindingProvider

## PathfindingProvider implementation wrapping Godot's built-in AStarGrid2D.
##
## Important AStarGrid2D gotcha: calling update() (required after changing
## region/cell_size/offset) CLEARS all point data, resetting every solid/
## weight flag. This wrapper keeps its own `_obstacles` dictionary as the
## source of truth and re-applies it after every update()/reconfigure() call.
##
## AStarGrid2D.get_point_path()/get_id_path() are documented as not
## thread-safe - this class is intended to be driven from the main thread
## (see PathfindingService), not called concurrently from multiple threads.

var _astar := AStarGrid2D.new()
var _cell_size: Vector2 = Vector2(16, 16)
var _region: Rect2i
var _obstacles: Dictionary = {}  # Vector2i -> bool, survives AStarGrid2D.update()

func setup(config: Dictionary) -> void:
	_region = config.get("region", Rect2i(0, 0, 100, 100))
	_cell_size = config.get("cell_size", Vector2(16, 16))
	_astar.region = _region
	_astar.cell_size = _cell_size
	_astar.offset = config.get("offset", _cell_size / 2.0)
	_astar.diagonal_mode = config.get("diagonal_mode", AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES)
	_astar.default_compute_heuristic = config.get("compute_heuristic", AStarGrid2D.HEURISTIC_OCTILE)
	_astar.default_estimate_heuristic = config.get("estimate_heuristic", AStarGrid2D.HEURISTIC_OCTILE)
	_astar.jumping_enabled = config.get("jumping_enabled", false)
	_astar.update()
	_reapply_obstacles()

func _reapply_obstacles() -> void:
	for cell in _obstacles:
		_astar.set_point_solid(cell, _obstacles[cell])

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := (world_pos - _astar.offset) / _cell_size
	return Vector2i(floori(local.x), floori(local.y))

func cell_to_world(cell: Vector2i) -> Vector2:
	return _astar.get_point_position(cell)

func is_within_bounds(world_pos: Vector2) -> bool:
	return _astar.is_in_boundsv(world_to_cell(world_pos))

## solid=true blocks the cell; re-applied automatically after reconfigure().
func set_obstacle(cell: Vector2i, solid: bool) -> void:
	_obstacles[cell] = solid
	if _astar.is_in_boundsv(cell):
		_astar.set_point_solid(cell, solid)

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var from_id := world_to_cell(from)
	var to_id := world_to_cell(to)
	if not (_astar.is_in_boundsv(from_id) and _astar.is_in_boundsv(to_id)):
		return PackedVector2Array()
	# allow_partial_path=true: still move the NPC as close as possible even
	# if the destination is fully unreachable, instead of returning nothing.
	return _astar.get_point_path(from_id, to_id, true)

func find_path_ids(from: Vector2, to: Vector2) -> Array[Vector2i]:
	var from_id := world_to_cell(from)
	var to_id := world_to_cell(to)
	if not (_astar.is_in_boundsv(from_id) and _astar.is_in_boundsv(to_id)):
		return []
	return _astar.get_id_path(from_id, to_id, true)

## Re-runs setup() with a new config; obstacles recorded so far are preserved
## and re-applied (AStarGrid2D.update() would otherwise silently drop them).
func reconfigure(config: Dictionary) -> void:
	setup(config)
