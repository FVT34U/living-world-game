class_name AnimalComponent
extends RefCounted

## Tags an entity as a huntable, foraging animal (boar, deer, ...). Plain
## data - AiBlackboardComponent plus the shared GOAP actions/goals in
## game/goap/ decide behavior; killed animals are fully destroyed
## (see Game.despawn_entity()), so there is no "alive" flag here.

var species: StringName = &""
var meat_yield: int = 1

## Counts down over time (see AnimalNeedsSystem); must be <= 0 to be
## eligible to mate (see Game.is_mate_eligible()). Set to a cooldown after a
## successful MateAction, and to a longer "maturation" delay on a newborn
## (see MateAction) so population growth stays gradual.
var mate_cooldown: float = 0.0

## True for a newborn (see MateAction) until its mate_cooldown maturation
## delay runs out (see AnimalNeedsSystem) - off-limits to hunting in the
## meantime (see Game.is_animal_protected()), unlike an adult merely on its
## own post-mating cooldown.
var is_juvenile: bool = false
