class_name NodeRefComponent
extends RefCounted

## Links an entity to the visual Node2D that represents it on screen, and
## optionally a Label (a child of that node) showing live status text - see
## game/systems/status_label_system.gd and storage_label_system.gd.
## ECS data drives these nodes; the nodes never drive ECS data.
var node: Node2D
var label: Label
