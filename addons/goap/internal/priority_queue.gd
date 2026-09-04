class_name GoapPriorityQueue
extends RefCounted

## Array-based binary min-heap keyed by `.f` on pushed objects.
## GDScript has no built-in priority queue; a linear scan-for-min over a
## plain Array would be O(n) per pop, which matters once search width is
## capped but still large.

var _items: Array = []

func is_empty() -> bool:
	return _items.is_empty()

func size() -> int:
	return _items.size()

func push(node: Object) -> void:
	_items.append(node)
	var i := _items.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if _items[parent].f <= _items[i].f:
			break
		var tmp = _items[parent]
		_items[parent] = _items[i]
		_items[i] = tmp
		i = parent

func pop() -> Object:
	var top = _items[0]
	var last = _items.pop_back()
	if not _items.is_empty():
		_items[0] = last
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := i * 2 + 2
			var smallest := i
			if l < _items.size() and _items[l].f < _items[smallest].f:
				smallest = l
			if r < _items.size() and _items[r].f < _items[smallest].f:
				smallest = r
			if smallest == i:
				break
			var tmp = _items[smallest]
			_items[smallest] = _items[i]
			_items[i] = tmp
			i = smallest
	return top
