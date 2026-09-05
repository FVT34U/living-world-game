# Attributes

A generic per-character attribute/characteristic system for Godot 4 (GDScript): data-driven `AttributeType` Resources plus a runtime `AttributeSet` bag of values.

**Zero dependency on the `ecs`, `goap`, or `pathfinding` addons, or on any notion of "player" vs "NPC".** `AttributeSet` doesn't know what owns it - it's just a `Dictionary` keyed by `AttributeType`, with helpers for clamped reads/writes and passive drift. Attach it to an ECS entity, a plain `Node`, a player-controller script, or use it standalone.

## Install

1. Copy `addons/attributes` into your project's `addons/` folder.
2. Project Settings → Plugins → enable **Attributes**.
3. No autoload, no dock. Create `AttributeType` `.tres` assets for whatever characteristics your game needs, and instantiate `AttributeSet` yourself per character.

## Core concepts

- **AttributeType** (`extends Resource`): one characteristic's identity and tuning - `id`, `display_name`, `min_value`/`max_value`/`default_value`, and `regen_per_second` (a passive per-second drift `AttributeSet.tick()` applies with no other code involved - positive for something that climbs on its own like age, negative for something that fades like hunger/satiety, zero for something that only changes in response to an event, like health). Save instances as `.tres` assets the same way `GoapResourceType` works in the `goap` addon.
- **AttributeSet** (`extends RefCounted`): the runtime bag of values for one character. `register(type, value?)` adds a type (defaulting to the type's own `default_value`); `get_value()`/`set_value()`/`add_value()` read and write, clamped to `[min_value, max_value]`; `get_ratio()` returns a 0..1 position for meters/bars or cross-characteristic comparisons; `tick(delta)` applies every registered type's `regen_per_second` - call it once per update from your own game loop, this addon starts no timers of its own.
- **Signals**: `value_changed(type, old, new)`, `depleted(type)` (crossed down to `min_value`), `filled(type)` (crossed up to `max_value`) - react to a characteristic bottoming out or maxing out without polling it every frame.

## Usage

```gdscript
# Author once, in the Inspector or by hand as a .tres:
#   health.tres   - min=0, max=100, default=100, regen_per_second=0   (only events change it)
#   satiety.tres  - min=0, max=100, default=100, regen_per_second=-1  (fades on its own)

var stats := AttributeSet.new()
stats.register(preload("res://health.tres"))
stats.register(preload("res://satiety.tres"), 80.0)  # start a bit below full

func _process(delta: float) -> void:
    stats.tick(delta)  # applies satiety's regen_per_second; health is untouched
    if stats.get_value(preload("res://satiety.tres")) <= 0.0:
        stats.add_value(preload("res://health.tres"), -2.0 * delta)  # starving hurts
```

## Integrating with ECS (or anything else)

This addon does not know ECS exists, but `AttributeSet` already satisfies whatever a `class_name`-based component needs to be - no adapter required. The integration pattern used in this project: `Game.ATTRIBUTES_TYPE = world.register_component(AttributeSet)`, then `world.add_component(entity, Game.ATTRIBUTES_TYPE, an_attribute_set)` like any other component. See `game/entity_factory.gd` and `game/systems/attribute_consequence_system.gd` for the game-layer glue (which `AttributeType` means what, and what happens when one is depleted) - this addon deliberately has no opinion on either.

## Performance notes

- `AttributeSet` stores values in a plain `Dictionary` keyed by `AttributeType` object reference - fine for the handful of characteristics a character typically has; not intended for thousands of dynamically-created types.
- `tick()` iterates every registered type every call; skip calling it (or call less often) for characters that don't need per-frame drift.
