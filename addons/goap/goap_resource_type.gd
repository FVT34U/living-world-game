class_name GoapResourceType
extends Resource

## An abstract resource identity ("wood", "meat", ...) that goals and actions
## reference instead of hand-typing fact strings. Save instances as .tres
## assets (e.g. res://.../wood.tres) and point GoapGoal.target_resource /
## GoapAction.requires_resource / GoapAction.produces_resource at them.
##
## This is what makes a goal abstract ("obtain meat") rather than concrete
## ("kill the boar"): any number of different GoapAction resources can set
## produces_resource to the same GoapResourceType, and the planner picks
## whichever is cheapest/reachable - see addons/goap/README.md.

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D

## The GoapWorldState fact key this resource type is tracked under.
func fact_key() -> String:
	return "has_resource:%s" % id
