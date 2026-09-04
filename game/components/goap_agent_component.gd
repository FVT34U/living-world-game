class_name GoapAgentComponent
extends RefCounted

var agent: GoapAgent
## Minimal demo "inventory" so ChopWoodAction/HuntAction have real state to
## change and build_world_state() has real state to read back - not part of
## the GOAP or ECS addons themselves, purely game-domain data.
var inventory_wood: int = 0
var inventory_meat: int = 0
