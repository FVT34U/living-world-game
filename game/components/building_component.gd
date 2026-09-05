class_name BuildingComponent
extends RefCounted

## Tags an entity as a static building. `kind` is the tag
## Game.find_nearest()/MoveToNearestAction search on (e.g. &"sawmill");
## a storage building additionally carries a StorageComponent.

var kind: StringName = &""
