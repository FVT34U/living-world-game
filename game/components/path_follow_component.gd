class_name PathFollowComponent
extends RefCounted

var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var speed: float = 80.0
var arrived: bool = true

## While true, PathFollowSystem leaves this entity in place regardless of
## `path` - used by HuntAction to root a targeted animal for the hunt's
## duration so it can't wander out of range mid-attack (see its doc comment).
var locked: bool = false
