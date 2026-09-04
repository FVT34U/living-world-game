class_name PathfindingService
extends Node

## Frame-budgeted, single-threaded async pathfinding request queue.
##
## This is the recommended default over a WorkerThreadPool-based approach:
## AStarGrid2D.get_point_path() is documented as not thread-safe, and actual
## grid searches on a settlement-sized map are sub-millisecond - the real
## cost of "many NPCs requesting paths" is one frame paying for all of them,
## which this queue solves by spreading requests across frames instead.
##
## Not an autoload: instantiate and assign `provider` yourself.

@export var max_requests_per_frame: int = 6

var provider: PathfindingProvider

var _queue: Array[PathRequest] = []

func request_path(from: Vector2, to: Vector2, callback: Callable) -> void:
	var req := PathRequest.new()
	req.from = from
	req.to = to
	req.callback = callback
	_queue.append(req)

func pending_count() -> int:
	return _queue.size()

func _process(_delta: float) -> void:
	if provider == null:
		return
	var n := mini(max_requests_per_frame, _queue.size())
	for i in n:
		var req: PathRequest = _queue.pop_front()
		var path := provider.find_path(req.from, req.to)
		req.callback.call(path)
