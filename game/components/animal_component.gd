class_name AnimalComponent
extends RefCounted

## Tags an entity as a huntable, foraging animal (boar, deer, ...). Plain
## data - AiBlackboardComponent plus the shared GOAP actions/goals in
## game/goap/ decide behavior; killed animals are fully destroyed
## (see Game.despawn_entity()), so there is no "alive" flag here.

var species: StringName = &""
var meat_yield: int = 1

## Rises over time (see AnimalNeedsSystem) until HungerGoal's dynamic
## priority makes eating outweigh idle wandering; reset to 0 on a successful
## EatPlantAction.
var hunger: float = 0.0
