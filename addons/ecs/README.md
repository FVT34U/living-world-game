# ECS

Lightweight, general-purpose Entity Component System for Godot 4 (GDScript).

**Zero dependency on the `goap` or `pathfinding` addons, or on any 2D/3D specifics.** Entities are plain integers, components are plain data objects — nothing here references `CanvasItem`, `Node2D`, `Node3D`, or any game-domain type. Safe to copy into any Godot project, 2D or 3D.

## Install

1. Copy `addons/ecs` into your project's `addons/` folder.
2. Project Settings → Plugins → enable **ECS**.
3. There is no autoload. Instantiate `ECSWorld` yourself wherever your game wants it (usually one node under your main scene).

## Core concepts

- **Entity**: a plain `int`. No object, no Node.
- **Component**: a plain data class, `extends RefCounted`, with `class_name`. Holds only data, no logic.
- **System**: `extends System` (from this addon), holds logic that runs over entities matching a component query.
- **World** (`ECSWorld`): owns entities, component storages, and the system schedule.

## Usage

```gdscript
# 1. Define a component (pure data)
class_name PositionComponent
extends RefCounted
var pos: Vector2 = Vector2.ZERO

# 2. Define a system (pure logic)
class_name GravitySystem
extends System

var _pos_type: int
var _buf: Array[int] = []

func _init(pos_type: int) -> void:
    super._init(0, System.Phase.PROCESS)
    _pos_type = pos_type

func update(world: ECSWorld, delta: float) -> void:
    world.query_into([_pos_type], _buf)
    for e in _buf:
        var p: PositionComponent = world.get_component(e, _pos_type)
        p.pos.y += 100.0 * delta

# 3. Wire it up, e.g. in a bootstrap script attached to a Node in your scene
var world := ECSWorld.new()
add_child(world)

var pos_type := world.register_component(PositionComponent)
world.add_system(GravitySystem.new(pos_type))

var e := world.create_entity()
world.add_component(e, pos_type, PositionComponent.new())
```

## Performance notes

- Component types are registered once at setup to get an `int` type-id; every runtime lookup uses that int, never a string.
- `query_into()` fills a buffer array you own and reuse across frames instead of allocating a new Array every call — always pass the same `Array[int]` member variable from your system.
- Component storage is a sparse set: O(1) add/remove/lookup, and iteration walks a densely packed array (no gaps to skip).
- `get_component()` on an entity that doesn't have that component type logs an error and returns `null` rather than reading past the end of its backing array - always guard with `has_component()` (or a `query_into()` that already includes the type) before calling it on an entity you haven't just created.
- Entities use a free-list, no generation/handle-safety packing yet (see Roadmap). A held entity id can be silently reassigned to an unrelated entity after the original is destroyed - if you cache one across frames (a "current target" on a component, say), re-validate both `is_alive()` *and* that it still has the component type you expect before trusting it, not just `is_alive()` alone.

## Roadmap / not included in phase 1

- Generation-tagged entity handles (pack a generation counter into the high bits of the int id) to detect stale entity references after reuse. Not needed for a single-world game with disciplined `destroy_entity` usage, but worth adding if entity ids escape into long-lived external references.
