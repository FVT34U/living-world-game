# GOAP

Goal-Oriented Action Planning for Godot 4 (GDScript): actions, goals, a forward A* planner, and per-agent plan execution/replanning - authored as data-driven Godot **Resources**.

**Zero dependency on the `ecs` or `pathfinding` addons.** Every entry point takes an opaque `agent_owner: Variant`, forwarded untouched into your `GoapAction`/`GoapGoal` subclasses - this addon never inspects or casts it. Typed as `Variant` rather than `Object` because GDScript's static type system does not treat `int` as an `Object` subtype, and entities (this project's `agent_owner`) are plain ints. Wire it up to ECS components, plain nodes, or anything else from your own game code.

## Install

1. Copy `addons/goap` into your project's `addons/` folder.
2. Project Settings → Plugins → enable **GOAP**. This also adds a **Goal Graph** bottom panel (see below).
3. No autoload. Create `GoapAgent` instances from your own game/bootstrap code.

## Core concepts

- **GoapWorldState**: a `Dictionary` of symbolic facts (`{"has_axe": true, "has_resource:wood": true}`). Keys/values are entirely your domain.
- **GoapResourceType**: a `.tres` asset (`extends Resource`) identifying an abstract resource - "wood", "meat", whatever your game trades in. `fact_key()` returns the `GoapWorldState` key it maps to (`"has_resource:<id>"`). Goals and actions reference the *resource*, not a hand-typed fact string, which is what lets a goal stay abstract ("obtain meat") while several unrelated actions ("hunt boar", "hunt deer", "buy meat") each independently satisfy it.
- **GoapAction**: `extends Resource`. `preconditions`/`effects` dictionaries the planner reasons over (the flexible escape hatch for positional facts), plus `requires_resource`/`produces_resource` (the abstraction convenience - set instead of typing a fact key), plus virtual `perform()` that does the real work at execution time. Because it's a Resource, one script can back many `.tres` instances with different exported parameters - e.g. an `AttackAction.gd` with `@export var damage: int` saved as both `attack_light.tres` and `attack_heavy.tres`, instead of writing two GDScript classes.
- **GoapGoal**: `extends Resource`. `desired_state` (flexible dict) + `target_resource` (abstraction convenience) + `priority`. Create it directly via "New Resource" in the FileSystem dock, or through the Goal Graph Editor.
- **GoapCompositeGoal**: `extends GoapGoal`. Combines several `sub_goals` as `ALL` (AND - ship needs every sub-goal satisfied at once, e.g. "prepare for winter" = wood AND meat) or `ANY` (OR - any one sub-goal satisfies it, e.g. "forage anything" = wood OR meat). Sub-goals can themselves be composite, so goal trees nest freely.
- **GoapPlanner**: static `plan(agent_owner, start_state, goal, actions) -> Array[GoapAction]`. Forward A* search, bounded by `MAX_EXPANSIONS`. For a composite goal it searches once per alternative the goal resolves into and keeps the cheapest successful plan.
- **GoapAgent**: owns an agent's goals/actions/current plan; call `tick(agent_owner, state, delta)` once per update to drive goal selection, planning, and execution.

## ⚠️ Shared Resources need per-agent duplication

A `.tres` loaded via `load()`/`preload()` is a **single cached object shared by every reference to that path**. `GoapAction` subclasses commonly carry runtime-mutable state (a "requested" flag, an elapsed timer - see `MoveToAction`/`ChopWoodAction` in this project's `game/` layer). If you hand that same loaded instance to two agents, they will corrupt each other's execution state.

**Always duplicate a template before handing it to an agent:**
```gdscript
agent.actions = [
    preload("res://actions/chop_wood.tres").instantiate_for_agent(),  # or .duplicate(true)
]
```
`GoapGoal`s are usually stateless (no runtime mutation), so sharing a loaded goal `.tres` across agents is safe by default - **except** if you mutate a loaded goal's fields per-agent (e.g. overriding `priority` so one NPC prefers gathering wood and another prefers wandering). If you do that, duplicate the goal too, the same way.

## Usage

```gdscript
# Actions/goals as GDScript classes (still the norm - Resource-ness doesn't
# change how you write behavior, only how you configure/store it):
class MoveToWoodpile extends GoapAction:
    func perform(agent_owner: Variant, delta: float) -> int:
        # ... move agent_owner toward the woodpile using your own game code ...
        return Status.SUCCESS  # or RUNNING / FAILED

class ChopWood extends GoapAction:
    func perform(agent_owner: Variant, delta: float) -> int:
        return Status.SUCCESS

# Configure instances as .tres assets instead of hardcoding in _init():
#   move_to_woodpile.tres  - preconditions={}, effects={"at_woodpile": true}
#   chop_wood.tres         - preconditions={"at_woodpile": true}, produces_resource=wood.tres

var agent := GoapAgent.new()
agent.actions = [
    preload("res://move_to_woodpile.tres").instantiate_for_agent(),
    preload("res://chop_wood.tres").instantiate_for_agent(),
]

# A goal that only cares about the abstract resource, not how it's obtained:
var gather_wood_goal := GoapGoal.new()
gather_wood_goal.target_resource = preload("res://wood.tres")
agent.goals = [gather_wood_goal]
agent.goal_recheck_interval = 1.0 + randf()  # stagger replanning across many agents

# each tick:
var state := GoapWorldState.new()
state.facts = {"at_woodpile": false, "has_resource:wood": false}
agent.tick(some_owner, state, delta)
```

### Composite goals

```gdscript
var prepare_for_winter := GoapCompositeGoal.new()
prepare_for_winter.mode = GoapCompositeGoal.Mode.ALL  # AND
prepare_for_winter.sub_goals = [gather_wood_goal, gather_meat_goal]

var forage_anything := GoapCompositeGoal.new()
forage_anything.mode = GoapCompositeGoal.Mode.ANY  # OR
forage_anything.sub_goals = [gather_wood_goal, gather_meat_goal]
```
Both are normally authored as `.tres` assets (via New Resource or the Goal Graph Editor) rather than built in code like this - the code form above is just to show the shape.

## The Goal Graph Editor

Enabling the plugin adds a **Goal Graph** panel at the bottom of the editor. Click **Open Folder** and pick a folder containing `GoapGoal`/`GoapCompositeGoal` `.tres` files (top-level only - it does not scan subfolders) to load them as nodes; drag a connection from a goal node's output into a composite node's sub-goal input to wire it in; edit name/resource/priority/state fields directly on each node; **Save All** writes every node back to its `.tres` file (new nodes get a filename derived from their goal name, inside the folder you opened).

**v1 scope, deliberately cut for now** (documented, not silently missing):
- No undo/redo integration inside the graph - save deliberately, don't rely on Ctrl+Z.
- Folder loading is top-level only, not recursive.
- Deleting a node from the canvas never deletes its `.tres` file - manage files in the FileSystem dock.
- Removing a composite's sub-goal slot only works for the last (empty) slot.

## Performance notes

- Forward A* was chosen over backward/regression search deliberately: it reuses `GoapWorldState` directly (no separate merge logic to get wrong), and is easier to debug. See the comment at the top of `goap_planner.gd` for the full reasoning.
- `MAX_EXPANSIONS` bounds worst-case planner cost per call, shared across every alternative a composite `ANY`/`ALL` goal resolves into (also capped by `GoapCompositeGoal.MAX_ALTERNATIVES`) - a wide goal tree can't blow up planning cost unboundedly.
- If you have many agents, do **not** call `tick()` for every agent every frame from a single loop with no budget - see `game/systems/goap_planning_system.gd` in this project for a round-robin, per-frame-budgeted example.
- Stagger `goal_recheck_interval` per agent (e.g. `base + randf() * jitter`) so agents don't all re-evaluate goals on the same frame.
- Multiple actions producing the same `GoapResourceType` (e.g. "hunt boar" vs "hunt deer" both setting `produces_resource = meat`) already gives you "pick one of several ways to get this resource" behavior for free via the existing A* cost search - no goal-level OR needed for that specific pattern, only when the *goal itself* has genuinely different alternative end-states.

## Integrating with ECS / Pathfinding

This addon does not know either exists. The integration pattern used in this project: a `GoapAction` subclass living in `res://game/goap/actions/` reads/writes ECS components via a shared world reference, and calls into the pathfinding addon's `PathfindingService`. See `game/goap/actions/move_to_action.gd`.
