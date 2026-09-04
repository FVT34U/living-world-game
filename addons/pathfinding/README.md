# Pathfinding

Grid-based 2D pathfinding for Godot 4, behind an abstract provider interface, plus a frame-budgeted async request queue so many simultaneous NPC path requests don't spike a single frame.

**Zero dependency on the `ecs` or `goap` addons.** `PathfindingService` only ever hands back a `PackedVector2Array` via a `Callable` you supply - it never touches entities, components, or GOAP actions.

## Install

1. Copy `addons/pathfinding` into your project's `addons/` folder.
2. Project Settings → Plugins → enable **Pathfinding**.
3. No autoload. Instantiate `PathfindingService` + a provider yourself.

## Core concepts

- **PathfindingProvider**: abstract interface (`setup`, `world_to_cell`, `cell_to_world`, `set_obstacle`, `find_path`, `find_path_ids`, `is_within_bounds`).
- **Grid2DPathfinder**: the provided implementation, wrapping Godot's built-in `AStarGrid2D`.
- **PathfindingService**: a `Node` that queues `request_path()` calls and resolves a bounded number per frame (`max_requests_per_frame`), calling your callback with the resulting path.

## Usage

```gdscript
var provider := Grid2DPathfinder.new()
provider.setup({
    "region": Rect2i(0, 0, 64, 64),
    "cell_size": Vector2(16, 16),
    "diagonal_mode": AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES,
})
provider.set_obstacle(Vector2i(5, 5), true)

var service := PathfindingService.new()
service.provider = provider
add_child(service)

service.request_path(Vector2(0, 0), Vector2(300, 300), func(path: PackedVector2Array) -> void:
    print("got path with %d points" % path.size())
)
```

## Performance notes

- Default mode is a single-threaded, per-frame-budgeted queue (`max_requests_per_frame`). This avoids `AStarGrid2D`'s documented thread-safety hazard entirely and is fast enough for a settlement-sized map.
- If profiling with real NPC counts shows this is a bottleneck, an advanced `WorkerThreadPool`-based mode is possible but requires either (a) a `Mutex` around every call into the shared `AStarGrid2D` (both reads via `find_path` and writes via `set_obstacle`/`reconfigure`), or (b) giving each worker its own `Grid2DPathfinder` built from the same static obstacle data if the grid rarely changes at runtime. Not implemented by default - add it only if you've measured the need.
- `AStarGrid2D.update()` (called internally by `setup()`/`reconfigure()`) clears all point data. `Grid2DPathfinder` keeps its own obstacle dictionary and re-applies it automatically, so calling `reconfigure()` at runtime is safe.
- Path-following (walking an entity along the returned array) is intentionally not part of this addon - see `game/systems/path_follow_system.gd` for an ECS-based example.

## Reuse in 3D projects

`PathfindingProvider` stays `Vector2`/`Vector2i`-typed rather than boxed through `Variant`, since a 3D project can't reuse 2D grid coordinates regardless. To reuse this pattern in 3D, define an equivalent `PathfindingProvider3D` (Vector3/Vector3i) mirroring this method shape, backed by Godot's `NavigationServer3D` or your own grid.
