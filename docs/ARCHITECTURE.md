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

## The simulation

The demo (`world_bootstrap.gd`) runs a small living settlement:

- **Woodcutters** walk to the sawmill, chop wood, carry it to a storage building, and repeat.
- **Hunters** stalk the nearest live boar or deer, kill it for meat, carry it to storage, and repeat.
- **Boars and deer** wander the map and, once hungry enough, seek out and eat the nearest plant.
- **Plants** go inert once eaten and regrow after a cooldown.
- **Animals reproduce**: once a boar/deer is well-fed and off its own cooldown, it seeks out the nearest *same-species* animal in the same state; once both are close enough they mate, go on cooldown, and spawn one (rarely two) offspring nearby - the only source of new animals, since hunted ones are gone for good. See `MateGoal`/`MateAction` below.
- **Storage buildings** hold a combined wood+meat capacity; once every storage is full, settlers stop delivering and wander instead; storages also slowly drain over time (population "consumption"), so the cycle never just tops out and stops.
- A **dev panel** (F1) can spawn or remove any settler, animal, plant, or building at a clicked position at runtime.

Settlers and animals are both plain GOAP agents (`GoapAgentComponent`) - the only difference is which goals/actions `EntityFactory` gives them. This is the same generic addon trio from before; nothing in `addons/` changed to support any of this.

## Data flow for one NPC tick

1. `GoapPlanningSystem` (ECS system, priority 0) queries every entity with a `GoapAgentComponent`, and — budgeted to a fixed number per frame, round-robin — for each one:
   - Skips it if it was already despawned by an *earlier* agent's action processed in this same frame (e.g. a hunter's `HuntAction` killing another agent's animal): the round-robin buffer is snapshotted once per frame, so a later index in it can name an id that's gone by the time its turn comes up.
   - Calls `Game.build_world_state(world, entity)`, which reads live ECS components and produces a plain `GoapWorldState` (a `Dictionary` of facts). This is the ECS → GOAP adapter step. It is generic across settlers and animals: the one positional fact it emits (`"at_<target>"`) comes from whatever `AiBlackboardComponent.target_fact` the entity's last `MoveToNearestAction` published, and resource facts (`has_resource:wood`/`has_resource:meat`) come from `InventoryComponent` when present.
   - Calls `GoapAgentComponent.agent.tick(entity, state, delta)`, which (re)selects a goal if needed, (re)plans via `GoapPlanner.plan()` if needed, and calls `perform()` on the current action. `GoapAgent.tick()` calls `start()` on whichever action just became current - both the first action of a fresh plan and every action advanced into afterward - and always calls `stop()` on an action before it stops being current, whether it finished, failed, or got abandoned by an early replan; game-layer actions rely on this to run cleanup exactly once per activation (see the `HuntAction` lock/unlock below).
2. `MoveToNearestAction` (`game/goap/actions/move_to_nearest_action.gd`) is the GOAP → Pathfinding adapter step, generalized beyond a single fixed waypoint: given a `target_tag` (`&"sawmill"`, `&"storage"`, `&"animal"`, `&"plant"`), it asks `Game.find_nearest()` for the closest live matching entity, stores it in the agent's `AiBlackboardComponent`, and calls `Game.pathfinding_service.request_path(...)`, re-requesting a path if the target has since moved (so it can chase a wandering animal) - or, once close, steering straight at the target's live position instead of re-running grid pathfinding at all, to avoid visibly flickering as a moving target keeps nudging the route. The callback stores the resulting path into the entity's `PathFollowComponent`.
3. `PathFollowSystem` (ECS system, priority 10) advances every entity's `PositionComponent` along its `PathFollowComponent.path` each frame, marking `arrived = true` on reaching the end, unless `PathFollowComponent.locked` is set - see step 4. This is pure ECS, unaware of GOAP or pathfinding beyond the plain array sitting in the component.
4. Once at the target, the next action in the plan runs against whatever `AiBlackboardComponent.target_entity` `MoveToNearestAction` resolved: `ChopWoodAction`/`HuntAction` produce a resource into `InventoryComponent`; `EatPlantAction` marks its plant inert and resets the eater's hunger; `DepositResourceAction` empties the carrier's `InventoryComponent` into the targeted `StorageComponent`. `HuntAction` additionally locks the target animal's own `PathFollowComponent` for the hunt's duration (unlocked in `stop()`) and, on success, fully despawns it via `Game.despawn_entity()` - without the lock, the animal's independent GOAP agent keeps wandering while being hunted and walks back out of the live "at_animal" fact's range before `hunt_duration` elapses, so the hunt keeps getting abandoned and replanned instead of ever finishing.
5. `RenderSyncSystem` (ECS system, priority 20) copies `PositionComponent.pos` into the entity's linked `Sprite2D.global_position` every frame. `StatusLabelSystem`/`StorageLabelSystem` (priority 21/22) keep each entity's status label and each storage's stock label in sync, so the plan's effect on ECS data is visible on screen at every step, not just position.

## The gather → deliver loop, without any addon changes

`DepositResourceAction`'s effect (and `WanderAction`'s, and `EatPlantAction`'s "ate" effect) sets a fact — `delivered_wood`, `delivered_meat`, `wandered`, `ate` — that `Game.build_world_state()` never writes into the live rebuilt state. That means the corresponding goal (`deliver_wood_goal`, `deliver_meat_goal`, `wander_goal`, `hunger_goal`) is *always* unsatisfied at the start of a fresh planning tick, so `GoapPlanner.plan()` always re-derives the full action chain (e.g. `move_to_sawmill → chop_wood → move_to_storage_wood → deposit_wood`) once its goal is (re-)selected. Combined with `GoapAgent.tick()` already replanning immediately once a plan completes, this gives an infinite gather/eat/wander loop for free, using nothing but the existing forward-search planner and the existing `preconditions`/`effects`/`requires_resource`/`produces_resource` fields.

**Pitfall this pattern doesn't protect against by itself:** a "move to X" action with *empty* preconditions is free to slot in anywhere the forward search likes, not just where it makes narrative sense — `move_to_storage`'s only original precondition was "none", so the planner could (and did) sometimes schedule it *before* chopping/hunting, since nothing about the empty-precondition action's position was constrained. `move_to_storage_wood.tres`/`move_to_storage_meat.tres` fix this by also setting `requires_resource`, so the move-to-storage step's precondition becomes "already carrying the resource" — now satisfiable only after chop/hunt, forcing the intended order. Any new multi-step chain built from empty-precondition move actions should check for this same ambiguity.

## Data-driven goals and actions

`GoapGoal` and `GoapAction` are Godot `Resource`s, not GDScript objects you build in code. Concretely, in this project:

- `game/resources/goap_resources/*.tres` are `GoapResourceType` assets (`wood`, `meat`) - the abstraction unit an action's `requires_resource`/`produces_resource` points at instead of a hand-typed fact string.
- `game/resources/goap_actions/*.tres` are configured instances of the action scripts under `game/goap/actions/`:
  - `move_to_sawmill.tres` / `move_to_storage_wood.tres` / `move_to_storage_meat.tres` / `move_to_animal.tres` / `move_to_plant.tres` all use `move_to_nearest_action.gd`, differing in `target_tag`/`target_fact` and (for the two storage variants, to force the right plan ordering - see above) `requires_resource`. Chasing a live target close-range switches from re-running A* to steering straight at its live position (see the class doc comment) to avoid visibly flickering as the target drifts.
  - `chop_wood.tres` uses `chop_wood_action.gd`; `hunt_boar.tres`/`hunt_deer.tres` both use `hunt_action.gd` with different `hunt_duration`/`cost`/`quarry_name`, so the planner naturally prefers deer (cheaper) when either would satisfy the same `meat` goal.
  - `deposit_wood.tres`/`deposit_meat.tres` both use `deposit_resource_action.gd`, differing only in `requires_resource`/`delivered_fact`.
  - `eat_plant.tres` uses `eat_plant_action.gd`; `wander.tres` uses `wander_action.gd` and is shared by every settler and animal.
- `game/resources/goap_goals/*.tres` are `GoapGoal` instances: `deliver_wood_goal.tres`/`deliver_meat_goal.tres` use the game-specific `DeliverResourceGoal` subclass (`game/goap/goals/deliver_resource_goal.gd`, invalid once every storage is full, or - via `requires_tag` - once no source of the resource exists at all, e.g. every animal has been hunted out; without that second check a hunter would sit on an unplannable goal forever instead of falling back to wander); `hunger_goal.tres` uses `HungerGoal` (`game/goap/goals/hunger_goal.gd`, valid once hunger crosses a threshold and a plant exists, with priority that rises with hunger); `mate_goal.tres` uses `MateGoal` (`game/goap/goals/mate_goal.gd`, valid only while `Game.is_mate_eligible()` holds for this animal *and* a same-species eligible partner exists - see below); `wander_goal.tres` is a plain leaf `GoapGoal` shared by every agent as the always-valid fallback.

### Reproduction (`MateGoal` / `MateAction` / `move_to_mate.tres`)

Mirrors the hunting pattern closely, reusing the same building blocks:

- `Game.is_mate_eligible(world, entity)` is the single gate: the animal must be well-fed (`hunger < MATE_HUNGER_THRESHOLD`, comfortably below `HungerGoal`'s own activation threshold so the two goals' valid windows never overlap), off its own `AnimalComponent.mate_cooldown` (ticked down by `AnimalNeedsSystem`, alongside hunger), and the total animal count must be under `MAX_ANIMAL_POPULATION` (a hard cap so reproduction can't grow the population unboundedly).
- `Game.find_nearest(world, pos, &"mate", requester)` - the one tag needing a `requester` id - returns the closest *other*, *same-species*, eligible animal. `MoveToNearestAction(target_tag=&"mate")` (`move_to_mate.tres`) walks there exactly like it walks to a sawmill or a live quarry.
- `MateAction` (`mate.tres`) then locks the partner (`Game.set_locked()`, same reasoning as `HuntAction`'s lock - otherwise the partner's own independent GOAP agent wanders off mid-attempt) and, on success, puts both participants on cooldown and spawns 1 (rarely 2, `twin_chance`) offspring near the pair via `EntityFactory.spawn_animal()`. Offspring start with their own longer `mate_cooldown` ("maturation") so population growth stays gradual rather than compounding immediately.
- Since both animals in a pair are typically each other's nearest eligible match, *both* independently path toward and engage the other - `is_ready()`/`perform()` both re-check both participants' eligibility right before completing, so whichever finishes first (round-robin order, or an earlier frame) claims the cooldown and the other's own attempt fails cleanly into a replan instead of reproducing twice for one meeting.
- Because reproduction is the *only* source of new animals, hunting pressure and starting population/hunter counts need to leave same-species pairs a realistic chance to survive long enough to meet - see the comment on the hunter-role split in `world_bootstrap.gd`.
- `game/entity_factory.gd` `preload()`s these templates and calls `instantiate_for_agent()` (`.duplicate(true)`) on each **action** per spawned entity before use - loaded `.tres` actions carry runtime-mutable state (elapsed timers, in-flight path requests), so any per-agent mutation needs its own copy (see the "Shared Resources need per-agent duplication" section of `addons/goap/README.md`). Goals are stateless here, so they're shared directly without duplication.

## Where to extend

- **New GOAP action**: write a `GoapAction` subclass under `game/goap/actions/` with `@export` parameters instead of constructor args, then create one or more `.tres` instances of it with `preconditions`/`effects`/`requires_resource`/`produces_resource` set per instance.
- **New GOAP goal**: usually no subclass needed - create a `GoapGoal` (leaf) or `GoapCompositeGoal` (AND/OR of other goals) `.tres` asset directly. Only subclass `GoapGoal` for dynamic `get_priority()`/`is_valid()` logic, as `DeliverResourceGoal`/`HungerGoal`/`MateGoal` do here.
- **New dynamic target tag**: add a case to `Game.find_nearest()` (and, if the target can go inert without being destroyed like a plant, to `Game.is_valid_target()`), then point a `move_to_nearest_action.gd` `.tres` instance's `target_tag` at it.
- **New abstract resource**: create a `GoapResourceType` `.tres` (id + display name), point any action's `produces_resource`/`requires_resource` at it, and add a case to `StorageConsumptionSystem` if it should also drain from storage over time.
- **New component type**: add a plain `RefCounted` class under `game/components/`, register it once via `world.register_component(...)` in `world_bootstrap.gd`, cache the returned id on `Game`.
- **New ECS system**: subclass `System` under `game/systems/`, give it a `priority` reflecting where it should run relative to the existing ones, add it via `world.add_system(...)`.
- **New spawnable kind**: add a `spawn_*` function to `game/entity_factory.gd`, then wire it into `game/ui/dev_panel.gd`'s `SPAWNABLE` list and `_spawn_at()` match so the dev panel can place it too.
- **Swapping pathfinding for a 3D project**: keep using the `goap` and `ecs` addons unmodified; implement a `PathfindingProvider3D` (Vector3/Vector3i) in a new `pathfinding_3d` addon mirroring `PathfindingProvider`'s method shape, and write a new `MoveToNearestAction`-style adapter for that project.

## The dev panel

`game/ui/dev_panel.gd` is a `CanvasLayer` built entirely in code (no separate scene), toggled with F1. It never touches ECS/GOAP state directly - every add/remove goes through `EntityFactory.spawn_*()` or `Game.despawn_entity()`, the same entry points the normal bootstrap and in-game actions use, so the dev panel can't desync from the simulation. "Add" arms a pending kind and places it on the next map click; "Remove mode" instead deletes whatever entity is nearest the next click, within a fixed pixel radius.

## Performance mitigations already in place

- ECS: sparse-set component storage (O(1) add/remove/lookup, packed iteration), int type-ids instead of string keys, caller-owned query buffers (no per-frame Array allocation).
- GOAP: forward A* with a hard expansion cap per plan attempt, shared across every alternative a composite `ALL`/`ANY` goal resolves into (itself capped by `GoapCompositeGoal.MAX_ALTERNATIVES`); per-frame planning budget (`GoapPlanningSystem`, round-robin) instead of ticking every agent every frame; staggered goal-recheck timers so agents don't all replan on the same frame.
- Pathfinding: frame-budgeted async request queue (`PathfindingService`) instead of resolving every path request synchronously in one frame.
- Dynamic target resolution (`Game.find_nearest`) is a linear scan over one component storage, which only runs at plan-time (replans, not every frame) and stays cheap at this project's entity counts; if NPC/animal counts grow much larger, this is the first place to add spatial partitioning.

See each addon's `README.md` for addon-specific usage and performance notes.
