class_name PathfindingProvider
extends RefCounted

## Abstract pathfinding provider interface.
##
## Deliberately typed on Vector2/Vector2i rather than genericized through
## Variant - boxing every position would cost real performance for no benefit,
## since a 3D project couldn't reuse Vector2i grid coordinates anyway. What is
## reusable across dimensions is this *method shape*, not this literal class:
## a future 3D project should define its own PathfindingProvider3D (Vector3 /
## Vector3i) mirroring these methods, and a matching Grid3DPathfinder-style
## implementation.

func setup(_config: Dictionary) -> void:
	push_error("PathfindingProvider.setup is abstract")

func is_within_bounds(_world_pos: Vector2) -> bool:
	push_error("PathfindingProvider.is_within_bounds is abstract")
	return false

func world_to_cell(_world_pos: Vector2) -> Vector2i:
	push_error("PathfindingProvider.world_to_cell is abstract")
	return Vector2i.ZERO

func cell_to_world(_cell: Vector2i) -> Vector2:
	push_error("PathfindingProvider.cell_to_world is abstract")
	return Vector2.ZERO

func set_obstacle(_cell: Vector2i, _solid: bool) -> void:
	push_error("PathfindingProvider.set_obstacle is abstract")

func find_path(_from: Vector2, _to: Vector2) -> PackedVector2Array:
	push_error("PathfindingProvider.find_path is abstract")
	return PackedVector2Array()

func find_path_ids(_from: Vector2, _to: Vector2) -> Array[Vector2i]:
	push_error("PathfindingProvider.find_path_ids is abstract")
	return []
