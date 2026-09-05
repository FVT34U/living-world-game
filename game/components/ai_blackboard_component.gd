class_name AiBlackboardComponent
extends RefCounted

## Scratch space one GoapAgent's actions share on the same entity: written by
## a "seek" action (MoveToNearestAction) when it resolves a dynamic target,
## read by the action that acts on it (HuntAction, EatPlantAction,
## DepositResourceAction) and by Game.build_world_state() to derive the
## "at_<target>" fact live actions depend on. Not part of the goap/ecs
## addons - purely a game-layer contract between game/goap/actions/*.

var target_entity: int = -1
var target_fact: String = ""
var target_tag: StringName = &""
