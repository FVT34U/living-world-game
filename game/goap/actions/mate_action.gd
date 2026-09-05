class_name MateAction
extends GoapAction

## Reproduction: engages the partner resolved by the preceding
## MoveToNearestAction(target_tag=&"mate") into AiBlackboardComponent -
## itself only ever resolved (see Game.find_nearest tag &"mate") among
## same-species animals that are both well-fed and off cooldown (see
## Game.is_mate_eligible()). Locks the partner (Game.set_locked()) for the
## mating duration, same reasoning as HuntAction: without it the partner's
## own independent GOAP agent could wander off mid-attempt.
##
## Both animals in a pair typically run this action against each other at
## once (each is the other's nearest eligible match); is_ready()/perform()
## both re-check eligibility of *both* participants right before finishing,
## so whichever completes first (processed earlier in GoapPlanningSystem's
## round-robin, or on an earlier frame) puts both on cooldown - the other's
## own attempt then finds itself or its partner no longer eligible and
## fails cleanly into a replan instead of reproducing twice for one meeting.
##
## On success, spawns one - rarely two (twin_chance) - offspring of the same
## species near the pair, each starting with its own maturation cooldown so
## it can't immediately mate itself. Needs a scene-tree parent to attach the
## new Sprite2D to (Game.world_root, set once by world_bootstrap.gd).

@export var mate_duration: float = 1.5
@export var cooldown: float = 25.0
@export var offspring_maturation: float = 20.0
@export var twin_chance: float = 0.15
@export var spawn_scatter: float = 24.0

var _elapsed: float = 0.0

func start(agent_owner: Variant) -> void:
	_elapsed = 0.0
	var world: ECSWorld = Game.ecs_world
	var board: AiBlackboardComponent = world.get_component(agent_owner, Game.AI_BLACKBOARD_TYPE)
	Game.set_locked(world, board.target_entity, true)

func is_ready(agent_owner: Variant) -> bool:
	var world: ECSWorld = Game.ecs_world
	var board: AiBlackboardComponent = world.get_component(agent_owner, Game.AI_BLACKBOARD_TYPE)
	return Game.is_valid_target(world, board.target_entity, &"animal") \
		and Game.is_mate_eligible(world, agent_owner) \
		and Game.is_mate_eligible(world, board.target_entity)

func perform(agent_owner: Variant, delta: float) -> int:
	_elapsed += delta
	if _elapsed < mate_duration:
		return Status.RUNNING
	var world: ECSWorld = Game.ecs_world
	var board: AiBlackboardComponent = world.get_component(agent_owner, Game.AI_BLACKBOARD_TYPE)
	if not Game.is_valid_target(world, board.target_entity, &"animal") \
		or not Game.is_mate_eligible(world, agent_owner) \
		or not Game.is_mate_eligible(world, board.target_entity):
		return Status.FAILED

	var partner: int = board.target_entity
	var self_animal: AnimalComponent = world.get_component(agent_owner, Game.ANIMAL_TYPE)
	var partner_animal: AnimalComponent = world.get_component(partner, Game.ANIMAL_TYPE)
	self_animal.mate_cooldown = cooldown
	partner_animal.mate_cooldown = cooldown

	var spawn_center := (Game.get_entity_position(world, agent_owner) + Game.get_entity_position(world, partner)) / 2.0
	var litter := 2 if randf() < twin_chance else 1
	for i in litter:
		var offset := Vector2(randf_range(-spawn_scatter, spawn_scatter), randf_range(-spawn_scatter, spawn_scatter))
		var child := EntityFactory.spawn_animal(world, Game.world_root, spawn_center + offset, self_animal.species)
		(world.get_component(child, Game.ANIMAL_TYPE) as AnimalComponent).mate_cooldown = offspring_maturation

	return Status.SUCCESS

func stop(agent_owner: Variant) -> void:
	var world: ECSWorld = Game.ecs_world
	var board: AiBlackboardComponent = world.get_component(agent_owner, Game.AI_BLACKBOARD_TYPE)
	Game.set_locked(world, board.target_entity, false)
