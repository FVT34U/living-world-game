# Architecture

## Overview

The project's NPC simulation is built from three independent, reusable Godot addons plus a thin game-layer adapter that wires them together:

```
addons/ecs          - entity/component/system container (generic, no game knowledge)
addons/goap          - goal-oriented action planning (generic, no ECS/pathfinding knowledge)
addons/pathfinding   - grid-based A* pathfinding behind an abstract provider (generic)
game/                - the ONLY layer allowed to know about all three at once
```

Each addon can be copied into a different Godot project (2D or 3D) and used on its own. None of them `preload`, `extend`, or type-hint against another addon's classes. The dependency direction is always: `game/` → addons, never addon → addon.

## Why independence is enforced this way

GOAP needs *something* to plan for and act on, but it never assumes that thing is an ECS entity — every `GoapAction`/`GoapGoal` method receives an opaque `agent_owner: Variant` it just forwards. Pathfinding needs *something* to move, but `PathfindingService` only ever hands back a `PackedVector2Array` through a callback — it never touches an entity or a GOAP plan. This means you could use the GOAP addon with plain Nodes and no ECS at all, or use the ECS addon in a game with no AI, or use the pathfinding addon in a puzzle game with neither.

The cost of this independence is that *someone* has to bridge them for an actual game — that someone is `res://game/`.

## Data flow for one NPC tick

1. `GoapPlanningSystem` (ECS system, priority 0) queries every entity with a `GoapAgentComponent`, and — budgeted to a fixed number per frame — for each one:
   - Calls `Game.build_world_state(world, entity)`, which reads live ECS components (`PositionComponent`, `GoapAgentComponent`) and produces a plain `GoapWorldState` (a `Dictionary` of facts like `at_woodpile`, `has_resource:wood`). This is the ECS → GOAP adapter step.
   - Calls `GoapAgentComponent.agent.tick(entity, state, delta)`, which (re)selects a goal if needed, (re)plans via `GoapPlanner.plan()` if needed, and calls `perform()` on the current action.
2. If the current action is a `MoveToAction` (`game/goap/actions/move_to_action.gd`), `perform()` reads the entity's `PositionComponent` and calls `Game.pathfinding_service.request_path(from, to, callback)`. This is the GOAP → Pathfinding adapter step. The callback stores the resulting path into the entity's `PathFollowComponent`.
3. `PathFollowSystem` (ECS system, priority 10) advances every entity's `PositionComponent` along its `PathFollowComponent.path` each frame, marking `arrived = true` on reaching the end. This is pure ECS, unaware of GOAP or pathfinding beyond the plain array sitting in the component.
4. Once `arrived` is true, `MoveToAction.perform()` (next time it's called) returns `SUCCESS`, and `GoapAgent` advances to the next action in the plan (e.g. `ChopWoodAction`/`HuntAction`, which increment demo "inventory" fields after a short delay).
5. `RenderSyncSystem` (ECS system, priority 20) copies `PositionComponent.pos` into the entity's linked `Sprite2D.global_position` every frame, so the plan's effect on ECS data is visible on screen.

## Data-driven goals and actions

`GoapGoal` and `GoapAction` are Godot `Resource`s, not GDScript objects you build in code. Concretely, in this project:

- `game/resources/goap_resources/*.tres` are `GoapResourceType` assets (`wood`, `meat`) - the abstraction unit a goal or action points at instead of a hand-typed fact string. `GoapResourceType.fact_key()` is the single source of truth for the `GoapWorldState` key (`"has_resource:wood"`), used identically by `Game.build_world_state()` and by any action's `produces_resource`/`requires_resource`.
- `game/resources/goap_actions/*.tres` are configured instances of `MoveToAction`/`ChopWoodAction`/`HuntAction` - e.g. `hunt_boar.tres` and `hunt_deer.tres` both use `hunt_action.gd` but with different `quarry_name`/`hunt_duration`/`cost`, so the planner naturally prefers deer (cheaper) when either would satisfy the same `meat` goal. This is the "one script, many parametrized instances" pattern instead of a subclass per variant.
- `game/resources/goap_goals/*.tres` are `GoapGoal`/`GoapCompositeGoal` instances - `gather_wood_goal.tres`/`gather_meat_goal.tres` are plain leaf goals (`target_resource` set, no subclass needed at all), and `prepare_for_winter_goal.tres` (`mode = ALL`)/`forage_anything_goal.tres` (`mode = ANY`) combine them - see `addons/goap/README.md` for the AND/OR semantics and the `GoapPlanner` alternative-resolution mechanics behind them.
- `game/entity_factory.gd` `preload()`s these templates and `duplicate(true)`s each one per spawned NPC before use - loaded `.tres` Resources are shared/cached objects, so any per-agent mutation (action runtime state, per-NPC goal priority) needs its own copy. See the "Shared Resources need per-agent duplication" section of `addons/goap/README.md`.
- The **Goal Graph Editor** (`addons/goap/editor/`, bottom panel "Goal Graph" once the GOAP plugin is enabled) lets you build/wire/save this kind of goal tree visually instead of hand-editing `.tres` text - point it at `res://game/resources/goap_goals/` to see this project's goals as a graph.

## Where to extend

- **New GOAP action**: write a `GoapAction` subclass under `game/goap/actions/` with `@export` parameters instead of constructor args, then create one or more `.tres` instances of it (New Resource in the FileSystem dock, or hand-author a `.tres` like the ones under `game/resources/goap_actions/`) with `preconditions`/`effects`/`requires_resource`/`produces_resource` set per instance.
- **New GOAP goal**: usually no subclass needed - create a `GoapGoal` (leaf) or `GoapCompositeGoal` (AND/OR of other goals) `.tres` asset directly, via New Resource or the Goal Graph Editor. Only subclass `GoapGoal` for dynamic `get_priority()`/`is_valid()` logic.
- **New abstract resource**: create a `GoapResourceType` `.tres` (id + display name), point any action's `produces_resource`/`requires_resource` and any goal's `target_resource` at it.
- **New component type**: add a plain `RefCounted` class under `game/components/`, register it once via `world.register_component(...)` in `world_bootstrap.gd`, cache the returned id on `Game`.
- **New ECS system**: subclass `System` under `game/systems/`, give it a `priority` reflecting where it should run relative to the existing three, add it via `world.add_system(...)`.
- **Swapping pathfinding for a 3D project**: keep using the `goap` and `ecs` addons unmodified; implement a `PathfindingProvider3D` (Vector3/Vector3i) in a new `pathfinding_3d` addon mirroring `PathfindingProvider`'s method shape, and write a new `MoveToAction`-style adapter for that project.

## Performance mitigations already in place

- ECS: sparse-set component storage (O(1) add/remove/lookup, packed iteration), int type-ids instead of string keys, caller-owned query buffers (no per-frame Array allocation).
- GOAP: forward A* with a hard expansion cap per plan attempt, shared across every alternative a composite `ALL`/`ANY` goal resolves into (itself capped by `GoapCompositeGoal.MAX_ALTERNATIVES`); per-frame planning budget (`GoapPlanningSystem`, round-robin) instead of ticking every agent every frame; staggered goal-recheck timers so agents don't all replan on the same frame.
- Pathfinding: frame-budgeted async request queue (`PathfindingService`) instead of resolving every path request synchronously in one frame.

See each addon's `README.md` for addon-specific usage and performance notes.
